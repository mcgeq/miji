import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';

/// 记账模块的通知设置。
///
/// 之前这些语义是散的：预算提醒开关和阈值在预算表单里、每日汇总是硬编码
/// 20:00 且无法关闭、账单提醒的时间根本不存在（只有打开 App 才扫一次）。
/// 这里统一成一个实体，UI 只需要面对一份配置。
class MoneyReminderSettings {
  const MoneyReminderSettings({
    this.enabled = true,
    this.notifyHour = 9,
    this.notifyMinute = 0,
    this.dailyDigestEnabled = true,
    this.digestHour = 20,
    this.digestMinute = 0,
    this.dailyLogReminderEnabled = false,
    this.logReminderHour = 21,
    this.logReminderMinute = 0,
  });

  /// 记账通知总开关。关掉后不再预约任何提醒 / 汇总 / 每日记账提醒。
  final bool enabled;

  /// 账单到期提醒的推送时间。
  final int notifyHour;
  final int notifyMinute;

  /// 每日汇总：当天有待处理提醒时的兜底推送。
  final bool dailyDigestEnabled;
  final int digestHour;
  final int digestMinute;

  /// 每日记账提醒：当天还没记过账时的晚间提醒。
  ///
  /// 默认关闭——它是一天一次的主动打扰，只对"想养成记账习惯"的人有用，
  /// 对只想被账单提醒的人是无谓噪声。
  final bool dailyLogReminderEnabled;
  final int logReminderHour;
  final int logReminderMinute;

  static const defaults = MoneyReminderSettings();

  TimeOfDay get notifyTime => TimeOfDay(hour: notifyHour, minute: notifyMinute);
  TimeOfDay get digestTime => TimeOfDay(hour: digestHour, minute: digestMinute);
  TimeOfDay get logReminderTime =>
      TimeOfDay(hour: logReminderHour, minute: logReminderMinute);

  MoneyReminderSettings copyWith({
    bool? enabled,
    int? notifyHour,
    int? notifyMinute,
    bool? dailyDigestEnabled,
    int? digestHour,
    int? digestMinute,
    bool? dailyLogReminderEnabled,
    int? logReminderHour,
    int? logReminderMinute,
  }) {
    return MoneyReminderSettings(
      enabled: enabled ?? this.enabled,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      digestHour: digestHour ?? this.digestHour,
      digestMinute: digestMinute ?? this.digestMinute,
      dailyLogReminderEnabled:
          dailyLogReminderEnabled ?? this.dailyLogReminderEnabled,
      logReminderHour: logReminderHour ?? this.logReminderHour,
      logReminderMinute: logReminderMinute ?? this.logReminderMinute,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'notifyHour': notifyHour,
      'notifyMinute': notifyMinute,
      'dailyDigestEnabled': dailyDigestEnabled,
      'digestHour': digestHour,
      'digestMinute': digestMinute,
      'dailyLogReminderEnabled': dailyLogReminderEnabled,
      'logReminderHour': logReminderHour,
      'logReminderMinute': logReminderMinute,
    };
  }

  static MoneyReminderSettings fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return defaults;
    }
    int intValue(Object? value, int fallback) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.round();
      }
      return fallback;
    }

    bool boolValue(Object? value, bool fallback) {
      return value is bool ? value : fallback;
    }

    final base = defaults;
    return MoneyReminderSettings(
      enabled: boolValue(raw['enabled'], base.enabled),
      notifyHour: intValue(
        raw['notifyHour'],
        base.notifyHour,
      ).clamp(0, 23).toInt(),
      notifyMinute: intValue(
        raw['notifyMinute'],
        base.notifyMinute,
      ).clamp(0, 59).toInt(),
      dailyDigestEnabled: boolValue(
        raw['dailyDigestEnabled'],
        base.dailyDigestEnabled,
      ),
      digestHour: intValue(
        raw['digestHour'],
        base.digestHour,
      ).clamp(0, 23).toInt(),
      digestMinute: intValue(
        raw['digestMinute'],
        base.digestMinute,
      ).clamp(0, 59).toInt(),
      dailyLogReminderEnabled: boolValue(
        raw['dailyLogReminderEnabled'],
        base.dailyLogReminderEnabled,
      ),
      logReminderHour: intValue(
        raw['logReminderHour'],
        base.logReminderHour,
      ).clamp(0, 23).toInt(),
      logReminderMinute: intValue(
        raw['logReminderMinute'],
        base.logReminderMinute,
      ).clamp(0, 59).toInt(),
    );
  }
}

/// 按用户隔离的设置存储。
///
/// 多用户共用设备时，后登录的人不应该继承前一个人的提醒时间。
abstract final class MoneyReminderSettingsStore {
  static String _keyFor(String userId) => 'money_reminder_settings_$userId';

  static Future<MoneyReminderSettings> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(userId));
    if (raw == null || raw.isEmpty) {
      return MoneyReminderSettings.defaults;
    }
    try {
      return MoneyReminderSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return MoneyReminderSettings.defaults;
    }
  }

  static Future<void> save(
    String userId,
    MoneyReminderSettings settings,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(userId), jsonEncode(settings.toJson()));
  }
}

final moneyReminderSettingsProvider =
    AsyncNotifierProvider<
      MoneyReminderSettingsController,
      MoneyReminderSettings
    >(MoneyReminderSettingsController.new);

class MoneyReminderSettingsController
    extends AsyncNotifier<MoneyReminderSettings> {
  @override
  Future<MoneyReminderSettings> build() async {
    final userId = ref.watch(authSessionControllerProvider).userId;
    if (userId == null || userId.isEmpty) {
      return MoneyReminderSettings.defaults;
    }
    return MoneyReminderSettingsStore.load(userId);
  }

  /// 写回设置并刷新状态。返回是否落盘成功。
  ///
  /// 方法名不能叫 `update`：`AsyncNotifier` 本身有一个签名不同的 `update`，
  /// 同名会被当成非法覆写。
  Future<bool> save(MoneyReminderSettings settings) async {
    final userId = ref.read(authSessionControllerProvider).userId;
    state = AsyncData(settings);
    if (userId == null || userId.isEmpty) {
      return false;
    }
    try {
      await MoneyReminderSettingsStore.save(userId, settings);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveWith(
    MoneyReminderSettings Function(MoneyReminderSettings current) transform,
  ) async {
    final current = state.value ?? MoneyReminderSettings.defaults;
    return save(transform(current));
  }
}
