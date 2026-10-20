import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/application/home_preference_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 三宫格的一格。
///
/// 每格统一为「模块名 → 主值 → 主值口径 → 次要指标」四层：
///
/// - [title]：这一格是什么（记账 / 健康 / 计划）；
/// - [value]：这一格最重要的数字，必须是短文本，窄格子要单行放得下；
/// - [label]：这个数字的口径（本月还可花 / 距下次经期 / 今日已完成）；
/// - [noteLabel] + [noteValue]：次要指标，一条「名称 + 取值」或一句短说明。
///
/// 旧版只有「大数字 + 一行副文案」，副文案里把口径和次要金额用 `·`
/// 粘在一起（`本月还可花 · 今日支出 ¥51.17`），用户既看不出大数字属于哪一项，
/// 也分不清两个金额谁主谁次。
class HomeBoardCell {
  const HomeBoardCell({
    required this.id,
    required this.emoji,
    required this.title,
    required this.value,
    required this.label,
    this.noteLabel,
    this.noteValue,
    this.valueAlert = false,
  });

  final HomeBlockId id;
  final String emoji;

  /// 模块名，回答「这一格是什么」。
  final String title;

  /// 主值：数字或极短的状态词。
  final String value;

  /// 主值口径，回答「这个数字是什么」。
  final String label;

  /// 次要指标的名称（如「今日支出」）；
  /// [noteValue] 为空时，它本身作为一句短说明渲染（如「全部完成 🎉」）。
  final String? noteLabel;

  /// 次要指标的取值（如「¥51.17」）。
  final String? noteValue;

  /// 主值是否需要告警色（例如本月已超支）。
  final bool valueAlert;
}

class HomeTodayBoardData {
  const HomeTodayBoardData({required this.cells});

  final List<HomeBoardCell> cells;

  bool get isEmpty => cells.isEmpty;
}

final homeTodayBoardProvider = Provider<HomeTodayBoardData>((ref) {
  final today = ref.watch(homeTodaySpendingSummaryProvider).asData?.value;
  final budget = ref.watch(homeMonthBudgetSummaryProvider).asData?.value;
  final masked = ref.watch(moneyAmountsMaskedProvider);
  final hint = ref.watch(homeHealthHintProvider).asData?.value;
  final action = ref.watch(todayActionItemsProvider).asData?.value;

  final cells = <HomeBoardCell>[
    if (ref.watch(homeBlockVisibleProvider(HomeBlockId.boardMoney)))
      buildMoneyBoardCell(
        todayExpenseMinor: today?.todayExpenseMinor,
        monthRemainingMinor: (budget?.hasBudget ?? false)
            ? budget?.availableMinor
            : null,
        monthNetMinor: today?.monthNetMinor,
        currencyCode: today?.currencyCode ?? 'CNY',
        masked: masked,
      ),
    if (ref.watch(homeBlockVisibleProvider(HomeBlockId.boardHealth)))
      buildHealthBoardCell(hint: hint),
    if (ref.watch(homeBlockVisibleProvider(HomeBlockId.boardAction)))
      buildActionBoardCell(action),
  ];

  return HomeTodayBoardData(cells: cells);
});

HomeBoardCell buildMoneyBoardCell({
  required int? todayExpenseMinor,
  required int? monthRemainingMinor,
  required int? monthNetMinor,
  required String currencyCode,
  required bool masked,
}) {
  String money(int minor) =>
      masked ? '••••' : formatMoneyMinorCompact(minor, currencyCode);

  // 今日支出永远是次要指标，且带自己的名称，不再和主值口径挤在一行。
  final todayValue = todayExpenseMinor == null
      ? '—'
      : (masked ? '••••' : formatMoneyMinor(todayExpenseMinor, currencyCode));

  // 有预算时主值是「还可花」；没有预算才退化成「本月结余」——
  // 与顶部预算 Hero 同一口径，两处不会各说各话。
  //
  // 判据同 Hero：`availableMinor < 0` 等价于「已用 + 已预留 > 预算」，
  // 也就是 HomeMonthBudgetSummary.isBusted。值是负数时把符号翻正——
  // 「本月已超支 -¥300」读起来像「超支了负三百」，摆一个正数才是人话。
  if (monthRemainingMinor != null) {
    final exceeded = monthRemainingMinor < 0;
    return HomeBoardCell(
      id: HomeBlockId.boardMoney,
      emoji: '💰',
      title: '记账',
      value: money(exceeded ? -monthRemainingMinor : monthRemainingMinor),
      label: exceeded ? '本月已超支' : '本月还可花',
      noteLabel: '今日支出',
      noteValue: todayValue,
      valueAlert: exceeded,
    );
  }

  if (monthNetMinor != null) {
    return HomeBoardCell(
      id: HomeBlockId.boardMoney,
      emoji: '💰',
      title: '记账',
      value: money(monthNetMinor),
      label: '本月结余',
      noteLabel: '今日支出',
      noteValue: todayValue,
    );
  }

  return const HomeBoardCell(
    id: HomeBlockId.boardMoney,
    emoji: '💰',
    title: '记账',
    value: '—',
    label: '本月还可花',
    noteLabel: '还没有流水',
  );
}

HomeBoardCell buildHealthBoardCell({required HomeHealthHint? hint}) {
  if (hint == null) {
    return const HomeBoardCell(
      id: HomeBlockId.boardHealth,
      emoji: '🩺',
      title: '健康',
      value: '未开启',
      label: '周期追踪',
      noteLabel: '点这里开启',
    );
  }
  final digest = hint.digest;
  return HomeBoardCell(
    id: HomeBlockId.boardHealth,
    emoji: '🩺',
    title: '健康',
    value: digest.value,
    label: digest.label,
    noteLabel: digest.note,
  );
}

HomeBoardCell buildActionBoardCell(TodayActionView? view) {
  if (view == null || view.totalCount == 0) {
    return const HomeBoardCell(
      id: HomeBlockId.boardAction,
      emoji: '✅',
      title: '计划',
      value: '—',
      label: '今日待办',
      noteLabel: '今天没有待办',
    );
  }
  final allDone = view.completedCount >= view.totalCount;
  return HomeBoardCell(
    id: HomeBlockId.boardAction,
    emoji: '✅',
    title: '计划',
    value: '${view.completedCount} / ${view.totalCount}',
    label: '今日已完成',
    noteLabel: allDone ? '全部完成 🎉' : '下一件',
    noteValue: allDone ? null : _nextTitle(view),
  );
}

String _nextTitle(TodayActionView view) {
  for (final item in view.items) {
    if (item.isCompleted) {
      continue;
    }
    return switch (item) {
      TodayTodoActionItem(:final task) => task.title,
      TodayHabitActionItem(:final progress) => progress.plan.name,
    };
  }
  return '已完成';
}
