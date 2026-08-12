import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/app_database.dart';
import 'package:vocab_app/data/repositories/study_repository.dart';
import 'package:vocab_app/data/repositories/word_book_repository.dart';
import 'package:vocab_app/models/card_state.dart';

const sampleBookJson = '''
{
  "book": "cet4",
  "name": "四级核心词汇",
  "desc": "测试词书",
  "words": [
    {"word": "alpha", "phonetic": "", "meaning": "n. 阿尔法", "example": null},
    {"word": "beta", "phonetic": "", "meaning": "n. 贝塔", "example": null},
    {"word": "gamma", "phonetic": "", "meaning": "n. 伽马", "example": null},
    {"word": "delta", "phonetic": "", "meaning": "n. 德尔塔", "example": null},
    {"word": "epsilon", "phonetic": "", "meaning": "n. 艾普西龙", "example": null}
  ]
}
''';

void main() {
  late AppDatabase appDb;
  late WordBookRepository bookRepo;
  late StudyRepository studyRepo;
  final fixedNow = DateTime(2026, 8, 12, 10);

  setUp(() {
    sqfliteFfiInit();
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    bookRepo = WordBookRepository(appDb);
    studyRepo = StudyRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  Future<List<(String, int)>> seed() async {
    await bookRepo.importWordBookJson(sampleBookJson);
    final words = await bookRepo.getWords('cet4');
    return words.map((w) => (w.word, w.id)).toList();
  }

  test('首次队列：只含新词，受 newLimit 限制', () async {
    await seed();
    final queue = await studyRepo.getTodayQueue('cet4', newLimit: 3, now: fixedNow);
    expect(queue.cards.length, 3);
    expect(queue.cards.every((c) => c.state.status == CardStatus.newWord), isTrue);
  });

  test('学习队列不含复习词（彻底分离）', () async {
    final seeded = await seed();
    // alpha 学过一次并到期
    final db = await appDb.database;
    final alpha = seeded.first;
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [alpha.$2]);

    // 学习队列：只有新词，alpha 不出现在其中
    final queue = await studyRepo.getTodayQueue('cet4',
        newLimit: 2, now: fixedNow, shuffle: false);
    expect(queue.cards.every((c) => c.state.status == CardStatus.newWord), isTrue);
    expect(queue.cards.any((c) => c.word.id == alpha.$2), isFalse);

    // 复习队列：alpha 在其中
    final review = await studyRepo.getReviewQueue(now: fixedNow);
    expect(review.any((c) => c.word.id == alpha.$2), isTrue);
  });

  test('复习队列按到期时间排序，未到期不进', () async {
    final seeded = await seed();
    final db = await appDb.database;
    // alpha 昨天到期、beta 今天到期、gamma 明天到期
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [seeded[0].$2]);
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [seeded[1].$2]);
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.add(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [seeded[2].$2]);

    final review = await studyRepo.getReviewQueue(now: fixedNow);
    expect(review.length, 2); // gamma 未到期
    expect(review.first.word.word, 'alpha'); // 更早到期在前
    expect(review[1].word.word, 'beta');
    expect(await studyRepo.getReviewCount(now: fixedNow), 2);
  });

  test('再学习：重置 SM-2 状态，今天即可复习', () async {
    final seeded = await seed();
    final alpha = seeded.first;
    await studyRepo.submitRating(alpha.$2, 2, now: fixedNow); // 变成 learning, due 明天
    await studyRepo.relearn(alpha.$2, now: fixedNow);

    final db = await appDb.database;
    final state = (await db.query('card_states', where: 'word_id = ?', whereArgs: [alpha.$2])).first;
    expect(state['status'], 'learning');
    expect(state['ease_factor'], 2.5);
    expect(state['interval_days'], 0);
    expect(state['review_count'], 0);
    // due = now → 今天即进入复习队列
    expect(await studyRepo.getReviewCount(now: fixedNow), 1);
  });

  test('学过的词列表（含状态）', () async {
    final seeded = await seed();
    await studyRepo.submitRating(seeded[0].$2, 2, now: fixedNow);
    final learned = await studyRepo.getLearnedWords();
    expect(learned.length, 1);
    expect(learned.first.word.word, seeded[0].$1);
    expect(learned.first.state.status, CardStatus.learning);
  });

  test('评分记得：更新 card_state 并写 study_log', () async {
    final seeded = await seed();
    final alpha = seeded.first;
    await studyRepo.submitRating(alpha.$2, 2, now: fixedNow);

    final db = await appDb.database;
    final state = (await db.query('card_states', where: 'word_id = ?', whereArgs: [alpha.$2])).first;
    expect(state['status'], 'learning');
    expect(state['interval_days'], 1);
    expect(state['review_count'], 1);
    expect(state['last_reviewed_at'], fixedNow.millisecondsSinceEpoch);
    // due_date = 明天
    final due = DateTime.fromMillisecondsSinceEpoch(state['due_date'] as int);
    expect(due, fixedNow.add(const Duration(days: 1)));

    final logs = await db.query('study_logs');
    expect(logs.length, 1);
    expect(logs.first['date'], '2026-08-12');
    expect(logs.first['rating'], 2);
  });

  test('评分忘了：间隔回 1 天，EF 下降', () async {
    final seeded = await seed();
    final alpha = seeded.first;
    await studyRepo.submitRating(alpha.$2, 2, now: fixedNow); // 先学一次
    await studyRepo.submitRating(alpha.$2, 0, now: fixedNow.add(const Duration(days: 1)));

    final db = await appDb.database;
    final state = (await db.query('card_states', where: 'word_id = ?', whereArgs: [alpha.$2])).first;
    expect(state['status'], 'learning');
    expect(state['interval_days'], 1);
    expect(state['ease_factor'], closeTo(2.3, 0.001));
    expect(state['review_count'], 2);
  });

  test('评分不存在的词抛错', () async {
    expect(() => studyRepo.submitRating(99999, 2, now: fixedNow),
        throwsA(isA<StateError>()));
  });

  test('稳定模式：同一天内新词取样确定，跨天变化', () async {
    await seed();
    final day1 = DateTime(2026, 8, 12, 10);
    final day2 = DateTime(2026, 8, 13, 10);

    final a1 = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day1, shuffle: false);
    final a2 = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day1, shuffle: false);
    // 同一天：抽到的词完全一致（稳定模式，批次固定；顺序可能不同）
    expect(a1.cards.map((c) => c.word.word).toSet(),
        a2.cards.map((c) => c.word.word).toSet());
    // 全部来自 new 状态
    for (final c in a1.cards) {
      expect(c.state.status, CardStatus.newWord);
    }

    final b = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day2, shuffle: false);
    // 跨天：换了一批（日期种子不同）
    expect(b.cards.map((c) => c.word.word).toList(),
        isNot(a1.cards.map((c) => c.word.word).toList()));
  });

  test('批次固定：学几个后退出重进，同一批剩余且总数不变（进度连续）', () async {
    await seed();
    final day = DateTime(2026, 8, 12, 10);
    // 第一次进入：生成 3 词批次
    final q1 = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day, shuffle: false);
    expect(q1.newTotal, 3);
    expect(q1.cards.length, 3);

    // 学第一个词
    await studyRepo.submitRating(q1.cards.first.word.id, 2, now: day);

    // 退出重进：同一批，已学排除，newTotal 不变（3）
    final q2 = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day, shuffle: false);
    expect(q2.newTotal, 3);
    expect(q2.cards.length, 2);
    expect(q2.cards.map((c) => c.word.word).toSet(),
        q1.cards.skip(1).map((c) => c.word.word).toSet());

    // 明天：生成新批次（总数不变但词不同）
    final nextDay = DateTime(2026, 8, 13, 10);
    final q3 = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: nextDay, shuffle: false);
    expect(q3.newTotal, 3);
  });

  test('shuffle=true 时稳定取样的基础上整体打乱', () async {
    await seed();
    final day = DateTime(2026, 8, 12, 10);
    final q = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day, shuffle: true, random: Random(42));
    expect(q.cards.length, 3);
    // 与同天关闭乱序时抽到的词是同一批（稳定模式），只是顺序不同
    final stable = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day, shuffle: false);
    expect(q.cards.map((c) => c.word.word).toSet(),
        stable.cards.map((c) => c.word.word).toSet());
  });

  test('关闭乱序：shuffle=false 时新词保持批次顺序（不含复习词）', () async {
    await seed();
    final q = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: fixedNow, shuffle: false);
    expect(q.cards.length, 3);
    expect(q.cards.every((c) => c.state.status == CardStatus.newWord), isTrue);
    // 关闭乱序时批次固定（与同一天重复查询的词集合一致）
    final q2 = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: fixedNow, shuffle: false);
    expect(q.cards.map((c) => c.word.word).toSet(),
        q2.cards.map((c) => c.word.word).toSet());
  });

  test('乱序打乱学习队列：新词集合来自剩余新词池', () async {
    await seed();
    final q = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: fixedNow, shuffle: true, random: Random(1));
    expect(q.cards.length, 3);
    expect(q.cards.every((c) => c.state.status == CardStatus.newWord), isTrue);
  });
}
