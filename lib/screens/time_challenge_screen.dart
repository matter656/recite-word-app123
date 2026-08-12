import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../games/time_challenge_game.dart';
import '../models/word.dart';
import '../providers/app_providers.dart';

/// 限时挑战：60 秒看释义选单词，连击加分。
class TimeChallengeScreen extends ConsumerStatefulWidget {
  final String bookId;
  const TimeChallengeScreen({super.key, required this.bookId});

  @override
  ConsumerState<TimeChallengeScreen> createState() =>
      _TimeChallengeScreenState();
}

class _TimeChallengeScreenState extends ConsumerState<TimeChallengeScreen> {
  static const _duration = Duration(seconds: 60);

  TimeChallengeGame? _game;
  QuizQuestion? _question;
  Duration _remaining = _duration;
  Timer? _timer;
  bool _loading = true;
  String? _error;
  int? _lastPicked; // 上一题点选的词 id（用于对错反馈）

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _remaining = _duration;
      _lastPicked = null;
    });
    try {
      final repo = ref.read(wordBookRepositoryProvider);
      final words = await repo.getWords(widget.bookId);
      if (!mounted) return;
      final game = TimeChallengeGame(words);
      setState(() {
        _game = game;
        _question = game.nextQuestion();
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining.inSeconds <= 1) {
        t.cancel();
        setState(() => _remaining = Duration.zero);
      } else {
        setState(() => _remaining -= const Duration(seconds: 1));
      }
    });
  }

  void _pick(Word option) {
    final game = _game;
    final q = _question;
    if (game == null || q == null || _lastPicked != null) return;

    game.answer(option.id, question: q);
    setState(() {
      _lastPicked = option.id;
    });
    // 短暂反馈后出下一题
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _lastPicked = null;
          _question = game.nextQuestion();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('限时挑战')),
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
    if (_remaining == Duration.zero || _question == null) {
      return _ResultView(
        game: game,
        onReplay: _load,
      );
    }
    final q = _question!;
    return Column(
      children: [
        _Header(remaining: _remaining, score: game.score, combo: game.combo),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('选出对应的单词',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Text(
                          q.correct.meaning,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(height: 1.4),
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

  Widget _optionButton(Word option, QuizQuestion q) {
    Color? bg;
    IconData? icon;
    if (_lastPicked != null) {
      if (option.id == q.correct.id) {
        bg = Colors.green.shade500;
        icon = Icons.check;
      } else if (option.id == _lastPicked) {
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Duration remaining;
  final int score;
  final int combo;

  const _Header({
    required this.remaining,
    required this.score,
    required this.combo,
  });

  @override
  Widget build(BuildContext context) {
    final secs = remaining.inSeconds;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: secs <= 10 ? Colors.red.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.timer,
                    size: 18,
                    color: secs <= 10 ? Colors.red : Colors.grey.shade700),
                const SizedBox(width: 4),
                Text('$secs',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: secs <= 10 ? Colors.red : Colors.grey.shade800)),
              ],
            ),
          ),
          const Spacer(),
          if (combo >= 2)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.deepOrange.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('🔥 连击 x$combo',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade800)),
            ),
          const SizedBox(width: 12),
          Text('$score 分',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final TimeChallengeGame game;
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
            Icon(Icons.emoji_events,
                size: 72, color: Colors.amber.shade600),
            const SizedBox(height: 16),
            Text('挑战结束', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            Text('${game.score}',
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text('得分', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(
              '答对 ${game.correctCount} / ${game.answered}'
              '（正确率 ${(game.accuracy * 100).round()}%）',
              style: theme.textTheme.bodyLarge,
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
