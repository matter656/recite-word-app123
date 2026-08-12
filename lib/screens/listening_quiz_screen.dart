import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../games/time_challenge_game.dart';
import '../models/word.dart';
import '../providers/app_providers.dart';
import '../services/audio_service.dart';

/// 听力题目模式。
enum ListeningQuizMode {
  word, // 听单词选释义
  example, // 听例句选大意
}

/// 听力四选一练习页（听音选词 / 听句理解共用）。
/// 复用 TimeChallengeGame 引擎：计时、连击计分。
class ListeningQuizScreen extends ConsumerStatefulWidget {
  final String bookId;
  final String bookName;
  final ListeningQuizMode mode;

  const ListeningQuizScreen({
    super.key,
    required this.bookId,
    required this.bookName,
    required this.mode,
  });

  @override
  ConsumerState<ListeningQuizScreen> createState() =>
      _ListeningQuizScreenState();
}

class _ListeningQuizScreenState extends ConsumerState<ListeningQuizScreen> {
  static const _duration = Duration(seconds: 60);

  TimeChallengeGame? _game;
  QuizQuestion? _question;
  Duration _remaining = _duration;
  Timer? _timer;
  bool _loading = true;
  String? _error;
  int? _lastPicked;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    TtsService.stop();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _remaining = _duration;
      _lastPicked = null;
    });
    _timer?.cancel();
    try {
      final words = await ref
          .read(wordBookRepositoryProvider)
          .getWords(widget.bookId);
      if (!mounted) return;
      final game = TimeChallengeGame(words);
      final q = game.nextQuestion();
      setState(() {
        _game = game;
        _question = q;
        _loading = false;
      });
      if (q != null) _playQuestion(q);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_remaining.inSeconds <= 1) {
          t.cancel();
          setState(() => _remaining = Duration.zero);
        } else {
          setState(() => _remaining -= const Duration(seconds: 1));
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  /// 播放当前题目音频（单词用在线真人发音，例句用 TTS）。
  Future<void> _playQuestion(QuizQuestion q) async {
    setState(() => _speaking = true);
    var ok = false;
    if (widget.mode == ListeningQuizMode.word) {
      // 单词：在线真人发音（稳定，需网络）
      ok = await WordAudioService.play(q.correct.word);
      if (!ok && mounted) _showPlayError();
    } else {
      // 例句：TTS 朗读
      ok = await TtsService.speak(q.correct.exampleEn ?? q.correct.word);
      if (!ok && mounted) _showPlayError();
    }
    if (mounted) setState(() => _speaking = false);
  }

  void _showPlayError() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('发音播放失败：请检查网络连接（单词发音需要联网）'),
      duration: Duration(seconds: 3),
    ));
  }

  void _pick(Word option) {
    final game = _game;
    final q = _question;
    if (game == null || q == null || _lastPicked != null) return;
    game.answer(option.id, question: q);
    setState(() => _lastPicked = option.id);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      final next = game.nextQuestion();
      setState(() {
        _lastPicked = null;
        _question = next;
      });
      if (next != null) _playQuestion(next);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.mode == ListeningQuizMode.word ? '听音选词' : '听句理解'} · ${widget.bookName}'),
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
    final game = _game!;
    final q = _question;
    if (_remaining == Duration.zero || q == null) {
      return _ResultView(game: game, onReplay: _load);
    }
    final label = widget.mode == ListeningQuizMode.word
        ? '听发音，选出对应的释义'
        : '听例句，选出最接近的中文意思';
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
                        Text(label,
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Icon(
                          _speaking
                              ? Icons.volume_up
                              : Icons.headphones,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _speaking ? null : () => _playQuestion(q),
                          icon: const Icon(Icons.replay),
                          label: Text(_speaking ? '播放中…' : '再听一遍'),
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
    final label = widget.mode == ListeningQuizMode.word
        ? option.meaning
        : (option.exampleCn ?? option.meaning);
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
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 72, color: Colors.amber.shade600),
          const SizedBox(height: 16),
          Text('练习结束', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          Text('${game.score}',
              style: theme.textTheme.displayMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text('得分', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text('答对 ${game.correctCount} / ${game.answered}'
              '（正确率 ${(game.accuracy * 100).round()}%）',
              style: theme.textTheme.bodyLarge),
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
                label: const Text('再来一轮'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
