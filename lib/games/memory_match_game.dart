import 'dart:math';

import '../models/word.dart';

/// 一张配对牌。
class MatchCard {
  final int id;
  final int wordId;
  final bool isWord;
  final String text;
  final String? phonetic;

  const MatchCard({
    required this.id,
    required this.wordId,
    required this.isWord,
    required this.text,
    this.phonetic,
  });
}

/// 翻牌结果。
enum FlipOutcome { none, matched, mismatch, done }

/// 记忆翻牌游戏逻辑（纯 Dart，可单元测试）。
///
/// 每词生成两张牌（单词牌 + 释义牌），全部配对即完成。
class MemoryMatchGame {
  final List<MatchCard> cards;
  final Map<int, MatchCard> _byId = {};

  final Set<int> _flipped = {}; // 当前翻开的牌 id（最多 2 张）
  final Set<int> _matched = {}; // 已配对的词 id
  final Set<int> _locked = {}; // 判定期间锁定的牌 id

  int attempts = 0;

  MemoryMatchGame(List<Word> words, {Random? random})
      : cards = _buildCards(words, random ?? Random()) {
    for (final c in cards) {
      _byId[c.id] = c;
    }
  }

  static List<MatchCard> _buildCards(List<Word> words, Random random) {
    final selected = List.of(words)..shuffle(random);
    final take = selected.take(6).toList();
    final cards = <MatchCard>[];
    var id = 0;
    for (final w in take) {
      cards.add(MatchCard(
        id: id++,
        wordId: w.id,
        isWord: true,
        text: w.word,
        phonetic: w.phonetic,
      ));
      cards.add(MatchCard(
        id: id++,
        wordId: w.id,
        isWord: false,
        text: w.meaning,
      ));
    }
    cards.shuffle(random);
    return cards;
  }

  bool get isFinished => _matched.length >= 6;

  /// 当前翻开且未被锁定的牌 id。
  Set<int> get flipped => Set.of(_flipped);

  /// 翻一张牌。返回本次操作的结果。
  /// 翻开两张后自动判定：匹配则保留，不匹配立即翻回并返回 mismatch。
  FlipOutcome flip(int cardId) {
    if (_locked.contains(cardId) || _matched.contains(_byId[cardId]!.wordId)) {
      return FlipOutcome.none;
    }
    if (_flipped.length == 2) {
      return FlipOutcome.none;
    }
    _flipped.add(cardId);
    if (_flipped.length < 2) {
      return FlipOutcome.none;
    }
    // 两张已翻开：判定
    attempts++;
    final ids = _flipped.toList();
    final a = _byId[ids[0]]!;
    final b = _byId[ids[1]]!;
    _flipped.clear();
    if (a.wordId == b.wordId) {
      _matched.add(a.wordId);
      if (isFinished) return FlipOutcome.done;
      return FlipOutcome.matched;
    } else {
      _locked.addAll(ids); // 短暂锁定，等待 UI 翻回
      return FlipOutcome.mismatch;
    }
  }

  /// 不匹配的牌翻回后调用，解除锁定。
  void unlock(Iterable<int> cardIds) {
    _locked.removeAll(cardIds);
  }

  /// 解除全部锁定（当前仅一组 mismatch 时使用）。
  void unlockAll() {
    _locked.clear();
  }

  bool isMatched(int cardId) => _matched.contains(_byId[cardId]!.wordId);
  bool isLocked(int cardId) => _locked.contains(cardId);
}
