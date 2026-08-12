import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/games/memory_match_game.dart';
import 'package:vocab_app/models/word.dart';

Word w(int id, String word) => Word(
      id: id,
      bookId: 'cet4',
      word: word,
      phonetic: '音$id',
      meaning: '释义$id',
    );

void main() {
  late List<Word> pool;
  setUp(() {
    pool = [for (var i = 1; i <= 10; i++) w(i, 'word$i')];
  });

  test('生成 12 张牌：6 词 × 2，含单词牌与释义牌', () {
    final game = MemoryMatchGame(pool, random: Random(1));
    expect(game.cards.length, 12);
    expect(game.cards.where((c) => c.isWord).length, 6);
    expect(game.cards.where((c) => !c.isWord).length, 6);
    final wordIds = game.cards.map((c) => c.wordId).toSet();
    expect(wordIds.length, 6);
  });

  test('配对同一词的两张牌返回 matched', () {
    final game = MemoryMatchGame(pool, random: Random(2));
    final target = game.cards.first.wordId;
    final wordCard = game.cards.firstWhere((c) => c.wordId == target && c.isWord);
    final meaningCard =
        game.cards.firstWhere((c) => c.wordId == target && !c.isWord);
    expect(game.flip(wordCard.id), FlipOutcome.none);
    expect(game.flip(meaningCard.id), FlipOutcome.matched);
    expect(game.isMatched(wordCard.id), isTrue);
    expect(game.attempts, 1);
  });

  test('配对不同词返回 mismatch 并锁定，解锁后可再翻', () {
    final game = MemoryMatchGame(pool, random: Random(3));
    final a = game.cards[0];
    final b = game.cards.firstWhere((c) => c.wordId != a.wordId);
    game.flip(a.id);
    final outcome = game.flip(b.id);
    expect(outcome, FlipOutcome.mismatch);
    expect(game.isLocked(a.id), isTrue);
    expect(game.isLocked(b.id), isTrue);
    game.unlock([a.id, b.id]);
    expect(game.isLocked(a.id), isFalse);
    expect(game.attempts, 1);
  });

  test('全部配对后 isFinished 为 true，最后一次返回 done', () {
    final game = MemoryMatchGame(pool, random: Random(4));
    var lastOutcome = FlipOutcome.none;
    final byWord = <int, List<MatchCard>>{};
    for (final c in game.cards) {
      byWord.putIfAbsent(c.wordId, () => []).add(c);
    }
    for (final pair in byWord.values) {
      game.flip(pair[0].id);
      lastOutcome = game.flip(pair[1].id);
    }
    expect(lastOutcome, FlipOutcome.done);
    expect(game.isFinished, isTrue);
    expect(game.attempts, 6);
  });

  test('已配对或锁定的牌不可重复翻', () {
    final game = MemoryMatchGame(pool, random: Random(5));
    final target = game.cards.first.wordId;
    final pair = game.cards.where((c) => c.wordId == target).toList();
    game.flip(pair[0].id);
    game.flip(pair[1].id);
    // 已配对：再翻无效
    expect(game.flip(pair[0].id), FlipOutcome.none);
    expect(game.flipped.length, 0);
  });
}
