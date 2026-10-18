import 'package:flutter/material.dart';

import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';

enum AppThemeModePreference {
  system,
  light,
  dark;

  static AppThemeModePreference fromStorageValue(String value) {
    return switch (value) {
      'light' => AppThemeModePreference.light,
      'dark' => AppThemeModePreference.dark,
      _ => AppThemeModePreference.system,
    };
  }

  String get storageValue {
    return switch (this) {
      AppThemeModePreference.system => 'system',
      AppThemeModePreference.light => 'light',
      AppThemeModePreference.dark => 'dark',
    };
  }
}

extension AppThemeModePreferenceX on AppThemeModePreference {
  ThemeMode get themeMode {
    return switch (this) {
      AppThemeModePreference.system => ThemeMode.system,
      AppThemeModePreference.light => ThemeMode.light,
      AppThemeModePreference.dark => ThemeMode.dark,
    };
  }
}

class UserPreferencesEntity {
  const UserPreferencesEntity({
    required this.userId,
    required this.themeMode,
    required this.sensitiveAccessTtl,
    required this.createdAt,
    required this.updatedAt,
    this.locale,
    this.timezone,
    this.currencyCode,
    this.showHomeTodayAction = true,
    this.maskMoneyAmounts = false,
    this.showHomeHealthStrip = false,
    this.homeBlockVisibility,
    this.homeBlockOrder,
    this.homeLayoutMode = 'pager',
    this.homePagerTabs = false,
    this.lifeEnergyPrefs,
  });

  final String userId;
  final AppThemeModePreference themeMode;
  final SensitiveAccessTtlOption sensitiveAccessTtl;
  final String? locale;
  final String? timezone;
  final String? currencyCode;
  final bool showHomeTodayAction;

  /// 首页金额隐私：开启后所有金额以模糊 / 占位方式展示。
  final bool maskMoneyAmounts;

  /// 首页是否显示健康窄条。v2 起由区块注册表控制，此字段保留向后兼容。
  final bool showHomeHealthStrip;

  /// 首页区块可见性 JSON。
  final String? homeBlockVisibility;

  /// 首页区块顺序 JSON。
  final String? homeBlockOrder;

  /// 首页布局：`list` / `pager`（默认）。
  final String homeLayoutMode;

  /// 横向分页是否显示顶部标签。
  final bool homePagerTabs;

  /// 时薪面板的界面偏好 JSON（分段 / 清单排序 / 年度账年份）。
  final String? lifeEnergyPrefs;

  final DateTime createdAt;
  final DateTime updatedAt;
}
