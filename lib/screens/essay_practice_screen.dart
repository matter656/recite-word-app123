import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/essay_repository.dart';
import '../models/essay.dart';
import '../providers/app_providers.dart';
import 'my_essays_screen.dart';

/// 写作练习：选题目 → 写作（实时字数）→ 保存到本地。
class EssayPracticeScreen extends ConsumerStatefulWidget {
  final EssayExam exam;
  final EssayTopic topic;

  const EssayPracticeScreen({
    super.key,
    required this.exam,
    required this.topic,
  });

  @override
  ConsumerState<EssayPracticeScreen> createState() =>
      _EssayPracticeScreenState();
}

class _EssayPracticeScreenState extends ConsumerState<EssayPracticeScreen> {
  final _controller = TextEditingController();
  late String _prompt;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _prompt = widget.topic.practicePrompts.first;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _wordCount => EssayRepository.countWords(_controller.text);

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('先写点内容再保存吧')));
      return;
    }
    final repo = ref.read(essayRepositoryProvider);
    await repo.saveDraft(EssayDraft(
      id: 0,
      examId: widget.exam.id,
      topicId: widget.topic.id,
      prompt: _prompt,
      content: content,
      wordCount: _wordCount,
      createdAt: DateTime.now(),
    ));
    if (!mounted) return;
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已保存！可以去「我的作文」查看')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('写作练习 · ${widget.topic.name}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '我的作文',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MyEssaysScreen(),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('题目',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        if (widget.topic.practicePrompts.length > 1)
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _prompt,
                              isDense: true,
                              items: [
                                for (var i = 0;
                                    i < widget.topic.practicePrompts.length;
                                    i++)
                                  DropdownMenuItem(
                                    value: widget.topic.practicePrompts[i],
                                    child: Text('题目 ${i + 1}'),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _prompt = v ?? _prompt),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(_prompt, style: const TextStyle(height: 1.5)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '在这里写你的作文…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_wordCount 词'
                      '${widget.exam.id == 'kaoyan' && widget.topic.id == 'picture' ? '（目标 160-200）' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _saved ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_saved ? '已保存' : '保存'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
