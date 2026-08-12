import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/data/app_database.dart';
import 'package:vocab_app/data/repositories/study_repository.dart';
import 'package:vocab_app/models/card_state.dart';
import 'package:vocab_app/models/word.dart';
import 'package:vocab_app/providers/app_providers.dart';
import 'package:vocab_app/screens/study_screen.dart';

Word makeWord(int id, String w) => Word(
      id: id,
      bookId: 'cet4',
      word: w,
      phonetic: 'ælfə',
      meaning: 'n. 测试释义',
      exampleEn: 'Example sentence.',
      exampleCn: '示例句。',
    );

CardState makeState(int wordId, {CardStatus status = CardStatus.newWord}) =>
    CardState(
      id: wordId,
      wordId: wordId,
      bookId: 'cet4',
      status: status,
      easeFactor: 2.5,
      intervalDays: 0,
      dueDate: DateTime(2026, 8, 12),
      reviewCount: 0,
    );

/// 内存版学习仓库：不依赖真实数据库。
class FakeStudyRepository extends StudyRepository {
  FakeStudyRepository(this._queue) : super(AppDatabase());

  final List<StudyCard> _queue;
  final List<int> rated = [];

  @override
  Future<List<StudyCard>> getTodayQueue(String bookId,
      {int newLimit = 20, DateTime? now}) async {
    return _queue;
  }

  @override
  Future<void> submitRating(int wordId, int rating, {DateTime? now}) async {
    rated.add(rating);
  }
}

Widget buildApp(FakeStudyRepository repo) {
  return ProviderScope(
    overrides: [
      studyRepositoryProvider.overrideWithValue(repo),
    ],
    child: const MaterialApp(
      home: StudyScreen(bookId: 'cet4', bookName: '四级核心词汇'),
    ),
  );
}

void main() {
  testWidgets('学习页：显示卡片正面，点击翻面显示释义与例句', (tester) async {
    final repo = FakeStudyRepository([
      StudyCard(word: makeWord(1, 'alpha'), state: makeState(1)),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    // 正面：单词 + 音标
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('/ælfə/'), findsOneWidget);
    expect(find.text('n. 测试释义'), findsNothing);

    // 点击翻面：释义 + 例句 + 评分按钮
    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();
    expect(find.text('n. 测试释义'), findsOneWidget);
    expect(find.text('Example sentence.'), findsOneWidget);
    expect(find.text('示例句。'), findsOneWidget);
    expect(find.text('记得'), findsOneWidget);
  });

  testWidgets('学习页：评分后推进到下一张', (tester) async {
    final repo = FakeStudyRepository([
      StudyCard(word: makeWord(1, 'alpha'), state: makeState(1)),
      StudyCard(word: makeWord(2, 'beta'), state: makeState(2)),
    ]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);

    // 翻面并选「记得」
    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('记得'));
    await tester.pumpAndSettle();

    expect(repo.rated, [2]);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('2 / 2'), findsOneWidget);

    // 学完最后一张 → 完成页
    await tester.tap(find.byType(GestureDetector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('模糊'));
    await tester.pumpAndSettle();
    expect(find.text('今日学习完成！'), findsOneWidget);
  });

  testWidgets('学习页：空队列显示完成页', (tester) async {
    final repo = FakeStudyRepository([]);
    await tester.pumpWidget(buildApp(repo));
    await tester.pumpAndSettle();
    expect(find.text('今日学习完成！'), findsOneWidget);
  });
}
