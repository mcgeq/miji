import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/application/home_preference_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 三宫格的一格。`value` / `sub` 已经是给人看的字符串。
class HomeBoardCell {
  const HomeBoardCell({
    required this.id,
    required this.emoji,
    required this.value,
    required this.sub,
  });

  final HomeBlockId id;
  final String emoji;
  final String value;
  final String sub;
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

  final int? primary = monthRemainingMinor ?? monthNetMinor;
  final value = primary == null ? '—' : money(primary);
  final todayLabel = todayExpenseMinor == null
      ? '还没有流水'
      : '今日支出 ${masked ? '••••' : formatMoneyMinor(todayExpenseMinor, currencyCode)}';
  final sub = monthRemainingMinor != null ? '本月还可花 · $todayLabel' : todayLabel;

  return HomeBoardCell(
    id: HomeBlockId.boardMoney,
    emoji: '💰',
    value: value,
    sub: sub,
  );
}

HomeBoardCell buildHealthBoardCell({required HomeHealthHint? hint}) {
  if (hint == null) {
    return const HomeBoardCell(
      id: HomeBlockId.boardHealth,
      emoji: '🩺',
      value: '未开启',
      sub: '去开启追踪',
    );
  }
  return HomeBoardCell(
    id: HomeBlockId.boardHealth,
    emoji: '🩺',
    value: hint.title,
    sub: hint.detail,
  );
}

HomeBoardCell buildActionBoardCell(TodayActionView? view) {
  if (view == null || view.totalCount == 0) {
    return const HomeBoardCell(
      id: HomeBlockId.boardAction,
      emoji: '✅',
      value: '—',
      sub: '今天没有待办',
    );
  }
  final sub = view.completedCount >= view.totalCount
      ? '全部完成 🎉'
      : '下一件 · ${_nextTitle(view)}';
  return HomeBoardCell(
    id: HomeBlockId.boardAction,
    emoji: '✅',
    value: '${view.completedCount} / ${view.totalCount}',
    sub: sub,
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
