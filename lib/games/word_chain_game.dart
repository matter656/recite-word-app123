import 'dart:math';

import '../models/word.dart';
import 'game_utils.dart';

/// 接龙题目：当前词 + 4 个候选（1 个正确）。
class ChainQuestion {
  final Word current;
  final List<Word> options;
  const ChainQuestion({required this.current, required this.options});
}

/// 单词接龙游戏逻辑（纯 Dart，可单元测试）。
///
/// 规则：用当前词的末字母接下一个词（四选一），用过的词不重复；
/// 无可用接词时游戏结束。
class WordChainGame {
  final List<Word> _pool;
  final Random _random;
  final Set<int> _used = {};

  late Word _current;
  int chain = 0; // 连续接对次数
  bool _ended = false;

  WordChainGame(this._pool, {Random? random}) : _random = random ?? Random() {
    _current = _pool[_random.nextInt(_pool.length)];
    _used.add(_current.id);
  }

  Word get current => _current;
  bool get ended => _ended;
  int get usedCount => _used.length;

  /// 生成下一题；无可用接词时结束并返回 null。
  ChainQuestion? nextQuestion() {
    if (_ended) return null;
    final last = lastLetterOf(_current.word);
    // 正确候选：以末字母开头且未用
    final corrects = _pool
        .where((w) =>
            !_used.contains(w.id) &&
            firstLetterOf(w.word) == last)
        .toList();
    if (corrects.isEmpty) {
      _ended = true;
      return null;
    }
    final correct = corrects[_random.nextInt(corrects.length)];
    // 干扰项：不以末字母开头且未用
    final options = pickOptions(_pool, correct, 4,
        random: _random, reject: (w) => firstLetterOf(w.word) == last);
    return ChainQuestion(current: _current, options: options);
  }

  /// 作答。返回是否接对；接对则更新当前词并加连击。
  bool answer(int chosenWordId) {
    if (_ended) return false;
    final last = lastLetterOf(_current.word);
    final chosen =
        _pool.firstWhere((w) => w.id == chosenWordId, orElse: () => _current);
    final isCorrect = chosen.id != _current.id &&
        !_used.contains(chosen.id) &&
        firstLetterOf(chosen.word) == last;
    if (isCorrect) {
      _used.add(chosen.id);
      _current = chosen;
      chain++;
    } else {
      _ended = true;
    }
    return isCorrect;
  }
}
