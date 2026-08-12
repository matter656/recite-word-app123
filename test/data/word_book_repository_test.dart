import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/app_database.dart';
import 'package:vocab_app/data/repositories/word_book_repository.dart';
import 'package:vocab_app/models/book.dart';
import 'package:vocab_app/models/word.dart';

const sampleBookJson = '''
{
  "book": "cet4",
  "name": "四级核心词汇",
  "desc": "测试词书",
  "words": [
    {"word": "abandon", "phonetic": "ə'bændən", "meaning": "vt. 放弃",
     "example": {"en": "Don't abandon me!", "cn": "别放弃我!"}},
    {"word": "ability", "phonetic": "ə'biliti", "meaning": "n. 能力", "example": null},
    {"word": "abnormal", "phonetic": "æb'nɔːməl", "meaning": "a. 反常的"}
  ]
}
''';

void main() {
  late AppDatabase appDb;
  late WordBookRepository repo;

  setUp(() {
    sqfliteFfiInit();
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = WordBookRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('导入词书后可查询词书与单词', () async {
    await repo.importWordBookJson(sampleBookJson);

    expect(await repo.isImported(), isTrue);

    final books = await repo.getBooks();
    expect(books.length, 1);
    final book = books.first;
    expect(book.id, 'cet4');
    expect(book.name, '四级核心词汇');
    expect(book.wordCount, 3);

    expect(await repo.countWords('cet4'), 3);
    final bookById = await repo.getBook('cet4');
    expect(bookById, isA<Book>());
  });

  test('单词字段完整导入，含例句', () async {
    await repo.importWordBookJson(sampleBookJson);
    final words = await repo.getWords('cet4');
    expect(words.length, 3);

    final abandon = words.firstWhere((w) => w.word == 'abandon');
    expect(abandon.phonetic, "ə'bændən");
    expect(abandon.meaning, 'vt. 放弃');
    expect(abandon.exampleEn, "Don't abandon me!");
    expect(abandon.exampleCn, '别放弃我!');

    final ability = words.firstWhere((w) => w.word == 'ability');
    expect(ability.exampleEn, isNull);
    expect(ability.exampleCn, isNull);
  });

  test('每词自动生成初始 card_state', () async {
    await repo.importWordBookJson(sampleBookJson);
    final db = await appDb.database;
    final rows = await db.query('card_states');
    expect(rows.length, 3);
    for (final r in rows) {
      expect(r['status'], 'new');
      expect(r['ease_factor'], 2.5);
      expect(r['interval_days'], 0);
      expect(r['review_count'], 0);
    }
  });

  test('重复导入同一词书不产生重复数据', () async {
    await repo.importWordBookJson(sampleBookJson);
    await repo.importWordBookJson(sampleBookJson);
    final books = await repo.getBooks();
    expect(books.length, 1);
    expect(await repo.countWords('cet4'), 3);
  });

  test('getWordById 返回单词', () async {
    await repo.importWordBookJson(sampleBookJson);
    final words = await repo.getWords('cet4');
    final w = await repo.getWordById(words.first.id);
    expect(w, isA<Word>());
    expect(w!.word, words.first.word);
  });

  test('真实词书 JSON 可完整导入（cet4）', () async {
    final jsonStr =
        await File('assets/wordbooks/cet4.json').readAsString();
    await repo.importWordBookJson(jsonStr);

    final books = await repo.getBooks();
    expect(books.single.id, 'cet4');
    expect(books.single.name, '四级核心词汇');
    expect(await repo.countWords('cet4'), 3849);

    final db = await appDb.database;
    final states = await db.query('card_states');
    expect(states.length, 3849);
    final words = await repo.getWords('cet4');
    final withExample =
        words.where((w) => w.exampleEn != null && w.exampleCn != null).length;
    expect(withExample, greaterThan(3000));
  });
}
