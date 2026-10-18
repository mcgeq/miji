import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 时薪面板「上次停在哪」：面板分段、清单排序、年度账的年份。
///
/// 为什么需要它：这三处都是**每天打开就会看到**的界面位置，不记的话用户固定
/// 用「代价最高」排序、或者每年年底都要回看同一年的账，每次都得重新点一遍。
///
/// 存在 `user_preferences.life_energy_prefs` 的一列 JSON 里，理由见那一列的
/// 注释：它们永远一起读写，每加一项都做一次迁移不值。
@immutable
class LifeEnergyPrefs {
  const LifeEnergyPrefs({this.tab, this.sort, this.payrollYear});

  static const empty = LifeEnergyPrefs();

  /// 面板分段：`convert` / `wishlist`。null = 默认「换算」。
  final String? tab;

  /// 清单排序：`recent` / `cost` / `desire` / `dueSoon`。null = 默认「最近加入」。
  final String? sort;

  /// 年度账上次看的年份。null = 跟随「今年」。
  final int? payrollYear;

  LifeEnergyPrefs copyWith({
    String? tab,
    String? sort,
    int? payrollYear,
    bool clearPayrollYear = false,
  }) {
    return LifeEnergyPrefs(
      tab: tab ?? this.tab,
      sort: sort ?? this.sort,
      payrollYear: clearPayrollYear ? null : (payrollYear ?? this.payrollYear),
    );
  }

  Map<String, Object?> toJson() => {
    if (tab != null) 'tab': tab,
    if (sort != null) 'sort': sort,
    if (payrollYear != null) 'payrollYear': payrollYear,
  };

  /// 读偏好。坏 JSON、类型不对、多出来的键都不许抛 —— 这个值只决定「界面停
  /// 在哪」，读坏了退回默认即可，不值得让整个面板打不开。
  factory LifeEnergyPrefs.fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return LifeEnergyPrefs.empty;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return LifeEnergyPrefs.empty;
      }
      final year = decoded['payrollYear'];
      return LifeEnergyPrefs(
        tab: decoded['tab'] is String ? decoded['tab'] as String : null,
        sort: decoded['sort'] is String ? decoded['sort'] as String : null,
        // JSON 里的年份是 num；只接受像样的年份，免得把脏数据当成年份传下去。
        payrollYear: year is num && year >= 1970 && year <= 3000
            ? year.toInt()
            : null,
      );
    } on FormatException {
      return LifeEnergyPrefs.empty;
    }
  }

  String encode() => jsonEncode(toJson());
}
