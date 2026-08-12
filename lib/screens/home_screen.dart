import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/app_providers.dart';
import 'study_screen.dart';

/// 首页：词书列表与入口。
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('背单词')),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (books) => books.isEmpty
            ? const Center(child: Text('暂无词书，请先导入词库'))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: books.length,
                itemBuilder: (context, i) => _BookCard(book: books[i]),
              ),
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  final Book book;
  const _BookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(Icons.menu_book, color: scheme.onPrimaryContainer),
        ),
        title: Text(book.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${book.description}\n共 ${book.wordCount} 词'),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => StudyScreen(bookId: book.id, bookName: book.name),
          ));
        },
      ),
    );
  }
}
