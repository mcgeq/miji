import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';

/// 首页区块布局（可见性 + 顺序）。解析失败自动回落默认。
final homeBlockLayoutProvider = Provider<HomeBlockLayout>((ref) {
  final preferences = ref.watch(currentUserPreferencesProvider).asData?.value;
  return HomeBlockLayout.fromStorage(
    visibilityJson: preferences?.homeBlockVisibility,
    orderJson: preferences?.homeBlockOrder,
  );
});

/// 统一入口：某区块是否可见。
final homeBlockVisibleProvider = Provider.family<bool, HomeBlockId>((ref, id) {
  return ref.watch(homeBlockLayoutProvider).isVisible(id);
});

/// 首页布局模式（纵向单列 / 横向分页）。默认横向分页。
final homeLayoutModeProvider = Provider<HomeLayoutMode>((ref) {
  final preferences = ref.watch(currentUserPreferencesProvider).asData?.value;
  return HomeLayoutMode.fromStorage(preferences?.homeLayoutMode);
});

/// 横向分页是否显示顶部标签（默认关，靠滑动 + 圆点）。
final homePagerTabsProvider = Provider<bool>((ref) {
  return ref
          .watch(currentUserPreferencesProvider)
          .maybeWhen(
            data: (preferences) => preferences?.homePagerTabs,
            orElse: () => null,
          ) ??
      false;
});

/// 健康区块是否显示。v2 起由区块注册表控制（默认开）。
///
/// 旧的 `showHomeHealthStrip` 列保留仅为向后兼容，不再读取。
final homeShowHealthStripProvider = Provider<bool>((ref) {
  return ref.watch(homeBlockVisibleProvider(HomeBlockId.healthCycle));
});

/// 今日行动卡片是否显示。
///
/// 兼容旧开关：待办区块不可见时也隐藏。Task 8 之后由
/// `homeBlockVisibleProvider(HomeBlockId.actionTodo)` 主导。
final homeShowTodayActionProvider = Provider<bool>((ref) {
  if (!ref.watch(homeBlockVisibleProvider(HomeBlockId.actionTodo))) {
    return false;
  }
  return ref
          .watch(currentUserPreferencesProvider)
          .maybeWhen(
            data: (preferences) => preferences?.showHomeTodayAction,
            orElse: () => null,
          ) ??
      true;
});
