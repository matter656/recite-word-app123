import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../games/game_utils.dart';
import '../games/word_chain_game.dart';
import '../providers/app_providers.dart';

/// 单词接龙（自由拼写版）：用系统键盘拼出以末字母开头的词。
class WordChainScreen extends ConsumerStatefulWidget {
  final String bookId;
  const WordChainScreen({super.key, required this.bookId});

  @override
  ConsumerState<WordChainScreen> createState() => _WordChainScreenState();
}

class _WordChainScreenState extends ConsumerState<WordChainScreen> {
  WordChainGame? _game;
  final _controller = TextEditingController();
  bool _loading = true;
  String? _error;
  String? _hintText;
  String? _feedback; // 上次提交的反馈
  bool _feedbackBad = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _hintText = null;
      _feedback = null;
    });
    try {
      final words = await ref
          .read(wordBookRepositoryProvider)
          .getWords(widget.bookId);
      if (!mounted) return;
      setState(() {
        _game = WordChainGame(words);
        _loading = false;
      });
      _controller.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _submit() {
    final game = _game;
    if (game == null || game.ended) return;
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    final outcome = game.submit(text);
    _controller.clear();
    setState(() {
      _hintText = null;
      switch (outcome) {
        case SubmitOutcome.correct:
          _feedback = '✓ 接上了！当前词：${game.current.word}';
          _feedbackBad = false;
        case SubmitOutcome.wrong:
          final last = lastLetterOf(game.current.word);
          _feedback = '✗ 不对哦，要以「$last」开头且在词库里（${game.errors}/${WordChainGame.kMaxErrorsPerWord} 次）';
          _feedbackBad = true;
        case SubmitOutcome.wordSkipped:
          _feedback = '这个接不出来了，已换词，继续挑战！当前词：${game.current.word}';
          _feedbackBad = false;
        case SubmitOutcome.ended:
          _feedback = '游戏结束';
          _feedbackBad = false;
      }
    });
  }

  void _useHint() {
    final game = _game;
    if (game == null || game.ended) return;
    final hint = game.useHint();
    setState(() {
      if (hint != null) {
        final last = lastLetterOf(game.current.word);
        _hintText = '提示：可以接「$hint」（以 $last 开头）';
      } else {
        _hintText = null;
      }
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
    if (game.ended) {
      return _ResultView(game: game, onReplay: _load);
    }
    final last = lastLetterOf(game.current.word);
    return Column(
      children: [
        _statusBar(game),
        Expanded(
          child: SingleChildScrollView(
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
                          '拼一个以「$last」开头的单词',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_hintText != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_hintText!,
                        style: const TextStyle(
                            color: Colors.orange, fontWeight: FontWeight.w600)),
                  ),
                ],
                if (_feedback != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _feedbackBad ? Colors.red.shade700 : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                  ],
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '输入以 $last 开头的单词…',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _submit,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _useHint,
                icon: const Icon(Icons.lightbulb_outline),
                label: Text(
                    '提示（${game.hints}/${WordChainGame.kMaxHints} 次）'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBar(WordChainGame game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('已接 ${game.chain} 词',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          if (game.errors > 0)
            Text('本轮拼错 ${game.errors}/3',
                style: TextStyle(color: Colors.red.shade600)),
          const Spacer(),
          Text('已用词 ${game.usedCount}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
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
            Text('接对 ${game.chain} 个词', style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(
              '共使用 ${game.usedCount} 个词 · 跳过 ${game.skipped} 个'
              '${game.hints > 0 ? ' · 用了 ${game.hints} 次提示' : ''}',
              style: theme.textTheme.bodyMedium,
            ),
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
