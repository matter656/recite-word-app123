import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/app_providers.dart';
import 'learned_words_screen.dart';
import 'study_screen.dart';

/// 复习模块：今日到期复习词总览 + 按书复习 + 学过的词管理。
class ReviewHomeScreen extends ConsumerStatefulWidget {
  const ReviewHomeScreen({super.key});

  @override
  ConsumerState<ReviewHomeScreen> createState() => _ReviewHomeScreenState();
}

class _ReviewHomeScreenState extends ConsumerState<ReviewHomeScreen> {
  Map<String, int>? _byBook;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final byBook =
        await ref.read(studyRepositoryProvider).getReviewCountByBook();
    if (!mounted) return;
    setState(() {
      _byBook = byBook;
      _loading = false;
    });
  }

  void _startReview({String? bookId, String bookName = '全部词书'}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyScreen(
        bookId: bookId,
        bookName: bookName,
        reviewMode: true,
      ),
    )).then((_) {
      // 复习完成返回：刷新角标与本页
      ref.invalidate(reviewCountProvider);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final countAsync = ref.watch(reviewCountProvider);
    final total = countAsync.value ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('复习')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(reviewCountProvider);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    color: total > 0
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Text(
                            total > 0 ? '今日待复习 $total 个单词' : '今日没有待复习的单词 🎉',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            total > 0
                                ? '按记忆曲线安排，及时复习效果最好'
                                : '学过的单词会在到期后自动出现在这里',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  total > 0 ? () => _startReview() : null,
                              icon: const Icon(Icons.play_arrow),
                              label: Text(total > 0 ? '开始复习全部' : '暂无复习任务'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('按词书复习',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  ...booksAsync.valueOrNull?.map(
                        (b) => _bookTile(context, b, _byBook![b.id] ?? 0),
                      ) ??
                      const [],
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.library_books_outlined),
                    ),
                    title: const Text('学过的单词'),
                    subtitle: const Text('查看所有学过的词，可重新学习'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const LearnedWordsScreen(),
                      ));
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _bookTile(BuildContext context, Book book, int due) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(book.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (due > 0)
              Text('待复习 $due',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _startReview(bookId: book.id, bookName: book.name),
      ),
    );
  }
}
