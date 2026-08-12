import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/repositories/essay_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/statistics_repository.dart';
import '../data/repositories/study_repository.dart';
import '../data/repositories/word_book_repository.dart';
import '../models/book.dart';

/// 每日新词上限（设置页可配置，默认 20）。
const int kDefaultDailyNewWords = 20;

final appDatabaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final wordBookRepositoryProvider = Provider<WordBookRepository>(
    (ref) => WordBookRepository(ref.watch(appDatabaseProvider)));

final studyRepositoryProvider = Provider<StudyRepository>(
    (ref) => StudyRepository(ref.watch(appDatabaseProvider)));

final statisticsRepositoryProvider = Provider<StatisticsRepository>(
    (ref) => StatisticsRepository(ref.watch(appDatabaseProvider)));

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository());

final essayRepositoryProvider = Provider<EssayRepository>(
    (ref) => EssayRepository(ref.watch(appDatabaseProvider)));

/// 作文考试类别列表。
final essayExamsProvider =
    FutureProvider((ref) => ref.watch(essayRepositoryProvider).getExams());

/// 词书列表（含导入状态刷新）。
final booksProvider =
    FutureProvider<List<Book>>((ref) => ref.watch(wordBookRepositoryProvider).getBooks());

/// 词库是否已导入。
final booksImportedProvider =
    FutureProvider<bool>((ref) => ref.watch(wordBookRepositoryProvider).isImported());

/// 每日新词数（设置值，未配置时默认）。
final dailyNewWordsProvider = FutureProvider<int>(
    (ref) => ref.watch(settingsRepositoryProvider).getDailyNewWords());

/// 连续打卡天数。
final streakProvider = FutureProvider<int>(
    (ref) => ref.watch(statisticsRepositoryProvider).getStreak());

/// 今日已学单词数。
final todayLearnedProvider = FutureProvider<int>(
    (ref) => ref.watch(statisticsRepositoryProvider).getTodayLearned());

/// 各词书学习进度。
final bookStatsProvider = FutureProvider(
    (ref) => ref.watch(statisticsRepositoryProvider).getBookStats());

