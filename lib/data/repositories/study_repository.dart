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

/// 当日学习队列：卡片列表 + 任务总数（用于进度显示）。
class StudyQueue {
  final List<StudyCard> cards;
  final int newTotal; // 今日新词任务总数（含已学的，批次固定）
  final int reviewTotal; // 今日到期复习词数

  const StudyQueue({
    required this.cards,
    required this.newTotal,
    required this.reviewTotal,
  });

  int get total => newTotal + reviewTotal;
}

/// 学习调度与评分记录的数据访问层。
class StudyRepository {
  final AppDatabase _db;

  StudyRepository(this._db);

  /// 生成当日学习队列：只含今日新词批次（最多 [newLimit] 个）。
  /// 复习词已分离到独立复习模块（见 [getReviewQueue]）。
  ///
  /// **批次固定**：今天第一次进入时从全词库随机抽样并持久化到
  /// `daily_new_words` 表，当天后续进入都读取同一批次（仅排除已学的），
  /// 进度连续不重置；跨天自动生成新批次。[shuffle] 为 true 时队列再随机打乱。
  Future<StudyQueue> getTodayQueue(
    String bookId, {
    int newLimit = 20,
    DateTime? now,
    bool shuffle = true,
    Random? random,
  }) async {
    final db = await _db.database;
    final refNow = now ?? DateTime.now();
    final today = _fmtDate(refNow);

    // ---- 今日新词批次（持久化，当天固定）----
    final daySeed =
        refNow.year * 10000 + refNow.month * 100 + refNow.day;
    final batchRows = await db.query('daily_new_words',
        where: 'date = ? AND book_id = ?',
        whereArgs: [today, bookId],
        orderBy: 'word_id');
    List<Map<String, Object?>> batchStates;
    int newTotal;
    if (batchRows.isEmpty) {
      // 今天第一次：从全词库随机抽样并落库
      final newRows = await db.query('card_states',
          where: "book_id = ? AND status = 'new'",
          whereArgs: [bookId],
          orderBy: 'id');
      final sampled = List.of(newRows)..shuffle(Random(daySeed));
      batchStates = sampled.take(newLimit).toList();
      newTotal = batchStates.length;
      if (batchStates.isNotEmpty) {
        final batch = db.batch();
        for (final r in batchStates) {
          batch.insert('daily_new_words', {
            'date': today,
            'book_id': bookId,
            'word_id': r['word_id'],
          });
        }
        await batch.commit(noResult: true);
      }
    } else {
      // 批次已存在：只取仍未学的（已学的自动排除）
      final wordIds = batchRows.map((r) => r['word_id'] as int).toList();
      final ph = List.filled(wordIds.length, '?').join(',');
      batchStates = await db.query('card_states',
          where: "word_id IN ($ph) AND status = 'new'",
          whereArgs: wordIds,
          orderBy: 'id');
      newTotal = batchRows.length;
    }

    // ---- 组装队列（纯新词）----
    if (batchStates.isEmpty) {
      return const StudyQueue(cards: [], newTotal: 0, reviewTotal: 0);
    }
    final all = List.of(batchStates);
    if (shuffle) {
      all.shuffle(random ?? Random());
    }

    final wordIds = all.map((r) => r['word_id'] as int).toList();
    final placeholders = List.filled(wordIds.length, '?').join(',');
    final wordRows = await db.rawQuery(
        'SELECT * FROM words WHERE id IN ($placeholders)', wordIds);
    final wordsById = {for (final r in wordRows) r['id'] as int: Word.fromMap(r)};

    final cards = all
        .where((r) => wordsById.containsKey(r['word_id'] as int))
        .map((r) => StudyCard(
              word: wordsById[r['word_id'] as int]!,
              state: CardState.fromMap(r),
            ))
        .toList();

    return StudyQueue(
      cards: cards,
      newTotal: newTotal,
      reviewTotal: 0,
    );
  }

  /// 今日到期复习队列（status != new 且 due_date <= now），按到期时间升序。
  /// [bookId] 为空时返回全部词书的到期复习词。
  Future<List<StudyCard>> getReviewQueue({
    String? bookId,
    DateTime? now,
  }) async {
    final db = await _db.database;
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final where = bookId == null
        ? "status != 'new' AND due_date <= ?"
        : "book_id = ? AND status != 'new' AND due_date <= ?";
    final args = bookId == null ? [ts] : [bookId, ts];
    final rows = await db.query('card_states',
        where: where, whereArgs: args, orderBy: 'due_date, id');
    return _toStudyCards(rows);
  }

  /// 今日到期复习词数量（角标用）。
  Future<int> getReviewCount({DateTime? now}) async {
    final db = await _db.database;
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final result = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM card_states WHERE status != 'new' AND due_date <= ?",
        [ts]);
    return result.first['c'] as int;
  }

  /// 每本书的今日到期复习词数量。
  Future<Map<String, int>> getReviewCountByBook({DateTime? now}) async {
    final db = await _db.database;
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
        "SELECT book_id, COUNT(*) AS c FROM card_states "
        "WHERE status != 'new' AND due_date <= ? GROUP BY book_id",
        [ts]);
    return {for (final r in rows) r['book_id'] as String: r['c'] as int};
  }

  /// 学过的词（status != new），含单词与学习状态；可按词书过滤。
  Future<List<StudyCard>> getLearnedWords({String? bookId}) async {
    final db = await _db.database;
    final where = bookId == null
        ? "status != 'new'"
        : "book_id = ? AND status != 'new'";
    final args = bookId == null ? null : [bookId];
    final rows = await db.query('card_states',
        where: where,
        whereArgs: args,
        orderBy: 'last_reviewed_at DESC');
    return _toStudyCards(rows);
  }

  /// 再学习：把词的 SM-2 状态重置（回到 learning、间隔清零、今天即可复习）。
  Future<void> relearn(int wordId, {DateTime? now}) async {
    final db = await _db.database;
    final ts = now ?? DateTime.now();
    await db.update(
      'card_states',
      {
        'status': CardStatus.learning.value,
        'ease_factor': 2.5,
        'interval_days': 0,
        'due_date': ts.millisecondsSinceEpoch,
        'review_count': 0,
        'last_reviewed_at': ts.millisecondsSinceEpoch,
      },
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  Future<List<StudyCard>> _toStudyCards(List<Map<String, Object?>> rows) async {
    final db = await _db.database;
    if (rows.isEmpty) return const [];
    final wordIds = rows.map((r) => r['word_id'] as int).toList();
    final placeholders = List.filled(wordIds.length, '?').join(',');
    final wordRows = await db.rawQuery(
        'SELECT * FROM words WHERE id IN ($placeholders)', wordIds);
    final wordsById = {for (final r in wordRows) r['id'] as int: Word.fromMap(r)};
    return rows
        .where((r) => wordsById.containsKey(r['word_id'] as int))
        .map((r) => StudyCard(
              word: wordsById[r['word_id'] as int]!,
              state: CardState.fromMap(r),
            ))
        .toList();
  }

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

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
