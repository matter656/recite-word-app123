import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/listening.dart';
import '../providers/app_providers.dart';
import 'listening_quiz_screen.dart';
import 'repeat_screen.dart';
import 'short_article_screen.dart';

/// 听力模块首页：听音选词 / 听句理解 / 跟读回放 + 短文听力。
class ListeningHomeScreen extends ConsumerStatefulWidget {
  const ListeningHomeScreen({super.key});

  @override
  ConsumerState<ListeningHomeScreen> createState() =>
      _ListeningHomeScreenState();
}

class _ListeningHomeScreenState extends ConsumerState<ListeningHomeScreen> {
  String? _bookId;

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);
    final articlesAsync = ref.watch(listeningArticlesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('英语听力')),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (books) {
          final bookId = _bookId ?? (books.isNotEmpty ? books.first.id : null);
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _bookSelector(context, books, bookId),
              const SizedBox(height: 12),
              _ModeCard(
                icon: Icons.headphones,
                color: Colors.deepPurple,
                title: '听音选词',
                description: '听单词发音，四选一选释义（计时连击）',
                enabled: bookId != null,
                onTap: () => _push(ListeningQuizScreen(
                  bookId: bookId!,
                  bookName: books.firstWhere((b) => b.id == bookId).name,
                  mode: ListeningQuizMode.word,
                )),
              ),
              _ModeCard(
                icon: Icons.record_voice_over,
                color: Colors.blue,
                title: '听句理解',
                description: '听例句发音，四选一选句子大意',
                enabled: bookId != null,
                onTap: () => _push(ListeningQuizScreen(
                  bookId: bookId!,
                  bookName: books.firstWhere((b) => b.id == bookId).name,
                  mode: ListeningQuizMode.example,
                )),
              ),
              _ModeCard(
                icon: Icons.mic,
                color: Colors.teal,
                title: '跟读回放',
                description: '听原音 → 录音跟读 → 回放对比',
                enabled: bookId != null,
                onTap: () => _push(RepeatScreen(bookId: bookId!)),
              ),
              const Divider(height: 32),
              Text('短文听力',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              articlesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载失败：$e'),
                data: (articles) => Column(
                  children: [
                    for (final a in articles)
                      _articleTile(context, a),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Widget _bookSelector(BuildContext context, List books, String? bookId) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.menu_book_outlined),
            const SizedBox(width: 12),
            const Text('词书：'),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: bookId,
                  isExpanded: true,
                  items: [
                    for (final b in books)
                      DropdownMenuItem(value: b.id, child: Text(b.name)),
                  ],
                  onChanged: (v) => setState(() => _bookId = v),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _articleTile(BuildContext context, ListeningArticle a) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.amber.shade100,
          child: Text(a.level[0],
              style: TextStyle(color: Colors.amber.shade900)),
        ),
        title: Text(a.title),
        subtitle: Text('${a.topic} · 级别：${a.level} · ${a.questions.length} 题'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _push(ShortArticleScreen(article: a)),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        enabled: enabled,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
