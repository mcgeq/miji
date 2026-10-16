import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/router/app_routes.dart';

/// 一级模块内部的一个「面板」——也就是二级路由的目标。
///
/// 面板**不是**独立 path 路由，而是模块根地址上的一枚 `?section=`。这条约定
/// 是有代价考量的：go_router 的 `pageKey` 由命中路由的 path 拼出来、**不含
/// query**，所以换面板时页面 State 不重建；一旦拆成 `/app/x/panel` 这样的
/// 同级 path，每次切换都会新建 `pageKey`，模块 State（面板保活、滚动位置、
/// 筛选条件、PageController）全部丢一次。
@immutable
class AppModuleSection {
  const AppModuleSection({
    required this.id,
    required this.label,
    required this.icon,
    this.aliases = const <String>[],
  });

  /// 写进 `?section=` 的值。外壳、深链、测试共用这一个稳定标识。
  final String id;

  final String label;

  final IconData icon;

  /// 历史上用过的 id（记账的 `more` 已不是真实面板）。解析时一并接受，免得
  /// 旧链接、旧通知点进来静默落到默认面板。
  final List<String> aliases;

  bool matches(String raw) => raw == id || aliases.contains(raw);
}

/// 一个一级模块的面板清单：地址、标题、默认面板、全部面板。
///
/// 三个模块（记账 / 打卡 / 健康）共用同一份声明，外壳、页面、选择器都从这里
/// 取数——否则「底栏知道有 8 个面板、页面以为是 8 个枚举、选择器又写死一遍」
/// 这种三份真相迟早对不上。
@immutable
class AppModuleNavSpec {
  const AppModuleNavSpec({
    required this.id,
    required this.path,
    required this.title,
    required this.defaultSectionId,
    required this.sections,
    this.pickerColumns = 4,
  });

  /// 会话态里用的模块键，与 [id] 同名便于排查。
  final String id;

  /// 模块根地址，同时也是底栏 / 侧栏对应项的 `path`。
  final String path;

  /// 面板选择器的标题（模块名）。
  final String title;

  final String defaultSectionId;

  /// 面板顺序**有意义**：`GtdPage` 的 `PageView` 页码就是这里的下标。
  final List<AppModuleSection> sections;

  /// 选择器的列数。8 个面板的记账与 4~5 个的其它模块都用 4 列，正好两行内收完。
  final int pickerColumns;

  AppModuleSection get defaultSection =>
      sections.firstWhere((section) => section.id == defaultSectionId);

  /// 把任意外部输入（URL、旧 id、枚举名）解析成真实存在的面板 id。
  ///
  /// 非法值一律退到默认面板而不是抛错：地址是用户可以手改、旧版本通知也会
  /// 带着过期的 id 过来的，宁可落到流水也不能白屏。
  String resolveSectionId(String? raw) {
    if (raw == null || raw.isEmpty) {
      return defaultSectionId;
    }
    for (final section in sections) {
      if (section.matches(raw)) {
        return section.id;
      }
    }
    return defaultSectionId;
  }

  AppModuleSection resolveSection(String? raw) =>
      sections.firstWhere((section) => section.id == resolveSectionId(raw));

  /// 面板在清单里的下标（`PageView` 用）。
  int indexOf(String? raw) {
    final id = resolveSectionId(raw);
    final index = sections.indexWhere((section) => section.id == id);
    return index < 0 ? 0 : index;
  }

  /// 该模块某一枚面板的地址。
  Uri uriFor(String? sectionId) => Uri(
    path: path,
    queryParameters: {'section': resolveSectionId(sectionId)},
  );

  /// 这个地址是否属于本模块（含子页面，如 `/app/gtd/plans/xxx`）。
  bool owns(String location) =>
      location == path || location.startsWith('$path/');

  /// 这个地址是否正好是本模块的根（不带子路径）。
  ///
  /// 两态唤出靠它区分「在模块里」与「在模块的某个子页面里」：后者再点底栏
  /// 应该退回模块根，而不是弹面板选择器。
  bool isRootOf(String location) => location == path;
}

const bookkeepingModuleNav = AppModuleNavSpec(
  id: 'bookkeeping',
  path: AppRoutes.bookkeeping,
  title: '记账',
  defaultSectionId: 'transactions',
  sections: [
    AppModuleSection(
      id: 'transactions',
      label: '流水',
      icon: Icons.receipt_long_rounded,
      aliases: ['more'],
    ),
    AppModuleSection(
      id: 'accounts',
      label: '账户',
      icon: Icons.account_balance_wallet_rounded,
    ),
    AppModuleSection(id: 'budgets', label: '预算', icon: Icons.flag_rounded),
    AppModuleSection(
      id: 'statistics',
      label: '统计',
      icon: Icons.query_stats_rounded,
    ),
    AppModuleSection(
      id: 'categories',
      label: '分类',
      icon: Icons.category_rounded,
    ),
    AppModuleSection(
      id: 'installments',
      label: '分期',
      icon: Icons.calendar_month_rounded,
    ),
    AppModuleSection(
      id: 'autoPosting',
      label: '自动记账',
      icon: Icons.event_repeat_rounded,
    ),
    AppModuleSection(
      id: 'reminders',
      label: '提醒',
      icon: Icons.notifications_active_rounded,
    ),
  ],
);

const gtdModuleNav = AppModuleNavSpec(
  id: 'gtd',
  path: AppRoutes.gtd,
  title: '打卡',
  defaultSectionId: 'today',
  sections: [
    AppModuleSection(id: 'today', label: '今日', icon: Icons.today_rounded),
    AppModuleSection(id: 'tasks', label: '任务', icon: Icons.task_alt_rounded),
    AppModuleSection(id: 'habits', label: '习惯', icon: Icons.checklist_rounded),
    AppModuleSection(
      id: 'calendar',
      label: '日历',
      icon: Icons.calendar_month_rounded,
    ),
    AppModuleSection(
      id: 'statistics',
      label: '统计',
      icon: Icons.insights_rounded,
    ),
  ],
);

const healthModuleNav = AppModuleNavSpec(
  id: 'health',
  path: AppRoutes.health,
  title: '健康',
  defaultSectionId: 'today',
  sections: [
    AppModuleSection(id: 'today', label: '今日', icon: Icons.today_rounded),
    AppModuleSection(
      id: 'calendar',
      label: '日历',
      icon: Icons.calendar_month_rounded,
    ),
    AppModuleSection(id: 'trends', label: '趋势', icon: Icons.insights_rounded),
    AppModuleSection(id: 'settings', label: '设置', icon: Icons.tune_rounded),
  ],
);

/// 有面板的一级模块。首页与设置不在列：它们没有「面板」这层。
const appModuleNavSpecs = <AppModuleNavSpec>[
  gtdModuleNav,
  bookkeepingModuleNav,
  healthModuleNav,
];

/// 按地址找模块（含子页面）。
AppModuleNavSpec? appModuleNavSpecForLocation(String location) {
  for (final spec in appModuleNavSpecs) {
    if (spec.owns(location)) {
      return spec;
    }
  }
  return null;
}

/// 按模块根地址找模块。
AppModuleNavSpec? appModuleNavSpecForPath(String path) {
  for (final spec in appModuleNavSpecs) {
    if (spec.isRootOf(path)) {
      return spec;
    }
  }
  return null;
}

/// 点一级模块时的落点判定。
///
/// - 返回地址：不在该模块里 → 跳过去（带上 [rememberedSectionId] 记忆的面板）；
/// - 返回 null：已经在该模块根上 → 调用方应当弹出面板选择器。
///
/// 抽成纯函数是为了它能被单测直接钉住：底栏点击是这次改版最容易退化的地方
/// （「点记账 = 进记账」一旦变成每次弹层，切模块就从 1 拍变成 3 拍）。
String? resolveModuleEntry({
  required AppModuleNavSpec spec,
  required String currentLocation,
  String? rememberedSectionId,
}) {
  if (currentLocation == spec.path) {
    return null;
  }
  return spec.uriFor(rememberedSectionId ?? spec.defaultSectionId).toString();
}

/// 会话态：「每个模块上次停在哪个面板」。
///
/// 底栏 / 侧栏只能给出模块根地址。没有这层记忆，从首页、通知或别的模块切回
/// 记账时 `?section=` 会缺失，面板被重置回默认值——用户在账户页看了一半的
/// 净资产一转眼就没了，这是收起 tab 之前就存在的退化。
final appModuleLastSectionProvider =
    NotifierProvider<AppModuleLastSection, Map<String, String>>(
      AppModuleLastSection.new,
    );

class AppModuleLastSection extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const <String, String>{};

  String? sectionOf(String moduleId) => state[moduleId];

  void remember(String moduleId, String sectionId) {
    if (state[moduleId] == sectionId) {
      return;
    }
    state = {...state, moduleId: sectionId};
  }

  /// 从当前地址里把所在模块的面板记下来。
  ///
  /// 模块内每次换面板都会写回 URL（`?section=`），所以 URL 就是「我在哪」的
  /// 真身：外壳只需在离开模块之前拍一张快照，不必让页面反过来通知外壳。
  void rememberUri(Uri uri) {
    final spec = appModuleNavSpecForPath(uri.path);
    if (spec == null) {
      return;
    }
    remember(spec.id, spec.resolveSectionId(uri.queryParameters['section']));
  }
}
