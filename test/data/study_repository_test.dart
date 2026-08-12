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

  test('乱序学习：shuffle=true 时队列随机但集合不变', () async {
    await seed();
    final q1 = await studyRepo.getTodayQueue('cet4',
        newLimit: 5, now: fixedNow, shuffle: true, random: Random(42));
    final q2 = await studyRepo.getTodayQueue('cet4',
        newLimit: 5, now: fixedNow, shuffle: true, random: Random(7));
    final w1 = q1.map((c) => c.word.word).toList();
    final w2 = q2.map((c) => c.word.word).toList();
    expect(w1.toSet(), w2.toSet(), reason: '打乱后单词集合应不变');
    expect(w1.length, 5);
    // 不同种子大概率产生不同顺序
    expect(w1, isNot(equals(w2)));
  });

  test('关闭乱序：shuffle=false 时保持复习在前、新词按导入顺序', () async {
    final seeded = await seed();
    final q = await studyRepo.getTodayQueue('cet4',
        newLimit: 5, now: fixedNow, shuffle: false);
    final words = q.map((c) => c.word.word).toList();
    // 无复习词时：新词按导入顺序（前 5 个）
    expect(words, seeded.take(5).map((e) => e.$1).toList());
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
