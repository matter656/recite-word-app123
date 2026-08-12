import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/book.dart';
import '../../models/card_state.dart';
import '../../models/word.dart';
import '../app_database.dart';

/// 词书与单词的数据访问层。
class WordBookRepository {
  final AppDatabase _db;

  WordBookRepository(this._db);

  /// 是否已导入过词库（首次启动用）。
  Future<bool> isImported() async {
    final db = await _db.database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM books');
    return (result.first['c'] as int) > 0;
  }

  /// 从 assets 导入 [bookTags] 指定的词书 JSON（如 ['cet4','cet6']）。
  Future<void> importWordBooks(List<String> bookTags) async {
    for (final tag in bookTags) {
      final jsonStr = await rootBundle.loadString('assets/wordbooks/$tag.json');
      await importWordBookJson(jsonStr);
    }
  }

  /// 解析单个词书 JSON 并写入数据库（事务）。
  /// 独立成方法便于测试注入。
  @visibleForTesting
  Future<void> importWordBookJson(String jsonStr) async {
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final db = await _db.database;
    final now = DateTime.now();
    final words = (data['words'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    await db.transaction((txn) async {
      await txn.insert('books', {
        'id': data['book'],
        'name': data['name'],
        'description': data['desc'],
        'word_count': words.length,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      // 已存在词的 word_id 映射（幂等导入：跳过已导入词）
      final existing = <String, int>{};
      final rows = await txn.query('words',
          columns: ['id', 'word'], where: 'book_id = ?', whereArgs: [data['book']]);
      for (final r in rows) {
        existing[r['word'] as String] = r['id'] as int;
      }
      for (final w in words) {
        final wordStr = w['word'] as String;
        final wordId = existing[wordStr];
        if (wordId != null) continue;
        final example = w['example'] as Map<String, dynamic>?;
        final newId = await txn.insert('words', {
          'book_id': data['book'],
          'word': wordStr,
          'phonetic': w['phonetic'] ?? '',
          'meaning': w['meaning'],
          'example_en': example?['en'],
          'example_cn': example?['cn'],
        });
        existing[wordStr] = newId;
        await txn.insert('card_states', {
          'word_id': newId,
          'book_id': data['book'],
          'status': CardStatus.newWord.value,
          'ease_factor': 2.5,
          'interval_days': 0,
          'due_date': now.millisecondsSinceEpoch,
          'review_count': 0,
        });
      }
    });
  }

  /// 全部词书。
  Future<List<Book>> getBooks() async {
    final db = await _db.database;
    final rows = await db.query('books', orderBy: 'name');
    return rows.map(Book.fromMap).toList();
  }

  Future<Book?> getBook(String id) async {
    final db = await _db.database;
    final rows = await db.query('books', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Book.fromMap(rows.first);
  }

  Future<int> countWords(String bookId) async {
    final db = await _db.database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM words WHERE book_id = ?', [bookId]);
    return result.first['c'] as int;
  }

  /// 词书内单词（按 id 升序，即导入顺序）。
  Future<List<Word>> getWords(String bookId, {int? limit, int? offset}) async {
    final db = await _db.database;
    final rows = await db.query('words',
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'id',
        limit: limit,
        offset: offset);
    return rows.map(Word.fromMap).toList();
  }

  Future<Word?> getWordById(int id) async {
    final db = await _db.database;
    final rows = await db.query('words', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Word.fromMap(rows.first);
  }
}
