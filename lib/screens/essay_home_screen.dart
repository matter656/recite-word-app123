import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/essay.dart';
import '../providers/app_providers.dart';
import 'essay_topic_detail_screen.dart';

/// 作文模块首页：考试类别 → 题材列表。
class EssayHomeScreen extends ConsumerWidget {
  const EssayHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(essayExamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('作文写作')),
      body: examsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (exams) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final exam in exams) _ExamCard(exam: exam),
            const SizedBox(height: 8),
            Text(
              '技巧：先看模板掌握结构，再读范文学习表达，最后用「写作练习」实战。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  final EssayExam exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: scheme.secondaryContainer,
          child: Icon(Icons.school, color: scheme.onSecondaryContainer),
        ),
        title: Text(exam.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(exam.description),
        children: [
          for (final topic in exam.topics)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(topic.name),
              subtitle: Text(topic.description),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      EssayTopicDetailScreen(exam: exam, topic: topic),
                ));
              },
            ),
        ],
      ),
    );
  }
}
