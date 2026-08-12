import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/app_providers.dart';
import 'essay_home_screen.dart';
import 'games_screen.dart';
import 'listening_home_screen.dart';
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
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _GamesEntryCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const GamesScreen(),
                    )),
                  ),
                  _EssayEntryCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const EssayHomeScreen(),
                    )),
                  ),
                  _ListeningEntryCard(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ListeningHomeScreen(),
                    )),
                  ),
                  const SizedBox(height: 4),
                  for (final book in books) _BookCard(book: book),
                ],
              ),
      ),
    );
  }
}

/// 趣味玩法入口卡片。
class _GamesEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _GamesEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.primaryContainer,
      child: ListTile(
        leading: const Icon(Icons.sports_esports, color: Colors.deepOrange),
        title: Text('趣味玩法',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: scheme.onPrimaryContainer)),
        subtitle: Text('限时挑战 · 记忆翻牌 · 单词接龙',
            style: TextStyle(color: scheme.onPrimaryContainer)),
        trailing: Icon(Icons.chevron_right, color: scheme.onPrimaryContainer),
        onTap: onTap,
      ),
    );
  }
}

/// 作文写作入口卡片。
class _EssayEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _EssayEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.edit_note, color: Colors.teal),
        title: Text('作文写作',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onSecondaryContainer)),
        subtitle: Text('考研/四六级模板 · 范文 · 句式 · 写作练习',
            style: TextStyle(color: scheme.onSecondaryContainer)),
        trailing: Icon(Icons.chevron_right, color: scheme.onSecondaryContainer),
        onTap: onTap,
      ),
    );
  }
}

/// 英语听力入口卡片。
class _ListeningEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ListeningEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: const Icon(Icons.headphones, color: Colors.deepPurple),
        title: Text('英语听力',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: scheme.onTertiaryContainer)),
        subtitle: Text('听音选词 · 听句理解 · 跟读回放 · 短文听力',
            style: TextStyle(color: scheme.onTertiaryContainer)),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: onTap,
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
