import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/core/sm2.dart';
import 'package:vocab_app/models/card_state.dart';

void main() {
  group('SM-2 记得（rating=2）', () {
    test('新词首次记得：间隔 1 天', () {
      final r = sm2Review(2,
          easeFactor: 2.5, intervalDays: 0, reviewCount: 0, status: CardStatus.newWord);
      expect(r.intervalDays, 1);
      expect(r.easeFactor, 2.5);
      expect(r.reviewCount, 1);
      expect(r.status, CardStatus.learning);
    });

    test('第二次记得：间隔 6 天，进入 reviewing', () {
      final r = sm2Review(2,
          easeFactor: 2.5, intervalDays: 1, reviewCount: 1, status: CardStatus.learning);
      expect(r.intervalDays, 6);
      expect(r.reviewCount, 2);
      expect(r.status, CardStatus.reviewing);
    });

    test('第三次记得：间隔按 EF 增长，EF 微升', () {
      final r = sm2Review(2,
          easeFactor: 2.3, intervalDays: 6, reviewCount: 2, status: CardStatus.reviewing);
      expect(r.easeFactor, closeTo(2.35, 0.001));
      expect(r.intervalDays, (6 * 2.35).round());
      expect(r.status, CardStatus.reviewing);
    });

    test('长期记得进入 mastered（间隔≥21 天且≥3 次）', () {
      final r = sm2Review(2,
          easeFactor: 2.4, intervalDays: 25, reviewCount: 5, status: CardStatus.reviewing);
      expect(r.intervalDays, (25 * 2.45).round());
      expect(r.status, CardStatus.mastered);
    });
  });

  group('SM-2 忘了/模糊（rating=0/1）', () {
    test('忘了：间隔回 1 天，EF 降 0.2，回 learning', () {
      final r = sm2Review(0,
          easeFactor: 2.5, intervalDays: 30, reviewCount: 4, status: CardStatus.reviewing);
      expect(r.intervalDays, 1);
      expect(r.easeFactor, closeTo(2.3, 0.001));
      expect(r.status, CardStatus.learning);
    });

    test('模糊：间隔回 1 天，EF 降 0.15', () {
      final r = sm2Review(1,
          easeFactor: 2.5, intervalDays: 30, reviewCount: 4, status: CardStatus.reviewing);
      expect(r.intervalDays, 1);
      expect(r.easeFactor, closeTo(2.35, 0.001));
      expect(r.status, CardStatus.learning);
    });
  });

  group('SM-2 边界', () {
    test('EF 下限 1.3', () {
      final r = sm2Review(0,
          easeFactor: 1.3, intervalDays: 10, reviewCount: 3, status: CardStatus.reviewing);
      expect(r.easeFactor, kMinEaseFactor);
    });

    test('EF 上限 2.5', () {
      final r = sm2Review(2,
          easeFactor: 2.5, intervalDays: 6, reviewCount: 2, status: CardStatus.reviewing);
      expect(r.easeFactor, kMaxEaseFactor);
    });

    test('间隔有上限保护', () {
      final r = sm2Review(2,
          easeFactor: 2.5, intervalDays: 3000, reviewCount: 5, status: CardStatus.reviewing);
      expect(r.intervalDays, lessThanOrEqualTo(3650));
    });
  });
}
