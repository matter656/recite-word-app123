import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocab_app/data/app_database.dart';
import 'package:vocab_app/data/repositories/essay_repository.dart';
import 'package:vocab_app/models/essay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase appDb;
  late EssayRepository repo;

  setUp(() {
    sqfliteFfiInit();
    appDb = AppDatabase(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repo = EssayRepository(appDb);
  });

  tearDown(() async {
    await appDb.close();
  });

  test('加载考试类别：考研 + 四六级，各含题材', () async {
    final exams = await repo.getExams();
    expect(exams.length, 2);
    expect(exams.map((e) => e.id), containsAll(['kaoyan', 'cet']));
    final kaoyan = exams.firstWhere((e) => e.id == 'kaoyan');
    expect(kaoyan.topics.map((t) => t.id),
        containsAll(['picture', 'chart', 'letter', 'notice']));
    expect(kaoyan.topics.first.practicePrompts, isNotEmpty);
  });

  test('加载模板：每个题材有模板、段落句式与完整模板', () async {
    const topics = ['picture', 'chart', 'letter', 'notice',
        'argumentation', 'phenomenon', 'cet_letter', 'cet_chart'];
    for (final id in topics) {
      final t = await repo.getTemplate(id);
      expect(t.title, isNotEmpty);
      expect(t.parts.length, greaterThanOrEqualTo(3));
      expect(t.parts.first.sentences, isNotEmpty);
      expect(t.fullTemplate, contains('_'));
    }
  });

  test('加载范文：题材有范文、翻译与点评', () async {
    final samples = await repo.getSamples('picture');
    expect(samples, isNotEmpty);
    final s = samples.first;
    expect(s.essay, isNotEmpty);
    expect(s.translation, isNotEmpty);
    expect(s.comment, isNotEmpty);
    // 英文单词数合理（考研大作文 160-200 词）
    expect(EssayRepository.countWords(s.essay), greaterThan(100));
  });

  test('加载句式库：8 类且每类有内容', () async {
    final cats = await repo.getSentenceCategories();
    expect(cats.length, 8);
    for (final c in cats) {
      expect(c.name, isNotEmpty);
      expect(c.sentences, isNotEmpty);
    }
  });

  test('草稿 CRUD：保存/查询/删除', () async {
    expect(await repo.getDrafts(), isEmpty);

    final id = await repo.saveDraft(EssayDraft(
      id: 0,
      examId: 'kaoyan',
      topicId: 'picture',
      prompt: '题目',
      content: 'This is a test essay with four words here.',
      wordCount: EssayRepository.countWords(
          'This is a test essay with four words here.'),
      createdAt: DateTime(2026, 8, 12),
    ));
    expect(id, greaterThan(0));

    final drafts = await repo.getDrafts();
    expect(drafts.length, 1);
    expect(drafts.first.examId, 'kaoyan');
    expect(drafts.first.wordCount, 9);

    await repo.deleteDraft(id);
    expect(await repo.getDrafts(), isEmpty);
  });

  test('英文单词数统计', () {
    expect(EssayRepository.countWords(''), 0);
    expect(EssayRepository.countWords('   '), 0);
    expect(EssayRepository.countWords('Hello world'), 2);
    expect(EssayRepository.countWords('Hello, world! This is a test.'), 6);
    expect(EssayRepository.countWords('a\nb\tc'), 3);
  });
}
