import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/app_database.dart';
import 'package:vocab_app/data/repositories/statistics_repository.dart';
import 'package:vocab_app/data/repositories/study_repository.dart';
import 'package:vocab_app/data/repositories/word_book_repository.dart';

const sampleBookJson = '''
{
  "book": "cet4",
  "name": "四级核心词汇",
  "desc": "测试词书",
  "words": [
    {"word": "alpha", "phonetic": "", "meaning": "n. 阿尔法", "example": null},
    {"word": "beta", "phonetic": "", "meaning": "n. 贝塔", "example": null},
    {"word": "gamma", "phonetic": "", "meaning": "n. 伽马", "example": null}
  ]
}
''';

void main() {
  late AppDatabase appDb;
  late WordBookRepository bookRepo;
  late StudyRepository studyRepo;
  late StatisticsRepository statsRepo;
  final day1 = DateTime(2026, 8, 10, 9);
  final day2 = DateTime(2026, 8, 11, 9);
  final day3 = DateTime(2026, 8, 12, 9);

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

  Future<List<int>> seedWordIds() async {
    await bookRepo.importWordBookJson(sampleBookJson);
    final words = await bookRepo.getWords('cet4');
    return words.map((w) => w.id).toList();
  }

  test('初始统计：全部未学，无待复习', () async {
    await seedWordIds();
    final stats = await statsRepo.getBookStats(now: day3);
    expect(stats.single.learned, 0);
    expect(stats.single.learning, 0);
    expect(stats.single.due, 0);
    expect(stats.single.mastered, 0);
    expect(stats.single.progress, 0);
  });

  test('学习后统计更新：已学、学习中、待复习、掌握', () async {
    final ids = await seedWordIds();
    await studyRepo.submitRating(ids[0], 2, now: day1); // learning, 明天到期
    await studyRepo.submitRating(ids[1], 2, now: day2); // learning, 明天到期
    await studyRepo.submitRating(ids[2], 0, now: day2); // learning, 明天到期

    final stats = await statsRepo.getBookStats(now: day3);
    expect(stats.single.learned, 3);
    expect(stats.single.learning, 3); // 学到一半
    expect(stats.single.due, 3); // day1 学的（day2 到期）+ day2 学的（day3 到期）
    expect(stats.single.mastered, 0);
    expect(stats.single.progress, closeTo(1.0, 0.001));
  });

  test('到期日推进后待复习归零', () async {
    final ids = await seedWordIds();
    await studyRepo.submitRating(ids[0], 2, now: day1);
    // day3 时 alpha 已到期（day2 到期），评完变为 day4 到期
    final statsBefore = await statsRepo.getBookStats(now: day3);
    expect(statsBefore.single.due, 1);
    await studyRepo.submitRating(ids[0], 2, now: day3);
    final statsAfter = await statsRepo.getBookStats(now: day3);
    expect(statsAfter.single.due, 0);
  });

  test('连续打卡：连续三天学习 streak=3', () async {
    final ids = await seedWordIds();
    await studyRepo.submitRating(ids[0], 2, now: day1);
    await studyRepo.submitRating(ids[1], 2, now: day2);
    await studyRepo.submitRating(ids[2], 2, now: day3);
    expect(await statsRepo.getStreak(now: day3), 3);
  });

  test('断签后 streak 从最近学习日重算', () async {
    final ids = await seedWordIds();
    await studyRepo.submitRating(ids[0], 2, now: day1);
    await studyRepo.submitRating(ids[1], 2, now: day3); // 跳过 day2
    // day3 有学习 → 连续从 day3 算：day3 有、day2 无 → 1
    expect(await statsRepo.getStreak(now: day3), 1);
  });

  test('今天没学则从昨天起算', () async {
    final ids = await seedWordIds();
    await studyRepo.submitRating(ids[0], 2, now: day2);
    // day3 没学 → 从 day2 算 → 1
    expect(await statsRepo.getStreak(now: day3), 1);
  });

  test('今日已学数按词去重', () async {
    final ids = await seedWordIds();
    await studyRepo.submitRating(ids[0], 2, now: day3);
    await studyRepo.submitRating(ids[0], 2, now: day3); // 同一天重复评
    await studyRepo.submitRating(ids[1], 2, now: day3);
    expect(await statsRepo.getTodayLearned(now: day3), 2);
  });
}
