import 'dart:math';

import '../models/word.dart';

/// 出题工具：从词池生成「1 个正确 + count-1 个干扰项」的选项列表。
///
/// [reject] 可排除干扰项（如接龙要求干扰项不以末字母开头）。
/// 返回的选项已洗牌，位置随机。
List<Word> pickOptions(
  List<Word> pool,
  Word correct,
  int count, {
  Random? random,
  bool Function(Word)? reject,
}) {
  final rand = random ?? Random();
  final options = <Word>[correct];
  final candidates = pool
      .where((w) => w.id != correct.id && !(reject?.call(w) ?? false))
      .toList()
    ..shuffle(rand);
  for (final w in candidates) {
    if (options.length >= count) break;
    options.add(w);
  }
  options.shuffle(rand);
  return options;
}

/// 单词的末字母（小写）。
String lastLetterOf(String word) {
  final w = word.trim().toLowerCase();
  return w.isEmpty ? '' : w.substring(w.length - 1);
}

/// 单词的首字母（小写）。
String firstLetterOf(String word) {
  final w = word.trim().toLowerCase();
  return w.isEmpty ? '' : w.substring(0, 1);
}
