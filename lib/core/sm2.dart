import '../models/card_state.dart';

/// SM-2 间隔重复算法的简化实现（三档自评：0=忘了, 1=模糊, 2=记得）。
///
/// 规则（同步于设计文档）：
/// - 记得(rating=2)：间隔按 EF 增长（0→1天, 1→6天, 之后 interval×EF'），EF 微升
/// - 模糊(rating=1)：间隔回到 1 天，EF 略降
/// - 忘了(rating=0)：间隔回到 1 天，EF 降更多
/// - EF 范围 [1.3, 2.5]
/// - 状态演化：连续记得 3 次且间隔≥21 天 → mastered；
///   连续记得 2 次 → reviewing；否则 learning；忘了/模糊 → learning
class Sm2Result {
  final double easeFactor;
  final int intervalDays;
  final int reviewCount;
  final CardStatus status;

  const Sm2Result({
    required this.easeFactor,
    required this.intervalDays,
    required this.reviewCount,
    required this.status,
  });
}

const double kMinEaseFactor = 1.3;
const double kMaxEaseFactor = 2.5;
const int kMasterIntervalDays = 21;

Sm2Result sm2Review(
  int rating, {
  required double easeFactor,
  required int intervalDays,
  required int reviewCount,
  required CardStatus status,
}) {
  assert(rating >= 0 && rating <= 2);

  double ef = easeFactor;
  int interval;
  CardStatus next;

  if (rating == 2) {
    // 记得：间隔增长
    if (reviewCount == 0) {
      interval = 1;
    } else if (reviewCount == 1) {
      interval = 6;
    } else {
      ef = _bump(ef, 0.05);
      interval = (intervalDays * ef).round().clamp(1, 3650);
    }
    final rc = reviewCount + 1;
    next = rc >= 3 && interval >= kMasterIntervalDays
        ? CardStatus.mastered
        : (rc >= 2 ? CardStatus.reviewing : CardStatus.learning);
  } else {
    // 忘了或模糊：回到 1 天，EF 下降
    ef = _bump(ef, rating == 0 ? -0.20 : -0.15);
    interval = 1;
    next = CardStatus.learning;
  }

  return Sm2Result(
    easeFactor: ef,
    intervalDays: interval,
    reviewCount: reviewCount + 1,
    status: next,
  );
}

double _bump(double ef, double delta) =>
    (ef + delta).clamp(kMinEaseFactor, kMaxEaseFactor);
