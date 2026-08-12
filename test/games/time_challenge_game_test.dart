import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/games/time_challenge_game.dart';
import 'package:vocab_app/models/word.dart';

Word w(int id, String word) => Word(
      id: id,
      bookId: 'cet4',
      word: word,
      phonetic: '',
      meaning: '释义$id',
    );

void main() {
  late List<Word> pool;
  setUp(() {
    pool = [for (var i = 1; i <= 30; i++) w(i, 'word$i')];
  });

  test('出题：4 个选项包含正确答案且互不重复', () {
    final game = TimeChallengeGame(pool, random: Random(1));
    final q = game.nextQuestion();
    expect(q, isNotNull);
    expect(q!.options.length, 4);
    expect(q.options.map((x) => x.id).toSet().length, 4);
    expect(q.options.any((x) => x.id == q.correct.id), isTrue);
  });

  test('答对计分并递增连击', () {
    final game = TimeChallengeGame(pool, random: Random(2));
    final q = game.nextQuestion()!;
    final r1 = game.answer(q.correct.id, question: q);
    expect(r1.correct, isTrue);
    expect(r1.scoreGained, 10); // 基础分
    expect(r1.combo, 1);
    expect(game.score, 10);

    final q2 = game.nextQuestion()!;
    final r2 = game.answer(q2.correct.id, question: q2);
    expect(r2.scoreGained, 12); // 连击 1 层 +2
    expect(r2.combo, 2);
    expect(game.score, 22);
  });

  test('答错清零连击且不计分', () {
    final game = TimeChallengeGame(pool, random: Random(3));
    final q1 = game.nextQuestion()!;
    game.answer(q1.correct.id, question: q1);
    final wrong = q1.options.firstWhere((x) => x.id != q1.correct.id);
    final r2 = game.answer(wrong.id, question: q1);
    expect(r2.correct, isFalse);
    expect(r2.combo, 0);
    expect(game.combo, 0);
    expect(game.score, 10);
    // 答错也会消耗该题（used）
    expect(game.answered, 2);
  });

  test('正确答案不重复出题，词用尽后结束', () {
    final small = [w(1, 'a'), w(2, 'b'), w(3, 'c')];
    final game = TimeChallengeGame(small, random: Random(4));
    final q1 = game.nextQuestion()!;
    game.answer(q1.correct.id, question: q1);
    final q2 = game.nextQuestion()!;
    game.answer(q2.correct.id, question: q2);
    final q3 = game.nextQuestion()!;
    game.answer(q3.correct.id, question: q3);
    expect(game.finished, isTrue);
    expect(game.nextQuestion(), isNull);
    expect(game.accuracy, 1.0);
  });

  test('正确率统计', () {
    final game = TimeChallengeGame(pool, random: Random(5));
    final q1 = game.nextQuestion()!;
    game.answer(q1.correct.id, question: q1);
    final wrong = q1.options.firstWhere((x) => x.id != q1.correct.id);
    game.answer(wrong.id, question: q1);
    expect(game.answered, 2);
    expect(game.correctCount, 1);
    expect(game.accuracy, 0.5);
  });
}
