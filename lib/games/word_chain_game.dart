import 'dart:math';

import '../models/word.dart';
import 'game_utils.dart';

/// 提交拼写的结果。
enum SubmitOutcome { correct, wrong, wordSkipped, ended }

/// 单词接龙（自由拼写版）游戏逻辑（纯 Dart，可单元测试）。
///
/// 规则：
/// - 玩家输入一个词：必须「以当前词末字母开头 + 在词库中 + 未用过」才算接对
/// - 拼错累计 [kMaxErrorsPerWord] 次 → 当前词作废，随机换一个未用词继续
/// - 「提示」按钮：显示一个可接的词作参考；提示累计 [kMaxHints] 次 → 游戏结束
class WordChainGame {
  static const int kMaxErrorsPerWord = 3;
  static const int kMaxHints = 5;

  final List<Word> _pool;
  final Map<String, Word> _byWord; // 小写词 → Word
  final Random _random;
  final Set<int> _used = {};

  late Word _current;
  int chain = 0; // 接对次数
  int errors = 0; // 当前词拼错次数
  int hints = 0; // 已用提示次数
  int skipped = 0; // 作废的词数
  bool _ended = false;

  WordChainGame(this._pool, {Random? random})
      : _byWord = {
          for (final w in _pool) w.word.trim().toLowerCase(): w,
        },
        _random = random ?? Random() {
    _current = _pool[_random.nextInt(_pool.length)];
    _used.add(_current.id);
  }

  Word get current => _current;
  bool get ended => _ended;
  int get usedCount => _used.length;
  bool get hintsExhausted => hints >= kMaxHints;
  bool get errorsExhausted => errors >= kMaxErrorsPerWord;

  /// 可接的候选词（以当前词末字母开头且未用）。
  List<Word> get _availableNext => _pool
      .where((w) =>
          !_used.contains(w.id) &&
          firstLetterOf(w.word) == lastLetterOf(_current.word))
      .toList();

  /// 提交玩家拼写的词。返回判定结果。
  SubmitOutcome submit(String input) {
    if (_ended) return SubmitOutcome.ended;
    final text = input.trim().toLowerCase();
    final word = _byWord[text];
    final last = lastLetterOf(_current.word);

    final isCorrect = word != null &&
        !_used.contains(word.id) &&
        firstLetterOf(word.word) == last;

    if (isCorrect) {
      _used.add(word.id);
      _current = word;
      chain++;
      errors = 0;
      return SubmitOutcome.correct;
    }

    // 拼错
    errors++;
    if (errors >= kMaxErrorsPerWord) {
      _skipCurrentWord();
      if (_ended) return SubmitOutcome.ended;
      return SubmitOutcome.wordSkipped;
    }
    return SubmitOutcome.wrong;
  }

  /// 换一个新词作为当前词（作废接不出来的词）。
  void _skipCurrentWord() {
    skipped++;
    errors = 0;
    final unused = _pool.where((w) => !_used.contains(w.id)).toList();
    if (unused.isEmpty) {
      _ended = true;
      return;
    }
    _current = unused[_random.nextInt(unused.length)];
    _used.add(_current.id);
    // 若新词也无词可接，继续换
    while (_availableNext.isEmpty) {
      final rest = _pool.where((w) => !_used.contains(w.id)).toList();
      if (rest.isEmpty) {
        _ended = true;
        return;
      }
      _current = rest[_random.nextInt(rest.length)];
      _used.add(_current.id);
    }
  }

  /// 使用提示：返回一个可接的词文本（供玩家参考）。
  /// 提示次数 +1；累计满 [kMaxHints] 次后游戏结束。
  /// 无可用接词时返回 null（游戏自然结束）。
  String? useHint() {
    if (_ended) return null;
    final available = _availableNext;
    if (available.isEmpty) {
      _ended = true;
      return null;
    }
    hints++;
    if (hints >= kMaxHints) {
      _ended = true;
    }
    return available[_random.nextInt(available.length)].word;
  }
}
