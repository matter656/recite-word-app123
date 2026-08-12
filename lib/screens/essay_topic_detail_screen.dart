import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/essay.dart';
import '../providers/app_providers.dart';
import 'essay_practice_screen.dart';

/// 题材详情：模板 / 范文 / 句式 + 写作练习入口。
class EssayTopicDetailScreen extends ConsumerStatefulWidget {
  final EssayExam exam;
  final EssayTopic topic;

  const EssayTopicDetailScreen({
    super.key,
    required this.exam,
    required this.topic,
  });

  @override
  ConsumerState<EssayTopicDetailScreen> createState() =>
      _EssayTopicDetailScreenState();
}

class _EssayTopicDetailScreenState
    extends ConsumerState<EssayTopicDetailScreen> {
  EssayTemplate? _template;
  List<EssaySample> _samples = const [];
  List<SentenceCategory> _sentences = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(essayRepositoryProvider);
      final template = await repo.getTemplate(widget.topic.id);
      final samples = await repo.getSamples(widget.topic.id);
      final sentences = await repo.getSentenceCategories();
      if (!mounted) return;
      setState(() {
        _template = template;
        _samples = samples;
        _sentences = sentences;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.topic.name),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => EssayPracticeScreen(
                    exam: widget.exam,
                    topic: widget.topic,
                  ),
                ));
              },
              icon: const Icon(Icons.edit_note),
              label: const Text('去练习'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '模板'),
              Tab(text: '范文'),
              Tab(text: '句式'),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败：$_error'),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    return TabBarView(
      children: [
        _TemplateTab(template: _template!),
        _SamplesTab(samples: _samples),
        _SentencesTab(sentences: _sentences),
      ],
    );
  }
}

class _TemplateTab extends StatelessWidget {
  final EssayTemplate template;
  const _TemplateTab({required this.template});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(template.title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        for (final part in template.parts) _PartCard(part: part),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('完整模板',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: '复制模板',
                      onPressed: () {
                        Clipboard.setData(
                            ClipboardData(text: template.fullTemplate));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('模板已复制，去粘贴到文档里写吧')),
                        );
                      },
                    ),
                  ],
                ),
                SelectableText(
                  template.fullTemplate,
                  style: const TextStyle(height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PartCard extends StatelessWidget {
  final TemplatePart part;
  const _PartCard({required this.part});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(part.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: scheme.primary)),
            const SizedBox(height: 6),
            for (final s in part.sentences)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(color: scheme.primary)),
                    Expanded(child: Text(s, style: const TextStyle(height: 1.4))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SamplesTab extends StatelessWidget {
  final List<EssaySample> samples;
  const _SamplesTab({required this.samples});

  @override
  Widget build(BuildContext context) {
    if (samples.isEmpty) {
      return const Center(child: Text('暂无范文'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [for (final s in samples) _SampleCard(sample: s)],
    );
  }
}

class _SampleCard extends StatelessWidget {
  final EssaySample sample;
  const _SampleCard({required this.sample});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(sample.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(sample.prompt,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('范文',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SelectableText(sample.essay, style: const TextStyle(height: 1.6)),
          const SizedBox(height: 12),
          const Text('参考译文',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          SelectableText(sample.translation,
              style: TextStyle(
                  height: 1.6, color: Colors.grey.shade800)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('💡 ${sample.comment}',
                style: const TextStyle(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _SentencesTab extends StatelessWidget {
  final List<SentenceCategory> sentences;
  const _SentencesTab({required this.sentences});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final cat in sentences) _SentenceCard(cat: cat),
      ],
    );
  }
}

class _SentenceCard extends StatelessWidget {
  final SentenceCategory cat;
  const _SentenceCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cat.name,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: scheme.primary)),
            const SizedBox(height: 6),
            for (final s in cat.sentences)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $s', style: const TextStyle(height: 1.4)),
              ),
          ],
        ),
      ),
    );
  }
}
