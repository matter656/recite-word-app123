import 'dart:math';

import '../models/word.dart';
import 'game_utils.dart';

/// 一道选择题：正确词 + 洗牌后的选项。
class QuizQuestion {
  final Word correct;
  final List<Word> options;
  const QuizQuestion({required this.correct, required this.options});
}

/// 答题结果。
class QuizResult {
  final bool correct;
  final int scoreGained;
  final int combo; // 答题后的连击数
  const QuizResult({
    required this.correct,
    required this.scoreGained,
    required this.combo,
  });
}

/// 限时挑战游戏逻辑（纯 Dart，可单元测试）。
///
/// 计分规则：基础 10 分/题，连击加成（连续答对第 n 层 +2n 分）。
class TimeChallengeGame {
  final List<Word> _pool;
  final Random _random;
  final Set<int> _used = {};

  int score = 0;
  int combo = 0;
  int answered = 0;
  int correctCount = 0;

  static const int baseScore = 10;
  static const int comboBonusPer = 2;

  TimeChallengeGame(this._pool, {Random? random}) : _random = random ?? Random();

  bool get finished => _used.length >= _pool.length;

  /// 生成下一题；词用尽返回 null。
  QuizQuestion? nextQuestion() {
    if (finished) return null;
    final candidates = _pool.where((w) => !_used.contains(w.id)).toList();
    final correct = candidates[_random.nextInt(candidates.length)];
    final options = pickOptions(_pool, correct, 4, random: _random);
    return QuizQuestion(correct: correct, options: options);
  }

  /// 作答。correct 词的 id 与答案一致则计分。
  QuizResult answer(int chosenWordId, {QuizQuestion? question}) {
    final q = question ?? nextQuestion();
    if (q == null) {
      return const QuizResult(correct: false, scoreGained: 0, combo: 0);
    }
    _used.add(q.correct.id);
    answered++;
    final isCorrect = chosenWordId == q.correct.id;
    if (isCorrect) {
      correctCount++;
      final gained = baseScore + comboBonusPer * combo;
      score += gained;
      combo++;
      return QuizResult(correct: true, scoreGained: gained, combo: combo);
    } else {
      combo = 0;
      return const QuizResult(correct: false, scoreGained: 0, combo: 0);
    }
  }

  double get accuracy =>
      answered == 0 ? 0 : correctCount / answered;
}
