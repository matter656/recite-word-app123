import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/study_repository.dart';
import '../providers/app_providers.dart';

/// 卡片学习页：看词回忆 → 翻面看释义例句 → 三档自评。
class StudyScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;

  const StudyScreen({super.key, required this.bookId, required this.bookName});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  List<StudyCard> _queue = const [];
  int _index = 0;
  bool _revealed = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(studyRepositoryProvider);
      final queue = await repo.getTodayQueue(
        widget.bookId,
        newLimit: kDefaultDailyNewWords,
      );
      if (!mounted) return;
      setState(() {
        _queue = queue;
        _index = 0;
        _revealed = false;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  StudyCard? get _current =>
      _index < _queue.length ? _queue[_index] : null;

  Future<void> _rate(int rating) async {
    final card = _current;
    if (card == null) return;
    final repo = ref.read(studyRepositoryProvider);
    setState(() {
      _revealed = false;
    });
    try {
      await repo.submitRating(card.word.id, rating);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _index += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bookName),
        actions: [
          if (!_loading && _current != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text('${_index + 1} / ${_queue.length}'),
              ),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败：$_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    final card = _current;
    if (card == null) {
      return const _DoneView();
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _revealed = !_revealed),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _revealed
                    ? _CardBack(key: ValueKey('back-${card.word.id}'), card: card)
                    : _CardFront(key: ValueKey('front-${card.word.id}'), card: card),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _revealed ? '点击卡片翻回，选择你的记忆程度' : '点击卡片查看释义',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_revealed) _RatingBar(onRate: _rate),
        ],
      ),
    );
  }
}

class _CardFront extends StatelessWidget {
  final StudyCard card;
  const _CardFront({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: scheme.primaryContainer,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.word.word,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
              ),
              if (card.word.phonetic.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '/${card.word.phonetic}/',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardBack extends StatelessWidget {
  final StudyCard card;
  const _CardBack({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              card.word.word,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (card.word.phonetic.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('/${card.word.phonetic}/',
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
            const Divider(height: 28),
            Text(
              card.word.meaning,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.5),
            ),
            if (card.word.exampleEn != null) ...[
              const SizedBox(height: 20),
              Text(card.word.exampleEn!,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
              if (card.word.exampleCn != null) ...[
                const SizedBox(height: 8),
                Text(card.word.exampleCn!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final ValueChanged<int> onRate;
  const _RatingBar({required this.onRate});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => onRate(0),
            icon: const Icon(Icons.refresh),
            label: const Text('忘了'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.orange.shade400,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => onRate(1),
            icon: const Icon(Icons.help_outline),
            label: const Text('模糊'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => onRate(2),
            icon: const Icon(Icons.check),
            label: const Text('记得'),
          ),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration,
              size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text('今日学习完成！', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('暂时没有要学习的新词和复习词了',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: const Text('返回词书列表'),
          ),
        ],
      ),
    );
  }
}
