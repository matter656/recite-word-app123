import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite/sqflite.dart'
    show Database, DatabaseFactory, OpenDatabaseOptions;

/// 应用数据库：负责初始化与建表。
///
/// [databaseFactory] 与 [path] 可注入，测试时用 sqflite_common_ffi 的内存库。
class AppDatabase {
  static const _dbName = 'vocab_app.db';
  static const _dbVersion = 1;

  final DatabaseFactory? databaseFactory;
  final String? path;
  Database? _db;

  AppDatabase({this.databaseFactory, this.path});

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    // 注意：字段 databaseFactory 会遮蔽 sqflite 的顶层 getter，
    // 必须用库别名 sqflite.databaseFactory 引用全局默认实现。
    final factory = databaseFactory ?? sqflite.databaseFactory;
    final dbPath = path ?? p.join(await sqflite.getDatabasesPath(), _dbName);
    final db = await factory.openDatabase(dbPath, options: OpenDatabaseOptions(
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    ));
    return db;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        word_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book_id TEXT NOT NULL REFERENCES books(id),
        word TEXT NOT NULL,
        phonetic TEXT NOT NULL DEFAULT '',
        meaning TEXT NOT NULL,
        example_en TEXT,
        example_cn TEXT,
        UNIQUE(book_id, word)
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_words_book ON words(book_id)');
    await db.execute('''
      CREATE TABLE card_states (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL UNIQUE REFERENCES words(id),
        book_id TEXT NOT NULL REFERENCES books(id),
        status TEXT NOT NULL DEFAULT 'new',
        ease_factor REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        due_date INTEGER NOT NULL,
        review_count INTEGER NOT NULL DEFAULT 0,
        last_reviewed_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE study_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        word_id INTEGER NOT NULL REFERENCES words(id),
        rating INTEGER NOT NULL,
        reviewed_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_logs_date ON study_logs(date)');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
