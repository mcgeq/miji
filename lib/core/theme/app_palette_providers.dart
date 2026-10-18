import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/theme/app_palette.dart';

/// 当前配色 id。
///
/// 为什么不进 `user_preferences` 表：配色是**这台设备看着顺眼**的事，
/// 不是账号数据。同一账号在手机和平板上选不同配色是合理需求，
/// 而且加一列要跑 drift 迁移 + codegen，代价和收益不成比例。
/// 所以走 `SharedPreferences`，与「敏感操作有效期」那类设备级偏好同一层。
final themePaletteIdProvider = NotifierProvider<ThemePaletteController, String>(
  ThemePaletteController.new,
);

class ThemePaletteController extends Notifier<String> {
  static const _storageKey = 'theme_palette_id';

  @override
  String build() {
    unawaited(_restore());
    return AppPalettes.defaultId;
  }

  /// 切换配色。**先改内存状态再落盘**：`MaterialApp` 立刻开始 420ms 过渡，
  /// 用户点下去就有反馈；写盘失败也只影响下次启动，不该卡住这次点击。
  void select(String paletteId) {
    final next = AppPalettes.byId(paletteId).id;
    if (next == state) {
      return;
    }
    state = next;
    unawaited(_persist(next));
  }

  Future<void> _restore() async {
    String? stored;
    try {
      final preferences = await SharedPreferences.getInstance();
      stored = preferences.getString(_storageKey);
    } catch (_) {
      // 读不到就保持默认配色，不让启动失败。
      return;
    }

    if (stored == null || stored.isEmpty) {
      return;
    }

    // 用 byId 归一化：存档里是个未知 id（降级、手改）时它会退回默认，
    // 于是这里不会把状态设成一个不存在的配色。
    final restored = AppPalettes.byId(stored).id;
    if (restored != state) {
      state = restored;
    }
  }

  Future<void> _persist(String paletteId) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_storageKey, paletteId);
    } catch (_) {
      // 落盘是 best-effort：本次会话已经切过去了。
    }
  }
}
