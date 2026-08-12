import '../../models/book.dart';
import '../app_database.dart';

/// 学习进度统计。
class StatisticsRepository {
  final AppDatabase _db;

  StatisticsRepository(this._db);

  /// 每本书的进度统计。
  Future<List<BookStats>> getBookStats({DateTime? now}) async {
    final db = await _db.database;
    final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;

    final books = await db.query('books', orderBy: 'name');
    final result = <BookStats>[];
    for (final b in books) {
      final book = Book.fromMap(b);
      final learned = await db.rawQuery(
          "SELECT COUNT(*) AS c FROM card_states WHERE book_id = ? AND status != 'new'",
          [book.id]);
      // 学习中：已学但未掌握（learning/reviewing）
      final learning = await db.rawQuery(
          "SELECT COUNT(*) AS c FROM card_states WHERE book_id = ? AND status IN ('learning', 'reviewing')",
          [book.id]);
      final due = await db.rawQuery(
          "SELECT COUNT(*) AS c FROM card_states WHERE book_id = ? AND status != 'new' AND due_date <= ?",
          [book.id, ts]);
      final mastered = await db.rawQuery(
          "SELECT COUNT(*) AS c FROM card_states WHERE book_id = ? AND status = 'mastered'",
          [book.id]);
      result.add(BookStats(
        book: book,
        learned: learned.first['c'] as int,
        learning: learning.first['c'] as int,
        due: due.first['c'] as int,
        mastered: mastered.first['c'] as int,
      ));
    }
    return result;
  }

  /// 连续打卡天数（按 study_logs 的日期，今天没学不算断）。
  Future<int> getStreak({DateTime? now}) async {
    final db = await _db.database;
    final ref = now ?? DateTime.now();
    final rows = await db.query('study_logs',
        columns: ['date'], distinct: true, orderBy: 'date DESC');

    final dates = rows.map((r) => r['date'] as String).toSet();
    var streak = 0;
    var day = ref;
    // 今天没学就从昨天开始算
    if (!dates.contains(_fmt(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    while (dates.contains(_fmt(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 今日已学单词数（按 study_logs 日期去重）。
  Future<int> getTodayLearned({DateTime? now}) async {
    final db = await _db.database;
    final today = _fmt(now ?? DateTime.now());
    final rows = await db.rawQuery(
        'SELECT COUNT(DISTINCT word_id) AS c FROM study_logs WHERE date = ?',
        [today]);
    return rows.first['c'] as int;
  }

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// 单本词书的进度快照。
class BookStats {
  final Book book;
  final int learned; // 已学（非 new 状态）
  final int learning; // 学习中（learning/reviewing，学到一半）
  final int due; // 待复习（今日到期）
  final int mastered; // 已掌握

  const BookStats({
    required this.book,
    required this.learned,
    required this.learning,
    required this.due,
    required this.mastered,
  });

  double get progress => book.wordCount == 0
      ? 0
      : learned / book.wordCount;
}
