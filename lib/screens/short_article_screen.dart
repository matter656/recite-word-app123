import 'package:flutter/material.dart';

import '../models/listening.dart';
import '../services/audio_service.dart';

/// 短文听力：先听全文 → 逐题作答（四选一 / 填空）→ 结果。
class ShortArticleScreen extends StatefulWidget {
  final ListeningArticle article;
  const ShortArticleScreen({super.key, required this.article});

  @override
  State<ShortArticleScreen> createState() => _ShortArticleScreenState();
}

class _ShortArticleScreenState extends State<ShortArticleScreen> {
  int _questionIndex = 0;
  int _score = 0;
  bool _finished = false;
  int? _lastPick;
  final _blankController = TextEditingController();
  String? _blankResult;
  bool _speaking = false;

  @override
  void dispose() {
    TtsService.stop();
    _blankController.dispose();
    super.dispose();
  }

  ListeningQuestion get _question => widget.article.questions[_questionIndex];

  Future<void> _playArticle() async {
    setState(() => _speaking = true);
    final ok = await TtsService.speak(widget.article.text);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('听不到声音？手机可能没有英文语音引擎。请到系统设置开启语音引擎后重试'),
        duration: Duration(seconds: 4),
      ));
    }
    if (mounted) setState(() => _speaking = false);
  }

  void _answerChoice(int index) {
    if (_lastPick != null) return;
    final correct = widget.article.questions[_questionIndex].options[index] ==
        widget.article.questions[_questionIndex].answer;
    if (correct) _score++;
    setState(() => _lastPick = index);
    Future.delayed(const Duration(milliseconds: 800), _next);
  }

  void _checkBlank() {
    if (_blankResult != null) return;
    final input = _blankController.text.trim().toLowerCase();
    final answer = widget.article.questions[_questionIndex].answer.toLowerCase();
    final correct = input == answer;
    if (correct) _score++;
    setState(() => _blankResult = correct ? '✓ 正确！' : '答案：${widget.article.questions[_questionIndex].answer}');
    Future.delayed(const Duration(milliseconds: 1200), _next);
  }

  void _next() {
    if (!mounted) return;
    if (_questionIndex + 1 >= widget.article.questions.length) {
      setState(() => _finished = true);
    } else {
      setState(() {
        _questionIndex++;
        _lastPick = null;
        _blankResult = null;
        _blankController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.article.title)),
      body: _finished ? _resultView() : _quizView(),
    );
  }

  Widget _quizView() {
    final theme = Theme.of(context);
    final q = _question;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Chip(label: Text(widget.article.level)),
            const SizedBox(width: 8),
            Chip(label: Text(widget.article.topic)),
            const Spacer(),
            Text('${_questionIndex + 1}/${widget.article.questions.length}',
                style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 12),
        // 播放全文
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_speaking ? Icons.volume_up : Icons.headphones,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('先听一遍短文，再回答问题',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                FilledButton.icon(
                  onPressed: _speaking ? null : _playArticle,
                  icon: const Icon(Icons.play_arrow),
                  label: Text(_speaking ? '播放中…' : '播放'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(q.question, style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (q.isChoice())
          ...q.options.asMap().entries.map((e) => _choiceButton(e.key, e.value)),
        if (!q.isChoice()) _blankInput(q),
      ],
    );
  }

  Widget _choiceButton(int index, String text) {
    Color? bg;
    if (_lastPick != null) {
      final correct = text == _question.answer;
      if (correct) {
        bg = Colors.green.shade500;
      } else if (index == _lastPick) {
        bg = Colors.red.shade400;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () => _answerChoice(index),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _blankInput(ListeningQuestion q) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _blankController,
          enabled: _blankResult == null,
          decoration: InputDecoration(
            hintText: '填写缺失的单词',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onSubmitted: (_) => _checkBlank(),
        ),
        const SizedBox(height: 12),
        if (_blankResult != null)
          Text(_blankResult!,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _blankResult!.startsWith('✓')
                      ? Colors.green
                      : Colors.orange)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _blankResult == null ? _checkBlank : null,
          icon: const Icon(Icons.check),
          label: const Text('提交'),
        ),
      ],
    );
  }

  Widget _resultView() {
    final theme = Theme.of(context);
    final total = widget.article.questions.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events, size: 72, color: Colors.amber.shade600),
            const SizedBox(height: 16),
            Text('完成！', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            Text('$_score / $total',
                style: theme.textTheme.displayMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text('答对 $_score 题', style: theme.textTheme.bodyLarge),
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
                  onPressed: _playArticle,
                  icon: const Icon(Icons.replay),
                  label: const Text('再听一遍'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
