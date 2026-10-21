import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/platform/mobile_platform.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';

/// Android 桌面小组件「今日支出」的数据投影。
///
/// 小组件是原生 `RemoteViews`，Dart 不在里面跑，所以这里只做一件事：
/// 把卡面要显示的四段文本算好、写进 `SharedPreferences`，再让原生重画。
///
/// **所有判断都在 Dart 侧完成**（遮罩、未解锁、今天没记账、金额格式化），
/// 原生只负责排版。这样小组件和首页 / 流水页永远同一个口径，不会各说各话；
/// 也避免了以后迁移数据库或改业务规则时，还要去 Kotlin 里改一遍。
///
/// 为什么要投影而不是让原生直接读 drift 的 sqlite：那会变成双写者，schema
/// 现在 v34，以后每次迁移都得两端同步，漏一次就是线上崩溃。
class MoneyWidgetSnapshot {
  const MoneyWidgetSnapshot({
    required this.label,
    required this.amount,
    required this.meta,
    required this.weekExpense,
    required this.monthExpense,
    required this.dailyExpense,
    required this.dateKey,
    required this.ledgerName,
    this.budgetVisible = false,
    this.budgetText = '',
    this.budgetTotal = '',
    this.budgetPercent = 0,
    this.budgetAlert = false,
  });

  /// 卡面左上角的口径说明。跨天后由原生改写为「截至 10-20」。
  final String label;

  /// 主数字，已按币种格式化；遮罩 / 未解锁时是 `••••`。
  final String amount;

  /// 主数字下面那行小字。
  final String meta;

  /// 底部三等分的三个周期数：本周 / 本月 / 日均支出。
  ///
  /// 卡片是满宽（5 格 ≈ 390dp）、2 格高在真实桌面上约 200dp，只放三段短文本
  /// 会空掉大半张卡。这三个数字都是首页同一份 [HomeTodaySpendingSummary] 里的
  /// 字段，取来即用，不额外查询。
  final String weekExpense;
  final String monthExpense;
  final String dailyExpense;

  /// 这份快照属于哪一天（`yyyy-MM-dd`，本地时区）。
  ///
  /// 原生拿它和今天比对：不一致就说明 app 没在当天更新过，卡面必须
  /// 写明「截至 X」而不是拿昨天的数字冒充今天。
  final String dateKey;

  /// 当前账本名；多账本时不加这一行会分不清看的是哪个账本的钱。
  final String ledgerName;

  /// 本月支出预算这一块是否要出现在卡上（没配预算时整块收起）。
  final bool budgetVisible;

  /// 预算左半句：`预算剩 ¥1,234.56` 或 `预算超支 ¥120.00`。
  final String budgetText;

  /// 预算右半句：`/ ¥3,000.00`。只剩总量，是为了让左半句的「还剩多少」
  /// 始终贴着左边、读起来是一句话，而不是两个独立数字。
  final String budgetTotal;

  /// 进度条百分比（0~100），口径是**占用**（已用 + 已预留），与首页预算卡同一判据。
  final int budgetPercent;

  /// 是否已经破了预算：为真时原生把左半句染成警示色。
  final bool budgetAlert;

  /// Receiver 的**全限定类名**（`home_widget` 拿到后直接 `Class.forName`）。
  ///
  /// 这里踩过一次坑：最初的写法是 `updateWidget(androidName: 'MoneyWidgetProvider')`，
  /// 而插件会把 `androidName` 拼成 `<applicationId>.<androidName>` ——
  /// `com.mcgeq.miji.MoneyWidgetProvider` 根本不存在（真实类在 `.widget` 子包里），
  /// 插件抛 `PlatformException(-3, No Widget found...)`，又被 [push] 的 catch 静默
  /// 吞掉。表现就是「数据写进去了、卡面永远不动」，只有等系统 30 分钟一次的
  /// 周期刷新才偶尔变一次。所以必须走 `qualifiedAndroidName`。
  ///
  /// 用全限定名而不是相对名还有个好处：以后加 applicationId 后缀的 flavor
  /// （`com.mcgeq.miji.dev` 之类）时，类名不会跟着变。
  static const androidProviderName =
      'com.mcgeq.miji.widget.MoneyWidgetProvider';

  /// iOS 的 Widget kind（本次未实现，先占位，避免以后改 Dart 侧调用）。
  static const iosWidgetName = 'MoneyWidget';

  /// 小组件只在移动端存在；桌面端 / Web / 单元测试里都不该去连那条通道。
  static bool get isSupported => isMobilePlatform;

  static const _kLabel = 'mw_label';
  static const _kAmount = 'mw_amount';
  static const _kMeta = 'mw_meta';
  static const _kWeek = 'mw_week';
  static const _kMonth = 'mw_month';
  static const _kDaily = 'mw_daily';
  static const _kBudgetVisible = 'mw_budget_visible';
  static const _kBudgetText = 'mw_budget_text';
  static const _kBudgetTotal = 'mw_budget_total';
  static const _kBudgetPercent = 'mw_budget_percent';
  static const _kBudgetAlert = 'mw_budget_alert';
  static const _kDate = 'mw_date';
  static const _kLedger = 'mw_ledger';

  /// 把首页那张「今日」汇总翻译成卡面文案。
  ///
  /// 口径与首页三宫格的记账格完全一致：同一个 [HomeTodaySpendingSummary]，
  /// 同一套 [formatMoneyMinor] / [formatMoneyMinorCompact]，同一个
  /// `moneyAmountsMaskedProvider`。
  ///
  /// 底部的三个周期数用 compact 格式（`¥2.3k`）：它们只是「扫一眼的量级」，
  /// 三等分后每列只有约 110dp，精确到分反而会被截断。
  factory MoneyWidgetSnapshot.fromTodaySummary({
    required HomeTodaySpendingSummary summary,
    required bool masked,
    required bool unlocked,
    required String ledgerName,
    required DateTime now,
    HomeMonthBudgetSummary? budget,
  }) {
    final dateKey = _dateKeyOf(now);

    // 锁着的时候连"今天花了多少钱"都不该出现在桌面上：小组件在锁屏上
    // 也可能可见，而应用本身是有锁的。
    //
    // 预算同理，而且这里连「有没有配预算」都不必暴露（那本身也是一种信息），
    // 所以整块直接收起，而不是显示一排 •••• 占位。
    if (!unlocked) {
      return MoneyWidgetSnapshot(
        label: '记账',
        amount: '••••',
        meta: '点开解锁',
        weekExpense: '••••',
        monthExpense: '••••',
        dailyExpense: '••••',
        dateKey: dateKey,
        ledgerName: ledgerName,
      );
    }

    if (masked) {
      final count = summary.todayTransactionCount;
      final hasBudget = budget?.hasBudget ?? false;
      return MoneyWidgetSnapshot(
        label: '今日支出',
        amount: '••••',
        // 明说「已隐藏」，否则用户会以为是小组件坏了。
        meta: count == 0 ? '点开记一笔' : '$count 笔 · 金额已隐藏',
        weekExpense: '••••',
        monthExpense: '••••',
        dailyExpense: '••••',
        dateKey: dateKey,
        ledgerName: ledgerName,
        // 保留这一块的位置（只打码数字），否则遮罩一开卡面高度会跳。
        budgetVisible: hasBudget,
        budgetText: hasBudget ? '预算 ••••' : '',
        budgetTotal: hasBudget ? '••••' : '',
      );
    }

    final expense = formatMoneyMinor(
      summary.todayExpenseMinor,
      summary.currencyCode,
    );
    final count = summary.todayTransactionCount;
    final income = summary.todayIncomeMinor > 0
        ? ' · 收入 ${formatMoneyMinor(summary.todayIncomeMinor, summary.currencyCode)}'
        : '';

    // 预算：`budget` 为 null 表示这一屏没有可用预算（没配、或只有已归档的），
    // 此时整块收起。判「破没破」用 isBusted（占用 = 已用 + 已预留），
    // 不用 used > total：未来义务占满额度时和真花超了没有区别，
    // 首页预算卡也是这个结论，两处不能各说各话。
    final monthlyBudget = (budget?.hasBudget ?? false) ? budget : null;
    final busted = monthlyBudget?.isBusted ?? false;

    return MoneyWidgetSnapshot(
      label: '今日支出',
      amount: expense,
      meta: count == 0 ? '今天还没记账' : '$count 笔$income',
      weekExpense: formatMoneyMinorCompact(
        summary.weekExpenseMinor,
        summary.currencyCode,
      ),
      monthExpense: formatMoneyMinorCompact(
        summary.monthExpenseMinor,
        summary.currencyCode,
      ),
      dailyExpense: formatMoneyMinorCompact(
        summary.dailyAverageExpenseMinor,
        summary.currencyCode,
      ),
      dateKey: dateKey,
      ledgerName: ledgerName,
      budgetVisible: monthlyBudget != null,
      budgetText: monthlyBudget == null
          ? ''
          // 超支时给「超出多少」而不是负数的「还剩」：负数得在脑子里再换算一次。
          : busted
          ? '预算超支 ${formatMoneyMinor(monthlyBudget.bustedMinor, monthlyBudget.currencyCode)}'
          : '预算剩 ${formatMoneyMinor(monthlyBudget.availableMinor, monthlyBudget.currencyCode)}',
      budgetTotal: monthlyBudget == null
          ? ''
          : '/ ${formatMoneyMinor(monthlyBudget.totalMinor, monthlyBudget.currencyCode)}',
      budgetPercent: monthlyBudget == null
          ? 0
          : (monthlyBudget.occupiedProgress * 100).clamp(0, 100).round(),
      budgetAlert: busted,
    );
  }

  Map<String, Object> toWidgetData() => <String, Object>{
    _kLabel: label,
    _kAmount: amount,
    _kMeta: meta,
    _kWeek: weekExpense,
    _kMonth: monthExpense,
    _kDaily: dailyExpense,
    // 布尔和整数都转成字符串：`saveWidgetData<String>` 是唯一在两端都稳的类型，
    // 混着写 Int 会在 Kotlin 侧 getString 抛 ClassCastException。
    _kBudgetVisible: budgetVisible ? '1' : '0',
    _kBudgetText: budgetText,
    _kBudgetTotal: budgetTotal,
    _kBudgetPercent: '$budgetPercent',
    _kBudgetAlert: budgetAlert ? '1' : '0',
    _kDate: dateKey,
    _kLedger: ledgerName,
  };

  /// 写入 `SharedPreferences` 并触发一次重画。
  Future<void> push() async {
    if (!isSupported) {
      return;
    }
    try {
      final data = toWidgetData();
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<String>(
          entry.key,
          entry.value as String,
        );
      }
      await HomeWidget.updateWidget(
        // 必须是 qualifiedAndroidName：见 [androidProviderName] 上的注释。
        qualifiedAndroidName: androidProviderName,
        iOSName: iosWidgetName,
      );
    } catch (error, stackTrace) {
      // 小组件失败不能影响主流程（比如用户还没装 launcher 支持、或者
      // 在单元测试里没有插件通道）。静默记一笔就够了。
      debugPrint('MoneyWidget push failed: $error\n$stackTrace');
    }
  }

  static String _dateKeyOf(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    return '${time.year}-$month-$day';
  }
}

/// 把当前状态推给小组件。
class MoneyWidgetPusher {
  MoneyWidgetPusher(this._ref);

  final Ref _ref;

  Future<void> push() async {
    if (!MoneyWidgetSnapshot.isSupported) {
      return;
    }

    final session = _ref.read(authSessionControllerProvider);
    final unlocked = session.isUnlocked && session.userId != null;

    var summary = const HomeTodaySpendingSummary.empty();
    HomeMonthBudgetSummary? budget;
    if (unlocked) {
      try {
        // 数据还没准备好（刚启动、正在 seed）时直接放弃这一次：
        // 写一份「¥0.00」比不更新更糟，它会被当成真的。
        summary = await _ref.read(homeTodaySpendingSummaryProvider.future);
      } catch (error) {
        debugPrint('MoneyWidget summary unavailable: $error');
        return;
      }

      // 预算单独 try：它要额外查「已预留」（自动记账 / 分期），失败概率比
      // 主数字高，但预算挂了不该让整张卡停在旧值上 —— 少一条预算条，
      // 也比今日支出不更新好。
      try {
        budget = await _ref.read(homeMonthBudgetSummaryProvider.future);
      } catch (error) {
        debugPrint('MoneyWidget budget unavailable: $error');
      }
    }

    final snapshot = MoneyWidgetSnapshot.fromTodaySummary(
      summary: summary,
      masked: _ref.read(moneyAmountsMaskedProvider),
      unlocked: unlocked,
      ledgerName: _ref.read(currentUserCurrentLedgerValueProvider)?.name ?? '',
      now: DateTime.now(),
      budget: budget,
    );
    await snapshot.push();
  }
}

final moneyWidgetPusherProvider = Provider<MoneyWidgetPusher>(
  (ref) => MoneyWidgetPusher(ref),
);

/// 数据一变就推一次（带 500ms 防抖）。
///
/// 监听的是「原子级」的四个信号：登录态、遮罩、记账数据版本号、当前账本。
/// 直接监听流水列表会一天推送几十次，而 launcher 那边每次都要跨进程重排。
final moneyWidgetAutoSyncProvider = Provider<void>((ref) {
  if (!MoneyWidgetSnapshot.isSupported) {
    return;
  }

  Timer? timer;
  void schedule() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 500), () {
      unawaited(ref.read(moneyWidgetPusherProvider).push());
    });
  }

  ref.listen(authSessionControllerProvider, (_, _) => schedule());
  ref.listen(moneyAmountsMaskedProvider, (_, _) => schedule());
  ref.listen(moneyDataRefreshVersionProvider, (_, _) => schedule());
  ref.listen(currentMoneyLedgerIdProvider, (_, _) => schedule());
  // 预算有独立的失效源（改额度、改自动记账模板、分期计划），不一定伴随
  // moneyDataRefreshVersion 自增，所以单独听一份。它是 FutureProvider，
  // 解锁 / 计算完成时各发一次，防抖会把它们合并成一次推送。
  ref.listen(homeMonthBudgetSummaryProvider, (_, _) => schedule());
  ref.onDispose(() => timer?.cancel());

  // 启动即对齐一次：装完小组件 / 换机恢复后，不需要等用户先记一笔。
  schedule();
});
