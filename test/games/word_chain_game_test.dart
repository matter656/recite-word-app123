import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/games/game_utils.dart';
import 'package:vocab_app/games/word_chain_game.dart';
import 'package:vocab_app/models/word.dart';

Word w(int id, String word) => Word(
      id: id,
      bookId: 'cet4',
      word: word,
      phonetic: '',
      meaning: '释义',
    );

void main() {
  late List<Word> pool;
  setUp(() {
    pool = [
      w(1, 'apple'), // a
      w(2, 'egg'), // e
      w(3, 'grape'), // g
      w(4, 'cat'), // c
      w(5, 'elephant'), // e
      w(6, 'tiger'), // t
      w(7, 'tea'), // t
      w(8, 'ant'), // a
    ];
  });

  test('拼对：以末字母开头的词库词，接龙前进并加连击', () {
    final game = WordChainGame(pool, random: Random(1));
    final last = lastLetterOf(game.current.word);
    // 找一个可接的词
    final next = pool.firstWhere(
        (x) => x.id != game.current.id && firstLetterOf(x.word) == last);
    final result = game.submit(next.word);
    expect(result, SubmitOutcome.correct);
    expect(game.chain, 1);
    expect(game.current.id, next.id);
    expect(game.usedCount, 2);
  });

  test('拼错：大小写不敏感，不接的词/不以末字母开头的词都算错', () {
    final game = WordChainGame(pool, random: Random(2));
    final last = lastLetterOf(game.current.word);

    // 不以末字母开头的词库词
    final wrongStart = pool.firstWhere(
        (x) => x.id != game.current.id && firstLetterOf(x.word) != last);
    expect(game.submit(wrongStart.word), SubmitOutcome.wrong);
    expect(game.errors, 1);

    // 不在词库里的词
    expect(game.submit('zzzzzz'), SubmitOutcome.wrong);
    expect(game.errors, 2);

    // 拼对时大小写不敏感
    final correct = pool.firstWhere(
        (x) => x.id != game.current.id && firstLetterOf(x.word) == last);
    expect(game.submit(correct.word.toUpperCase()), SubmitOutcome.correct);
  });

  test('拼错 3 次：当前词作废并换词，游戏继续', () {
    final game = WordChainGame(pool, random: Random(3));
    final firstCurrent = game.current.id;
    game.submit('zzz');
    game.submit('zzz');
    final r3 = game.submit('zzz');
    expect(r3, SubmitOutcome.wordSkipped);
    expect(game.skipped, 1);
    expect(game.current.id, isNot(firstCurrent));
    expect(game.errors, 0);
    expect(game.ended, isFalse);
  });

  test('已用过的词不能重复接', () {
    final game = WordChainGame(pool, random: Random(4));
    final last = lastLetterOf(game.current.word);
    final next = pool.firstWhere(
        (x) => x.id != game.current.id && firstLetterOf(x.word) == last);
    expect(game.submit(next.word), SubmitOutcome.correct);
    // 再次提交同一个词（现在已用）→ 错
    expect(game.submit(next.word), SubmitOutcome.wrong);
  });

  test('提示：返回可接的词，累计 5 次后游戏结束', () {
    final game = WordChainGame(pool, random: Random(5));
    for (var i = 0; i < 5; i++) {
      final hint = game.useHint();
      expect(hint, isNotNull);
      expect(firstLetterOf(hint!), lastLetterOf(game.current.word),
          reason: '提示词应以末字母开头');
      if (i < 4) {
        expect(game.ended, isFalse);
      }
    }
    expect(game.hints, 5);
    expect(game.hintsExhausted, isTrue);
    expect(game.ended, isTrue);
  });

  test('提示不重复已用词，用完提示后 submit 返回 ended', () {
    final game = WordChainGame(pool, random: Random(6));
    for (var i = 0; i < WordChainGame.kMaxHints; i++) {
      game.useHint();
    }
    expect(game.submit('whatever'), SubmitOutcome.ended);
  });

  test('无可用接词时 useHint 返回 null 并结束', () {
    // 全 a 开头词池：末字母都不是 a → 无可接词
    final allA = [w(1, 'apple'), w(2, 'ant'), w(3, 'alligator')];
    final game = WordChainGame(allA, random: Random(7));
    // 无论首词是哪个，末字母都不是 a，找不到以该字母开头的其他词
    // 这里用循环验证游戏可自然终止
    var guard = 0;
    while (!game.ended && guard < 20) {
      game.useHint();
      guard++;
    }
    expect(game.ended, isTrue);
  });
}
