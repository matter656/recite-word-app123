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
  // 构造一个可控词池：apple(a) / egg(e) / grape(g) / cat(c) ...
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

  test('起始词后出题：候选词首字母等于当前词末字母', () {
    final game = WordChainGame(pool, random: Random(1));
    final q = game.nextQuestion()!;
    final last = lastLetterOf(game.current.word);
    expect(q.options.length, 4);
    // 正确候选首字母必须等于末字母
    final correct = q.options.firstWhere(
        (x) => firstLetterOf(x.word) == last &&
            x.id != game.current.id);
    expect(correct, isNotNull);
    // 干扰项不以末字母开头
    for (final opt in q.options) {
      if (opt.id != correct.id) {
        expect(firstLetterOf(opt.word), isNot(last),
            reason: '干扰项 ${opt.word} 不应以 $last 开头');
      }
    }
  });

  test('接对后更新当前词并加连击，已用词不重复出', () {
    final game = WordChainGame(pool, random: Random(2));
    final q = game.nextQuestion()!;
    final last = lastLetterOf(game.current.word);
    final correct = q.options.firstWhere(
        (x) => firstLetterOf(x.word) == last && x.id != game.current.id);
    expect(game.answer(correct.id), isTrue);
    expect(game.chain, 1);
    expect(game.current.id, correct.id);
    expect(game.usedCount, 2);

    // 已用词不会再出现在后续题目的正确候选里
    final q2 = game.nextQuestion();
    if (q2 != null) {
      // 正确候选应排除已用词：验证 options 中最多 1 个以末字母开头的词
      final starts = q2.options
          .where((x) => firstLetterOf(x.word) == lastLetterOf(game.current.word))
          .toList();
      expect(starts.length, 1);
    }
  });

  test('接错即结束', () {
    final game = WordChainGame(pool, random: Random(3));
    final q = game.nextQuestion()!;
    final wrong = q.options.firstWhere(
        (x) => firstLetterOf(x.word) != lastLetterOf(game.current.word));
    expect(game.answer(wrong.id), isFalse);
    expect(game.ended, isTrue);
    expect(game.nextQuestion(), isNull);
  });

  test('无可用接词时结束', () {
    // 构造：所有词都以 x 开头（词池无接词可能）→ 但首词随机……
    // 直接构造极端池：apple(a), ant(a), alligator(a)——全 a 开头
    final allA = [w(1, 'apple'), w(2, 'ant'), w(3, 'alligator')];
    final game = WordChainGame(allA, random: Random(4));
    // 无论首词是什么，末字母 l/e/t 等都找不到以该字母开头的其他词
    // （池内全 a 开头，且不能重复用词）
    var count = 0;
    while (!game.ended) {
      final q = game.nextQuestion();
      if (q == null) break;
      // 全部选干扰项（非 a 开头的没有）→ 必然出错结束
      count++;
      if (count > 10) break;
      final last = lastLetterOf(game.current.word);
      final candidates =
          q.options.where((x) => firstLetterOf(x.word) == last).toList();
      if (candidates.isEmpty) {
        game.answer(q.options.first.id);
      } else {
        game.answer(candidates.first.id);
      }
    }
    expect(game.ended, isTrue);
  });
}
