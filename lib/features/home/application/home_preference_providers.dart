import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';

/// 首页是否显示健康窄条。
final homeShowHealthStripProvider = Provider<bool>((ref) {
  return ref
          .watch(currentUserPreferencesProvider)
          .maybeWhen(
            data: (preferences) => preferences?.showHomeHealthStrip,
            orElse: () => null,
          ) ??
      false;
});

/// 首页是否显示今日行动卡片。
final homeShowTodayActionProvider = Provider<bool>((ref) {
  return ref
          .watch(currentUserPreferencesProvider)
          .maybeWhen(
            data: (preferences) => preferences?.showHomeTodayAction,
            orElse: () => null,
          ) ??
      true;
});
