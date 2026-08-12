import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/study_repository.dart';
import '../models/card_state.dart';
import '../providers/app_providers.dart';
import '../services/audio_service.dart';

/// 跟读回放：选单词 → 听原音 → 录音跟读 → 回放对比。
class RepeatScreen extends ConsumerStatefulWidget {
  final String bookId;
  const RepeatScreen({super.key, required this.bookId});

  @override
  ConsumerState<RepeatScreen> createState() => _RepeatScreenState();
}

class _RepeatScreenState extends ConsumerState<RepeatScreen> {
  List<StudyCard>? _cards;
  StudyCard? _selected;
  bool _loading = true;
  String? _error;
  bool _recording = false;
  bool _speaking = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    TtsService.stop();
    RecorderService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cards = await ref
          .read(studyRepositoryProvider)
          .getLearnedWords(bookId: widget.bookId);
      if (cards.isEmpty) {
        // 还没学过的词：用词库前 50 个词做跟读练习
        final words = await ref
            .read(wordBookRepositoryProvider)
            .getWords(widget.bookId, limit: 50);
        final fallback = [
          for (final w in words)
            StudyCard(
              word: w,
              state: CardState(
                id: -1,
                wordId: w.id,
                bookId: widget.bookId,
                status: CardStatus.newWord,
                easeFactor: 2.5,
                intervalDays: 0,
                dueDate: DateTime(2020),
                reviewCount: 0,
              ),
            ),
        ];
        if (!mounted) return;
        setState(() {
          _cards = fallback;
          _loading = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _cards = cards;
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

  Future<void> _speak(StudyCard card) async {
    setState(() {
      _speaking = true;
      _selected = card;
    });
    await TtsService.speak(card.word.word);
    if (mounted) setState(() => _speaking = false);
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await RecorderService.stop();
      setState(() {
        _recording = false;
        _recordedPath = path;
      });
    } else {
      final ok = await RecorderService.hasPermission();
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('需要麦克风权限才能录音')),
          );
        }
        return;
      }
      setState(() {
        _recording = true;
        _recordedPath = null;
      });
      await RecorderService.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('跟读回放')),
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
    final cards = _cards!;
    return Column(
      children: [
        Expanded(
          child: cards.isEmpty
              ? const Center(child: Text('词库还没有单词'))
              : ListView.builder(
                  itemCount: cards.length,
                  itemBuilder: (context, i) {
                    final card = cards[i];
                    final selected = _selected?.word.id == card.word.id;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        title: Text(card.word.word),
                        subtitle: Text(
                            card.word.meaning.length > 30
                                ? '${card.word.meaning.substring(0, 30)}…'
                                : card.word.meaning,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.volume_up),
                          tooltip: '播放发音',
                          onPressed: () => _speak(card),
                        ),
                        onTap: () => _speak(card),
                      ),
                    );
                  },
                ),
        ),
        if (_selected != null) _playerPanel(),
      ],
    );
  }

  Widget _playerPanel() {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '跟读：${_selected!.word.word}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: Icon(_speaking ? Icons.volume_up : Icons.volume_up,
                        color: scheme.primary),
                    tooltip: '播放原音',
                    onPressed: () => _speak(_selected!),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _toggleRecord,
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(_recording ? '停止录音' : '开始录音'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _recordedPath == null
                          ? null
                          : () => RecorderService.playFile(_recordedPath!),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('回放我的'),
                    ),
                  ),
                ],
              ),
              if (_recordedPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '已录好，点击「回放我的」对比原音吧',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
