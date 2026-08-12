import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'home_screen.dart';
import 'review_home_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';

/// 主框架：底部导航（词书 / 复习 / 统计 / 设置），复习带今日待复习角标。
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    ReviewHomeScreen(),
    StatisticsScreen(),
    SettingsScreen(),
  ];

  void _onDestinationSelected(int i) {
    if (i == 1) {
      // 切到复习 tab：刷新角标
      ref.invalidate(reviewCountProvider);
    }
    if (i == 2) {
      // 切到统计 tab：刷新统计数据
      ref.invalidate(bookStatsProvider);
      ref.invalidate(streakProvider);
      ref.invalidate(todayLearnedProvider);
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final reviewCount = ref.watch(reviewCountProvider);
    final badge = reviewCount.when(
      data: (n) => n > 0 ? n : null,
      loading: () => null,
      error: (_, _) => null,
    );

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '词书',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: badge != null,
              label: Text('$badge'),
              child: const Icon(Icons.history),
            ),
            selectedIcon: Badge(
              isLabelVisible: badge != null,
              label: Text('$badge'),
              child: const Icon(Icons.history),
            ),
            label: '复习',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '统计',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
