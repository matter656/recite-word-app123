import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/data/repositories/listening_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('短文听力数据：10 篇且结构完整', () async {
    final repo = ListeningRepository();
    final articles = await repo.getArticles();
    expect(articles.length, 10);

    for (final a in articles) {
      expect(a.title, isNotEmpty);
      expect(a.level, isNotEmpty);
      expect(a.topic, isNotEmpty);
      expect(a.text.length, greaterThan(50));
      expect(a.questions, isNotEmpty);
      for (final q in a.questions) {
        expect(q.question, isNotEmpty);
        expect(q.answer, isNotEmpty);
        if (q.isChoice()) {
          expect(q.options.length, 4, reason: '${a.title} 选择题应有 4 个选项');
          expect(q.options, contains(q.answer));
        }
      }
    }
  });

  test('每篇短文包含选择题与填空题', () async {
    final repo = ListeningRepository();
    final articles = await repo.getArticles();
    for (final a in articles) {
      expect(
        a.questions.any((q) => q.isChoice()),
        isTrue,
        reason: '${a.title} 应包含选择题',
      );
      expect(
        a.questions.any((q) => !q.isChoice()),
        isTrue,
        reason: '${a.title} 应包含填空题',
      );
    }
  });
}
