import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'memory_match_screen.dart';
import 'time_challenge_screen.dart';
import 'word_chain_screen.dart';

/// 趣味玩法：选择词书后进入各玩法。
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key});

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  String? _bookId;

  @override
  Widget build(BuildContext context) {
    final booksAsync = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('趣味玩法')),
      body: booksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (books) {
          final bookId = _bookId ?? (books.isNotEmpty ? books.first.id : null);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _bookSelector(context, books, bookId),
              const SizedBox(height: 16),
              _GameCard(
                icon: Icons.timer,
                color: Colors.deepOrange,
                title: '限时挑战',
                description: '60 秒看释义选单词，连击加分',
                enabled: bookId != null,
                onTap: () => _start(TimeChallengeScreen(bookId: bookId!)),
              ),
              _GameCard(
                icon: Icons.style,
                color: Colors.teal,
                title: '记忆翻牌',
                description: '翻牌配对单词与释义，挑战最少步数',
                enabled: bookId != null,
                onTap: () => _start(MemoryMatchScreen(bookId: bookId!)),
              ),
              _GameCard(
                icon: Icons.link,
                color: Colors.indigo,
                title: '单词接龙',
                description: '用末字母接下一个词，拼写挑战（可提示）',
                enabled: bookId != null,
                onTap: () => _start(WordChainScreen(bookId: bookId!)),
              ),
            ],
          );
        },
      ),
    );
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

  void _start(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _GameCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onTap;

  const _GameCard({
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
      margin: const EdgeInsets.only(bottom: 12),
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
