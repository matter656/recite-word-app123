import 'dart:math';

import '../../core/sm2.dart';
import '../../models/card_state.dart';
import '../../models/word.dart';
import '../app_database.dart';

/// 学习会话中的一张卡片（单词 + 学习状态）。
class StudyCard {
  final Word word;
  final CardState state;

  const StudyCard({required this.word, required this.state});
}

/// 学习调度与评分记录的数据访问层。
class StudyRepository {
  final AppDatabase _db;

  StudyRepository(this._db);

  /// 生成当日学习队列：到期的复习词在前（保持到期顺序），
  /// 新词（最多 [newLimit] 个）在后；[shuffleNewWords] 为 true 时新词随机打乱。
  Future<List<StudyCard>> getTodayQueue(
    String bookId, {
    int newLimit = 20,
    DateTime? now,
    bool shuffleNewWords = true,
    Random? random,
  }) async {
    final db = await _db.database;
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;

    final reviewRows = await db.query('card_states',
        where: "book_id = ? AND status != 'new' AND due_date <= ?",
        whereArgs: [bookId, ts],
        orderBy: 'due_date, id');
    final newRows = await db.query('card_states',
        where: "book_id = ? AND status = 'new'",
        whereArgs: [bookId],
        orderBy: 'id',
        limit: newLimit);
    // query 返回只读列表，需拷贝后才能 shuffle
    final newCards = List.of(newRows);
    if (shuffleNewWords) {
      newCards.shuffle(random ?? Random());
    }

    final all = [...reviewRows, ...newCards];
    if (all.isEmpty) return const [];

    final wordIds = all.map((r) => r['word_id'] as int).toList();
    final placeholders = List.filled(wordIds.length, '?').join(',');
    final wordRows = await db.rawQuery(
        'SELECT * FROM words WHERE id IN ($placeholders)', wordIds);
    final wordsById = {for (final r in wordRows) r['id'] as int: Word.fromMap(r)};

    return all
        .where((r) => wordsById.containsKey(r['word_id'] as int))
        .map((r) => StudyCard(
              word: wordsById[r['word_id'] as int]!,
              state: CardState.fromMap(r),
            ))
        .toList();
  }

  /// 提交自评并更新 SM-2 调度、写入学习日志。
  Future<void> submitRating(
    int wordId,
    int rating, {
    DateTime? now,
  }) async {
    final db = await _db.database;
    final ts = now ?? DateTime.now();

    final rows = await db
        .query('card_states', where: 'word_id = ?', whereArgs: [wordId]);
    if (rows.isEmpty) {
      throw StateError('card_state 不存在: word_id=$wordId');
    }
    final state = CardState.fromMap(rows.first);

    final result = sm2Review(
      rating,
      easeFactor: state.easeFactor,
      intervalDays: state.intervalDays,
      reviewCount: state.reviewCount,
      status: state.status,
    );
    final due = ts.add(Duration(days: result.intervalDays));

    await db.transaction((txn) async {
      await txn.update(
        'card_states',
        {
          'status': result.status.value,
          'ease_factor': result.easeFactor,
          'interval_days': result.intervalDays,
          'due_date': due.millisecondsSinceEpoch,
          'review_count': result.reviewCount,
          'last_reviewed_at': ts.millisecondsSinceEpoch,
        },
        where: 'word_id = ?',
        whereArgs: [wordId],
      );
      final date = '${ts.year.toString().padLeft(4, '0')}-'
          '${ts.month.toString().padLeft(2, '0')}-'
          '${ts.day.toString().padLeft(2, '0')}';
      await txn.insert('study_logs', {
        'date': date,
        'word_id': wordId,
        'rating': rating,
        'reviewed_at': ts.millisecondsSinceEpoch,
      });
    });
  }
}
