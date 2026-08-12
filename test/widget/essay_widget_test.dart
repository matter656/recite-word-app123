import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocab_app/screens/essay_home_screen.dart';

void main() {
  testWidgets('作文首页：显示考研与四六级考试类别，展开后见题材', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: EssayHomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('考研英语'), findsOneWidget);
    expect(find.text('大学英语四六级'), findsOneWidget);

    // 展开考研英语
    await tester.tap(find.text('考研英语'));
    await tester.pumpAndSettle();
    expect(find.text('图画作文（大作文）'), findsOneWidget);
    expect(find.text('书信（小作文）'), findsOneWidget);

    // 展开四六级
    await tester.tap(find.text('大学英语四六级'));
    await tester.pumpAndSettle();
    expect(find.text('议论文'), findsOneWidget);
  });
}
