import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/essay.dart';
import '../providers/app_providers.dart';

/// 我的作文：保存的草稿列表，可查看与删除。
class MyEssaysScreen extends ConsumerStatefulWidget {
  const MyEssaysScreen({super.key});

  @override
  ConsumerState<MyEssaysScreen> createState() => _MyEssaysScreenState();
}

class _MyEssaysScreenState extends ConsumerState<MyEssaysScreen> {
  List<EssayDraft>? _drafts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final drafts =
        await ref.read(essayRepositoryProvider).getDrafts();
    if (!mounted) return;
    setState(() {
      _drafts = drafts;
      _loading = false;
    });
  }

  Future<void> _delete(EssayDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这篇作文？'),
        content: const Text('删除后无法恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(essayRepositoryProvider).deleteDraft(draft.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已删除')));
    _load();
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的作文')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drafts!.isEmpty
              ? const Center(
                  child: Text('还没有写过作文，去「写作练习」写一篇吧'),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _drafts!.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final d = _drafts![i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.article_outlined),
                          title: Text(
                            d.prompt.length > 40
                                ? '${d.prompt.substring(0, 40)}…'
                                : d.prompt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                              '${_fmtDate(d.createdAt)} · ${d.wordCount} 词'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: '删除',
                            onPressed: () => _delete(d),
                          ),
                          onTap: () => _showDetail(d),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showDetail(EssayDraft d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: controller,
            children: [
              Text('${_fmtDate(d.createdAt)} · ${d.wordCount} 词',
                  style: Theme.of(ctx).textTheme.bodySmall),
              const SizedBox(height: 8),
              SelectableText(d.prompt,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const Divider(height: 24),
              SelectableText(d.content,
                  style: const TextStyle(height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}
