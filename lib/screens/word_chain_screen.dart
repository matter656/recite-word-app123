import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../games/game_utils.dart';
import '../games/word_chain_game.dart';
import '../models/word.dart';
import '../providers/app_providers.dart';

/// 单词接龙：用当前词的末字母接下一个词（四选一）。
class WordChainScreen extends ConsumerStatefulWidget {
  final String bookId;
  const WordChainScreen({super.key, required this.bookId});

  @override
  ConsumerState<WordChainScreen> createState() => _WordChainScreenState();
}

class _WordChainScreenState extends ConsumerState<WordChainScreen> {
  WordChainGame? _game;
  ChainQuestion? _question;
  bool _loading = true;
  String? _error;
  int? _lastPicked;
  bool? _lastCorrect;

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
      final words = await ref
          .read(wordBookRepositoryProvider)
          .getWords(widget.bookId);
      if (!mounted) return;
      setState(() {
        _game = WordChainGame(words);
        _question = _game!.nextQuestion();
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

  void _pick(Word option) {
    final game = _game;
    if (game == null || _lastPicked != null) return;
    final correct = game.answer(option.id);
    setState(() {
      _lastPicked = option.id;
      _lastCorrect = correct;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _lastPicked = null;
        _lastCorrect = null;
        _question = game.nextQuestion(); // 结束时为 null
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('单词接龙')),
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
    final game = _game!;
    final q = _question;
    if (q == null) {
      return _ResultView(game: game, onReplay: _load);
    }
    final last = lastLetterOf(game.current.word);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('已接 ${game.chain} 个词',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('用过的词 ${game.usedCount} 个',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('当前单词',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(
                          game.current.word,
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '下一个词必须以「$last」开头',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                for (final option in q.options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _optionButton(option, q),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionButton(Word option, ChainQuestion q) {
    Color? bg;
    IconData? icon;
    if (_lastPicked != null) {
      final isCorrectOption = option.id == _lastPicked && _lastCorrect == true;
      final isWrongPick = option.id == _lastPicked && _lastCorrect == false;
      if (isCorrectOption) {
        bg = Colors.green.shade500;
        icon = Icons.check;
      } else if (isWrongPick) {
        bg = Colors.red.shade400;
        icon = Icons.close;
      }
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () => _pick(option),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon),
              const SizedBox(width: 8),
            ],
            Text(option.word,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final WordChainGame game;
  final VoidCallback onReplay;

  const _ResultView({required this.game, required this.onReplay});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.link, size: 72, color: Colors.indigo.shade400),
            const SizedBox(height: 16),
            Text('接龙结束', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            Text('${game.chain}',
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text('连续接对 ${game.chain} 个词', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('共使用 ${game.usedCount} 个词', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('返回'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onReplay,
                  icon: const Icon(Icons.replay),
                  label: const Text('再来一局'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
