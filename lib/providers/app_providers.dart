import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/repositories/study_repository.dart';
import '../data/repositories/word_book_repository.dart';
import '../models/book.dart';

/// 每日新词上限（M4 设置页可配置，当前为默认值）。
const int kDefaultDailyNewWords = 20;

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final wordBookRepositoryProvider = Provider<WordBookRepository>(
    (ref) => WordBookRepository(ref.watch(appDatabaseProvider)));

final studyRepositoryProvider = Provider<StudyRepository>(
    (ref) => StudyRepository(ref.watch(appDatabaseProvider)));

/// 词书列表（含导入状态刷新）。
final booksProvider =
    FutureProvider<List<Book>>((ref) => ref.watch(wordBookRepositoryProvider).getBooks());

/// 词库是否已导入。
final booksImportedProvider =
    FutureProvider<bool>((ref) => ref.watch(wordBookRepositoryProvider).isImported());
