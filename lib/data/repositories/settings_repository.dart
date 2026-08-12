import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_providers.dart';

/// 用户设置（shared_preferences 持久化）。
class SettingsRepository {
  static const _kDailyNewWords = 'daily_new_words';
  static const _kReminderEnabled = 'reminder_enabled';
  static const _kReminderHour = 'reminder_hour';
  static const _kReminderMinute = 'reminder_minute';

  Future<int> getDailyNewWords() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kDailyNewWords) ?? kDefaultDailyNewWords;
  }

  Future<void> setDailyNewWords(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kDailyNewWords, count);
  }

  Future<bool> getReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kReminderEnabled) ?? false;
  }

  Future<void> setReminderEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kReminderEnabled, enabled);
  }

  Future<TimeOfDay> getReminderTime() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_kReminderHour) ?? 20,
      minute: prefs.getInt(_kReminderMinute) ?? 0,
    );
  }

  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReminderHour, time.hour);
    await prefs.setInt(_kReminderMinute, time.minute);
  }
}
