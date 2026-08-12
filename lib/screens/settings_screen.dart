import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import '../services/notification_service.dart';

/// 设置页：每日新词数、每日提醒。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _dailyNewWords = kDefaultDailyNewWords;
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(settingsRepositoryProvider);
    final daily = await repo.getDailyNewWords();
    final enabled = await repo.getReminderEnabled();
    final time = await repo.getReminderTime();
    if (!mounted) return;
    setState(() {
      _dailyNewWords = daily;
      _reminderEnabled = enabled;
      _reminderTime = time;
      _loaded = true;
    });
  }

  Future<void> _saveDailyNewWords(int v) async {
    setState(() => _dailyNewWords = v);
    await ref.read(settingsRepositoryProvider).setDailyNewWords(v);
    ref.invalidate(dailyNewWordsProvider);
  }

  Future<void> _toggleReminder(bool v) async {
    setState(() => _reminderEnabled = v);
    await ref.read(settingsRepositoryProvider).setReminderEnabled(v);
    if (v) {
      await NotificationService.scheduleDaily(_reminderTime);
    } else {
      await NotificationService.cancel();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: '选择每日提醒时间',
    );
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    await ref.read(settingsRepositoryProvider).setReminderTime(picked);
    if (_reminderEnabled) {
      await NotificationService.scheduleDaily(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _section('学习'),
                ListTile(
                  title: const Text('每日新词数'),
                  subtitle: Text('每次学习新引入的单词上限：$_dailyNewWords 个'),
                  trailing: SizedBox(
                    width: 200,
                    child: Slider(
                      value: _dailyNewWords.toDouble(),
                      min: 5,
                      max: 50,
                      divisions: 9,
                      label: '$_dailyNewWords',
                      onChanged: (v) => _saveDailyNewWords(v.round()),
                    ),
                  ),
                ),
                const Divider(),
                _section('提醒'),
                SwitchListTile(
                  title: const Text('每日提醒'),
                  subtitle: Text('每天 $_reminderTime 提醒背单词'),
                  value: _reminderEnabled,
                  onChanged: _toggleReminder,
                ),
                ListTile(
                  enabled: _reminderEnabled,
                  title: const Text('提醒时间'),
                  trailing: Text(_reminderTime.format(context)),
                  onTap: _pickTime,
                ),
                const Divider(),
                _section('关于'),
                const ListTile(
                  title: Text('词库来源'),
                  subtitle:
                      Text('词表与释义：ECDICT（MIT 协议）\n例句：Tatoeba（CC-BY 2.0）'),
                  isThreeLine: true,
                ),
              ],
            ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
