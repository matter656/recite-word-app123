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
    expect(queue.length, 3);
    expect(queue.every((c) => c.state.status == CardStatus.newWord), isTrue);
  });

  test('复习词优先于新词', () async {
    final seeded = await seed();
    // alpha 学过一次并到期（直接改库模拟）
    final db = await appDb.database;
    final alpha = seeded.first;
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [alpha.$2]);

    final queue = await studyRepo.getTodayQueue('cet4',
        newLimit: 2, now: fixedNow, shuffle: false);
    expect(queue.length, 3);
    expect(queue.first.word.word, 'alpha'); // 复习词在前（关闭乱序时）
    expect(queue.first.state.status, CardStatus.learning);
  });

  test('未到期复习词不进队列', () async {
    final seeded = await seed();
    final db = await appDb.database;
    final alpha = seeded.first;
    await db.update('card_states',
        {'status': 'reviewing', 'due_date': fixedNow.add(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [alpha.$2]);

    final queue = await studyRepo.getTodayQueue('cet4', newLimit: 2, now: fixedNow);
    expect(queue.every((c) => c.state.status == CardStatus.newWord), isTrue);
    expect(queue.length, 2);
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
    // 同一天：抽到的词完全一致（稳定模式）
    expect(a1.map((c) => c.word.word).toList(),
        a2.map((c) => c.word.word).toList());
    // 全部来自 new 状态
    for (final c in a1) {
      expect(c.state.status, CardStatus.newWord);
    }

    final b = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day2, shuffle: false);
    // 跨天：换了一批（日期种子不同）
    expect(b.map((c) => c.word.word).toList(),
        isNot(a1.map((c) => c.word.word).toList()));
  });

  test('shuffle=true 时稳定取样的基础上整体打乱', () async {
    await seed();
    final day = DateTime(2026, 8, 12, 10);
    final q = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day, shuffle: true, random: Random(42));
    expect(q.length, 3);
    // 与同天关闭乱序时抽到的词是同一批（稳定模式），只是顺序不同
    final stable = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: day, shuffle: false);
    expect(q.map((c) => c.word.word).toSet(),
        stable.map((c) => c.word.word).toSet());
  });

  test('关闭乱序：shuffle=false 时复习词在前、新词随机取样', () async {
    final seeded = await seed();
    final db = await appDb.database;
    // alpha 设为到期的复习词
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [seeded[0].$2]);

    final q = await studyRepo.getTodayQueue('cet4',
        newLimit: 3, now: fixedNow, shuffle: false);
    expect(q.length, 4); // 1 复习 + 3 新词
    // 复习词固定在队首
    expect(q.first.word.word, 'alpha');
    // 其余为新词
    expect(q.skip(1).every((c) => c.state.status == CardStatus.newWord), isTrue);
  });

  test('乱序打乱整个队列：复习词与新词混合，但词集合不变', () async {
    final seeded = await seed();
    final db = await appDb.database;
    // alpha/beta 设为到期的复习词
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [seeded[0].$2]);
    await db.update('card_states',
        {'status': 'learning', 'due_date': fixedNow.subtract(const Duration(days: 1)).millisecondsSinceEpoch},
        where: 'word_id = ?', whereArgs: [seeded[1].$2]);

    final q = await studyRepo.getTodayQueue('cet4',
        newLimit: 5, now: fixedNow, shuffle: true, random: Random(1));
    // 全部词都在（2 复习 + 3 新词 = 5）
    expect(q.length, 5);
    final all = q.map((c) => c.word.word).toSet();
    expect(all, {'alpha', 'beta', 'gamma', 'delta', 'epsilon'});
  });
}
