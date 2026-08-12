import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/app_database.dart';
import 'package:vocab_app/data/repositories/statistics_repository.dart';
import 'package:vocab_app/data/repositories/study_repository.dart';
import 'package:vocab_app/data/repositories/word_book_repository.dart';

/// 用真实 4 本词书 JSON 模拟首次启动导入，验证数据一致性与各查询路径。
void main() {
  late AppDatabase appDb;
  late WordBookRepository bookRepo;
  late StudyRepository studyRepo;
  late StatisticsRepository statsRepo;

  setUp(() {
    sqfliteFfiInit();
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    bookRepo = WordBookRepository(appDb);
    studyRepo = StudyRepository(appDb);
    statsRepo = StatisticsRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('真实 4 本词书全量导入：数据一致，无悬挂引用', () async {
    const tags = ['cet4', 'cet6', 'ky', 'ielts'];
    for (final tag in tags) {
      final jsonStr =
          await File('assets/wordbooks/$tag.json').readAsString();
      await bookRepo.importWordBookJson(jsonStr);
    }

    // 4 本书导入成功
    final books = await bookRepo.getBooks();
    expect(books.length, 4);
    for (final b in books) {
      expect(await bookRepo.countWords(b.id), b.wordCount);
    }

    final db = await appDb.database;
    // 每个 word 都有对应 card_state（无悬挂）
    final orphan = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM card_states cs
      LEFT JOIN words w ON w.id = cs.word_id WHERE w.id IS NULL
    ''');
    expect(orphan.first['c'], 0);
    // 每个 card_state 的 word_id 唯一
    final dup = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM (SELECT word_id FROM card_states
      GROUP BY word_id HAVING COUNT(*) > 1)
    ''');
    expect(dup.first['c'], 0);

    // 总词数
    final total = await db.rawQuery('SELECT COUNT(*) AS c FROM words');
    expect(total.first['c'], 3849 + 5407 + 4801 + 5040);
  });

  test('全量导入后：每本书的当日队列可正常生成', () async {
    const tags = ['cet4', 'cet6', 'ky', 'ielts'];
    for (final tag in tags) {
      await bookRepo
          .importWordBookJson(await File('assets/wordbooks/$tag.json').readAsString());
    }
    final books = await bookRepo.getBooks();
    for (final b in books) {
      final queue = await studyRepo.getTodayQueue(b.id, newLimit: 20);
      expect(queue.length, 20);
    }
  });

  test('全量导入后：统计查询正常', () async {
    await bookRepo
        .importWordBookJson(await File('assets/wordbooks/cet4.json').readAsString());
    final stats = await statsRepo.getBookStats();
    expect(stats.single.learned, 0);
    expect(await statsRepo.getStreak(), 0);
    expect(await statsRepo.getTodayLearned(), 0);
  });

  test('未注入 factory 时走全局默认（模拟真机启动路径，防回归）', () async {
    // 模拟真机：sqflite 插件初始化后设置全局 databaseFactory
    databaseFactory = databaseFactoryFfi;
    final defaultDb = AppDatabase(path: inMemoryDatabasePath);
    final repo = WordBookRepository(defaultDb);
    await repo.importWordBookJson(
        await File('assets/wordbooks/cet4.json').readAsString());
    expect(await repo.countWords('cet4'), 3849);
    await defaultDb.close();
  });
}
