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
  }) {
    final dateKey = _dateKeyOf(now);

    // 锁着的时候连"今天花了多少钱"都不该出现在桌面上：小组件在锁屏上
    // 也可能可见，而应用本身是有锁的。
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
    );
  }

  Map<String, Object> toWidgetData() => <String, Object>{
    _kLabel: label,
    _kAmount: amount,
    _kMeta: meta,
    _kWeek: weekExpense,
    _kMonth: monthExpense,
    _kDaily: dailyExpense,
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
    if (unlocked) {
      try {
        // 数据还没准备好（刚启动、正在 seed）时直接放弃这一次：
        // 写一份「¥0.00」比不更新更糟，它会被当成真的。
        summary = await _ref.read(homeTodaySpendingSummaryProvider.future);
      } catch (error) {
        debugPrint('MoneyWidget summary unavailable: $error');
        return;
      }
    }

    final snapshot = MoneyWidgetSnapshot.fromTodaySummary(
      summary: summary,
      masked: _ref.read(moneyAmountsMaskedProvider),
      unlocked: unlocked,
      ledgerName: _ref.read(currentUserCurrentLedgerValueProvider)?.name ?? '',
      now: DateTime.now(),
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
  ref.onDispose(() => timer?.cancel());

  // 启动即对齐一次：装完小组件 / 换机恢复后，不需要等用户先记一笔。
  schedule();
});
