import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/study_repository.dart';
import '../models/card_state.dart';
import '../providers/app_providers.dart';

/// 学过的单词：按状态筛选浏览，可查看详情并「再学习」（重置重学）。
class LearnedWordsScreen extends ConsumerStatefulWidget {
  const LearnedWordsScreen({super.key});

  @override
  ConsumerState<LearnedWordsScreen> createState() =>
      _LearnedWordsScreenState();
}

class _LearnedWordsScreenState extends ConsumerState<LearnedWordsScreen> {
  List<StudyCard>? _cards;
  CardStatus? _filter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cards = await ref.read(studyRepositoryProvider).getLearnedWords();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _relearn(StudyCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新学习这个单词？'),
        content: const Text('会重置它的记忆进度，今天起重新学习'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('重新学习'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(studyRepositoryProvider).relearn(card.word.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已重置「${card.word.word}」，今天起重新学习')));
    ref.invalidate(reviewCountProvider);
    _load();
  }

  void _showDetail(StudyCard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: controller,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(card.word.word,
                        style: Theme.of(ctx).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                  ),
                  _statusChip(ctx, card.state.status),
                ],
              ),
              if (card.word.phonetic.isNotEmpty)
                Text('/${card.word.phonetic}/',
                    style: Theme.of(ctx)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Theme.of(ctx).colorScheme.outline)),
              const Divider(height: 28),
              Text(card.word.meaning,
                  style: Theme.of(ctx).textTheme.titleMedium
                      ?.copyWith(height: 1.5)),
              if (card.word.exampleEn != null) ...[
                const SizedBox(height: 16),
                Text(card.word.exampleEn!,
                    style: Theme.of(ctx).textTheme.bodyLarge
                        ?.copyWith(height: 1.5)),
                if (card.word.exampleCn != null) ...[
                  const SizedBox(height: 6),
                  Text(card.word.exampleCn!,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.outline)),
                ],
              ],
              const SizedBox(height: 12),
              Text(
                '已复习 ${card.state.reviewCount} 次 · 下次复习间隔 ${card.state.intervalDays} 天'
                '${card.state.status == CardStatus.mastered ? ' · 已掌握' : ''}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _relearn(card);
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('重新学习'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, CardStatus status) {
    final (color, text) = switch (status) {
      CardStatus.learning => (Colors.indigo, '学习中'),
      CardStatus.reviewing => (Colors.orange, '复习中'),
      CardStatus.mastered => (Colors.green, '已掌握'),
      CardStatus.newWord => (Colors.grey, '新词'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color.shade800)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('学过的单词')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 状态筛选
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _filterChip(null, '全部'),
                      _filterChip(CardStatus.learning, '学习中'),
                      _filterChip(CardStatus.reviewing, '复习中'),
                      _filterChip(CardStatus.mastered, '已掌握'),
                    ],
                  ),
                ),
                Expanded(
                  child: _cards!.isEmpty
                      ? const Center(child: Text('还没有学过的单词'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          itemCount: _cards!.length,
                          itemBuilder: (context, i) {
                            final card = _cards![i];
                            if (_filter != null &&
                                card.state.status != _filter) {
                              return const SizedBox.shrink();
                            }
                            return Card(
                              child: ListTile(
                                leading: _statusChip(context, card.state.status),
                                title: Text(card.word.word),
                                subtitle: Text(
                                    card.word.meaning.length > 40
                                        ? '${card.word.meaning.substring(0, 40)}…'
                                        : card.word.meaning,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                trailing: IconButton(
                                  icon: const Icon(Icons.restart_alt),
                                  tooltip: '重新学习',
                                  onPressed: () => _relearn(card),
                                ),
                                onTap: () => _showDetail(card),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _filterChip(CardStatus? status, String label) {
    final selected = _filter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = status),
    );
  }
}
