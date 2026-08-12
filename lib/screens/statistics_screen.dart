import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/statistics_repository.dart';
import '../providers/app_providers.dart';

/// 统计页：打卡、今日学习、各词书进度。
class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(bookStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('学习统计')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bookStatsProvider);
            ref.invalidate(streakProvider);
            ref.invalidate(todayLearnedProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SummaryCard(),
              const SizedBox(height: 20),
              Text('词书进度',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...stats.map((s) => _BookProgressCard(stats: s)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);
    final today = ref.watch(todayLearnedProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: _StatItem(
                icon: Icons.local_fire_department,
                color: Colors.deepOrange,
                value: streak.when(
                    data: (v) => '$v 天', loading: () => '—', error: (_, _) => '—'),
                label: '连续打卡',
              ),
            ),
            Container(width: 1, height: 48, color: Colors.grey.shade300),
            Expanded(
              child: _StatItem(
                icon: Icons.today,
                color: Colors.indigo,
                value: today.when(
                    data: (v) => '$v 词', loading: () => '—', error: (_, _) => '—'),
                label: '今日已学',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _BookProgressCard extends StatelessWidget {
  final BookStats stats;
  const _BookProgressCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(stats.book.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text('${stats.learned} / ${stats.book.wordCount}',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: stats.progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _chip(context, '待复习 ${stats.due}', Colors.orange),
                const SizedBox(width: 8),
                _chip(context, '已掌握 ${stats.mastered}', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: color.shade800)),
    );
  }
}
