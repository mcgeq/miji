import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_providers.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_summary_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
import 'package:miji/features/life_energy/data/life_energy_repository.dart';
import 'package:miji/features/life_energy/domain/bonus_payment.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/life_energy_prefs.dart';
import 'package:miji/features/life_energy/domain/overtime_record.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/salary_history.dart';
import 'package:miji/features/life_energy/domain/salary_segment.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/wishlist_insight.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

final lifeEnergyRepositoryProvider = Provider<LifeEnergyRepository>((ref) {
  // 带上变更日志：没有它这些数据永远不上传，换机就丢。
  return LifeEnergyRepository(
    ref.watch(appDatabaseProvider),
    syncLogger: ref.watch(syncChangeLoggerProvider),
  );
});

/// 「现在」的唯一来源。
///
/// 冷却期 / 本期月份 / 剩余天数全部依赖当前时间；测试注入一个固定时刻就能
/// 钉住「冷却还有 3 天」这类文案，而不必写死日期（写死日期的断言过几个月
/// 会自己烂掉）。
final lifeEnergyClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

/// **原始**档案（不做段解析）。`null` 表示还没填过。
///
/// 段表为空时它就是唯一的真相；有段之后，它仍然存着「当前」的金额和条件，
/// 历史段的差异由 [salarySegmentsProvider] 提供。
final rawWorkProfileProvider = StreamProvider.autoDispose<WorkProfile?>((
  ref,
) async* {
  if (!ref.mounted) {
    return;
  }
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    yield null;
    return;
  }
  yield* ref.watch(lifeEnergyRepositoryProvider).watchProfile(session.userId!);
});

/// 职业段（按生效月升序，含当前段）。
final salarySegmentsProvider = StreamProvider.autoDispose<List<SalarySegment>>((
  ref,
) async* {
  if (!ref.mounted) {
    return;
  }
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    yield const <SalarySegment>[];
    return;
  }
  yield* ref
      .watch(lifeEnergyRepositoryProvider)
      .watchSalarySegments(session.userId!);
});

/// 一段窗口内还没入账的支出义务，按月切成两份。
///
/// 为什么要下月那份：只看本月剩余，月底打开时余量会显得很宽裕（这个月的
/// 房贷已经付过了），而人做购买决定时想的是「下个月还要不要还」。两份摆在一起，
/// 才不会得出「我这个月还能花 900」这种误导。
class CommittedExpenseWindow {
  const CommittedExpenseWindow({
    required this.thisMonth,
    required this.nextMonth,
  });

  static const empty = CommittedExpenseWindow(
    thisMonth: <MoneyBudgetCommitmentItem>[],
    nextMonth: <MoneyBudgetCommitmentItem>[],
  );

  /// 今天 → 下月 1 日。
  final List<MoneyBudgetCommitmentItem> thisMonth;

  /// 下月 1 日 → 再下月 1 日。
  final List<MoneyBudgetCommitmentItem> nextMonth;

  int get thisMonthMinor =>
      thisMonth.fold(0, (sum, item) => sum + item.amountMinor);

  int get nextMonthMinor =>
      nextMonth.fold(0, (sum, item) => sum + item.amountMinor);
}

/// 时薪面板「上次停在哪」。
///
/// 读偏好表里那一列 JSON；读不到 / 读坏了都退回默认（`LifeEnergyPrefs.empty`），
/// 界面停在哪这种信息不值得让整页打不开。
final lifeEnergyPrefsProvider = Provider.autoDispose<LifeEnergyPrefs>((ref) {
  final raw = ref
      .watch(currentUserPreferencesProvider)
      .asData
      ?.value
      ?.lifeEnergyPrefs;
  return LifeEnergyPrefs.fromJsonString(raw);
});

/// 未来两个月**还没入账**的支出义务：自动记账模板（房贷 / 房租这类周期账单）、
/// 分期待还期次、账单提醒、待确认流水。
///
/// 数据不在这里另存一份：读的就是记账模块「预算已预留」和「未来现金流」用的
/// 同一套来源（`upcomingExpenseCommitments`）。用户在自动记账里建一条「每月
/// 25 日房贷 8,000」，这一页和记账那边立刻是同一个数 —— 要改也只改一处。
///
/// 一次查询取两个月再在内存里切：仓库那侧要为渲染周期展开所有模板，
/// 分两次查等于把同一批数据读两遍。
///
/// **口径差异是有意的**：这里的开关全开（含账单提醒、含待确认流水），而
/// 预算「已预留」默认只算自动记账与分期。原因是问的问题不同 —— 预算问
/// 「这个周期还被占多少」，估算值混进去会让额度看起来过紧；这里问「这个月
/// 还剩多少能自由花」，多算义务只会让余量更小，也就是更保守。别把两边对齐。
final currentCommittedExpenseProvider =
    FutureProvider.autoDispose<CommittedExpenseWindow>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final ledger = ref.watch(currentUserCurrentLedgerValueProvider);
      if (!session.isUnlocked || session.userId == null || ledger == null) {
        return CommittedExpenseWindow.empty;
      }
      final now = ref.watch(lifeEnergyClockProvider)();
      final start = DateTime(now.year, now.month, now.day);
      final nextMonthStart = DateTime(now.year, now.month + 1);
      final monthAfterStart = DateTime(now.year, now.month + 2);
      final items = await ref
          .watch(moneyRepositoryProvider)
          .upcomingExpenseCommitments(
            session.userId!,
            ledgerId: ledger.id,
            start: start,
            end: monthAfterStart,
            currencyCode: ledger.baseCurrencyCode,
          );
      final thisMonth = <MoneyBudgetCommitmentItem>[];
      final nextMonth = <MoneyBudgetCommitmentItem>[];
      for (final item in items) {
        if (item.date.isBefore(nextMonthStart)) {
          thisMonth.add(item);
        } else {
          nextMonth.add(item);
        }
      }
      return CommittedExpenseWindow(thisMonth: thisMonth, nextMonth: nextMonth);
    });

/// 年终奖（按纳税年度倒序，含「未指定年度」的旧数据）。
final bonusPaymentsProvider = StreamProvider.autoDispose<List<BonusPayment>>((
  ref,
) async* {
  if (!ref.mounted) {
    return;
  }
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    yield const <BonusPayment>[];
    return;
  }
  yield* ref.watch(lifeEnergyRepositoryProvider).watchBonuses(session.userId!);
});

/// 档案 + 段 = 一份职业履历。历史页用它算「每一段的时薪和涨幅」。
final salaryHistoryProvider = Provider.autoDispose<SalaryHistory?>((ref) {
  final profile = ref.watch(rawWorkProfileProvider).asData?.value;
  if (profile == null) {
    return null;
  }
  final segments =
      ref.watch(salarySegmentsProvider).asData?.value ??
      const <SalarySegment>[];
  return SalaryHistory(profile: profile, segments: segments);
});

/// 当前（今天所在月）生效的尺子 —— 面板、清单、档案页都用这**一个**。
///
/// 返回 `AsyncValue` 而不是裸值：调用方原本写的是 `ref.watch(...).asData?.value`
/// （StreamProvider 时代），保持这个形状可以让 7 个使用点一行都不用改。
///
/// 为什么只有「当前月」这一个入口：段是按月切的，而所有会随时间变化的量
/// （本期加班、本月支出）都是月口径。留一个无参的 `hourlyWage` 出来，下一个
/// 人就会顺手拿它算历史，而历史必须带月份。
final currentWorkProfileProvider =
    Provider.autoDispose<AsyncValue<WorkProfile?>>((ref) {
      final raw = ref.watch(rawWorkProfileProvider);
      final segments = ref.watch(salarySegmentsProvider);

      if (raw.hasError) {
        return AsyncError<WorkProfile?>(raw.error!, raw.stackTrace!);
      }
      final profile = raw.asData?.value;
      if (profile == null) {
        return raw.isLoading
            ? const AsyncLoading<WorkProfile?>()
            : const AsyncData<WorkProfile?>(null);
      }

      final list = segments.asData?.value ?? const <SalarySegment>[];
      final now = ref.watch(lifeEnergyClockProvider)();
      return AsyncData<WorkProfile?>(
        SalaryHistory(
          profile: profile,
          segments: list,
          bonuses:
              ref.watch(bonusPaymentsProvider).asData?.value ??
              const <BonusPayment>[],
        ).profileAt(now),
      );
    });

/// 当前这一年的 12 个月工资计划（累计预扣跑满 12 次）。
///
/// 只有**税前口径**下才返回值：`net` 模式没有「怎么算的」可展示 —— 用户填的
/// 就是到手，硬造一张扣缴表只会让人以为这些数是真的。
/// 某一年的 12 个月工资计划。
///
/// 参数是年份而不是「当前年」：档案页只关心今年，但年度账要看往年（「去年个税
/// 交了多少」）。用一个 family，两个调用点各取所需，不必各自再算一遍。
///
/// 传 null 表示「今年」——那是绝大多数调用方的意思，写成显式数字反而要求它们
/// 知道今天几号。
final annualPayrollProvider = Provider.autoDispose.family<AnnualPayroll?, int?>(
  (ref, year) {
    final history = ref.watch(salaryHistoryProvider);
    if (history == null || !history.profile.isGrossMode) {
      return null;
    }
    final resolvedYear = year ?? ref.watch(lifeEnergyClockProvider)().year;
    final plan = history.annualPayrollFor(resolvedYear);
    return plan.hasData ? plan : null;
  },
);

/// 今年（档案页、想买段用的就是这一个）。
final currentAnnualPayrollProvider = Provider.autoDispose<AnnualPayroll?>((
  ref,
) {
  return ref.watch(annualPayrollProvider(null));
});

/// 想买清单（当前账本 + 跨账本记录）。
final currentWishlistProvider = StreamProvider.autoDispose<List<WishlistEntry>>(
  (ref) async* {
    if (!ref.mounted) {
      return;
    }
    final session = ref.watch(authSessionControllerProvider);
    if (!session.isUnlocked || session.userId == null) {
      yield const <WishlistEntry>[];
      return;
    }
    final ledger = ref.watch(currentUserCurrentLedgerValueProvider);
    yield* ref
        .watch(lifeEnergyRepositoryProvider)
        .watchWishlist(userId: session.userId!, ledgerId: ledger?.id);
  },
);

/// 本月的加班记录。
final currentMonthOvertimeProvider =
    StreamProvider.autoDispose<List<OvertimeRecord>>((ref) async* {
      if (!ref.mounted) {
        return;
      }
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <OvertimeRecord>[];
        return;
      }
      final now = ref.watch(lifeEnergyClockProvider)();
      yield* ref
          .watch(lifeEnergyRepositoryProvider)
          .watchOvertimeEntries(
            userId: session.userId!,
            monthStart: DateTime(now.year, now.month),
          );
    });

/// 基线 + 本月加班聚合出来的「本期」。
///
/// 档案没填时返回 null（没有任何可算的）。
final currentLifeEnergyPeriodProvider = Provider.autoDispose<LifeEnergyPeriod?>(
  (ref) {
    final profile = ref.watch(currentWorkProfileProvider).asData?.value;
    if (profile == null) {
      return null;
    }
    final records =
        ref.watch(currentMonthOvertimeProvider).asData?.value ??
        const <OvertimeRecord>[];
    return LifeEnergyPeriod(profile: profile, records: records);
  },
);

/// 本月支出 / 收入合计（当前账本）。
///
/// 复用流水模块的聚合（`summarizeTransactions`），不在这里重写一遍「什么算
/// 支出」——待确认、转账、退款的口径散到第二处，迟早两边对不上。
final currentMonthMoneySummaryProvider =
    FutureProvider.autoDispose<MoneyTransactionSummary>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const MoneyTransactionSummary.empty();
      }
      // 记完一笔账后要跟着刷新，否则「本月花掉」会停在打开面板那一刻。
      ref.watch(moneyDataRefreshVersionProvider);
      final ledger = ref.watch(currentUserCurrentLedgerValueProvider);
      final now = ref.watch(lifeEnergyClockProvider)();
      return ref
          .watch(moneyRepositoryProvider)
          .summarizeTransactions(
            session.userId!,
            MoneyTransactionQuery(
              dateStart: DateTime(now.year, now.month),
              dateEnd: DateTime(now.year, now.month + 1, 0),
              ledgerId: ledger?.id,
            ),
          );
    });

/// 清单汇总（件数 / 合计金额 / 合计工作日）。
final currentWishlistInsightProvider = Provider.autoDispose<WishlistInsight?>((
  ref,
) {
  final entries = ref.watch(currentWishlistProvider).asData?.value;
  if (entries == null) {
    return null;
  }
  return WishlistInsight.from(
    entries: entries,
    profile: ref.watch(currentWorkProfileProvider).asData?.value,
    now: ref.watch(lifeEnergyClockProvider)(),
  );
});

/// 写操作。放在一个类里，页面不用逐个 `ref.read(...notifier)`；
/// 每次写完 bump 一次全局刷新版本号，让面板与清单同时更新。
class LifeEnergyActions {
  const LifeEnergyActions(this._ref);

  final Ref _ref;

  LifeEnergyRepository get _repository =>
      _ref.read(lifeEnergyRepositoryProvider);

  String? get _userId {
    final session = _ref.read(authSessionControllerProvider);
    if (!session.isUnlocked) {
      return null;
    }
    return session.userId;
  }

  String? get _ledgerId => _ref.read(currentUserCurrentLedgerValueProvider)?.id;

  void _refresh() {
    _ref.read(moneyDataRefreshVersionProvider.notifier).bump();
    _ref.invalidate(rawWorkProfileProvider);
    _ref.invalidate(salarySegmentsProvider);
    _ref.invalidate(bonusPaymentsProvider);
    _ref.invalidate(currentWorkProfileProvider);
    _ref.invalidate(currentWishlistProvider);
    _ref.invalidate(currentMonthOvertimeProvider);
  }

  /// 记住「上次停在哪」。写失败不影响界面（下一次读到的还是旧值）。
  Future<void> saveLifeEnergyPrefs(LifeEnergyPrefs prefs) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _ref
        .read(preferencesRepositoryProvider)
        .updateLifeEnergyPrefs(userId, prefs.encode());
    _ref.invalidate(currentUserPreferencesProvider);
  }

  Future<void> saveProfile(WorkProfile profile) async {
    await _repository.saveProfile(profile);
    _refresh();
  }

  /// 新增一段（涨薪 / 跳槽 / 转正）。
  ///
  /// 条件项传 null 表示「和上一段一样」，repository 在写入前会把上一段的
  /// 继承值冻结成显式值，保证以后改档案不会改到历史。
  Future<void> addSalarySegment({
    required int effectiveYear,
    required int effectiveMonth,
    required int amountMinor,
    int? grossAmountMinor,
    String? employer,
    LifeEnergyPayCycle? payCycle,
    int? workDaysPerMonth,
    int? workMinutesPerDay,
    int? commuteMinutesPerDay,
    int? overtimeMinutesPerMonth,
    int? workCostMonthlyMinor,
    SocialInsuranceConfig? payroll,
    String? note,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _repository.createSalarySegment(
      userId: userId,
      effectiveYear: effectiveYear,
      effectiveMonth: effectiveMonth,
      amountMinor: amountMinor,
      grossAmountMinor: grossAmountMinor,
      employer: employer,
      payCycle: payCycle,
      workDaysPerMonth: workDaysPerMonth,
      workMinutesPerDay: workMinutesPerDay,
      commuteMinutesPerDay: commuteMinutesPerDay,
      overtimeMinutesPerMonth: overtimeMinutesPerMonth,
      workCostMonthlyMinor: workCostMonthlyMinor,
      payroll: payroll,
      note: note,
    );
    _refresh();
  }

  Future<void> updateSalarySegment(SalarySegment segment) async {
    final now = _ref.read(lifeEnergyClockProvider)();
    await _repository.upsertSalarySegment(segment.copyWith(updatedAt: now));
    _refresh();
  }

  /// 删掉一段历史。**当前段删不掉**：删了之后档案就没有归属了，
  /// 要改当前薪水请直接改档案（那是「改错」而不是「删历史」）。
  /// 记/改一笔年终奖。同一年已有一条就覆盖（见 [BonusPayment] 的「一年一条」）。
  Future<void> saveBonus({
    required int taxYear,
    required int amountMinor,
    String? sourceLabel,
    String? note,
    BonusPayment? bonus,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _repository.saveBonus(
      userId: userId,
      taxYear: taxYear,
      amountMinor: amountMinor,
      sourceLabel: sourceLabel,
      note: note,
      id: bonus?.id,
    );
    _refresh();
  }

  Future<void> deleteBonus(BonusPayment bonus) async {
    await _repository.deleteBonus(bonus.userId, bonus.id);
    _refresh();
  }

  Future<void> deleteSalarySegment(SalarySegment segment) async {
    await _repository.deleteSalarySegment(segment.userId, segment.id);
    _refresh();
  }

  Future<void> addWishlistItem({
    required String title,
    required int targetAmountMinor,
    String? notes,
    WishDesireLevel desire = WishDesireLevel.want,
    DateTime? cooldownUntil,
    bool? q1Satisfaction,
    bool? q2Aligned,
    bool? q3NoJob,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _repository.createWishlistEntry(
      userId: userId,
      ledgerId: _ledgerId,
      title: title,
      targetAmountMinor: targetAmountMinor,
      notes: notes,
      desire: desire,
      cooldownUntil: cooldownUntil,
      q1Satisfaction: q1Satisfaction,
      q2Aligned: q2Aligned,
      q3NoJob: q3NoJob,
    );
    _refresh();
  }

  Future<void> updateWishlistItem(WishlistEntry entry) async {
    await _repository.updateWishlistEntry(entry);
    _refresh();
  }

  /// 标记买了 / 放弃。写 `decidedAt` 让「省下多少」有据可查。
  Future<void> settleWishlistItem(
    WishlistEntry entry,
    WishlistItemStatus status, {
    String? transactionId,
  }) async {
    final now = _ref.read(lifeEnergyClockProvider)();
    await _repository.updateWishlistEntry(
      entry.copyWith(
        storedStatus: status,
        decidedAt: now,
        transactionId: transactionId,
        // 买了却没记流水时把旧 id 清掉：否则「已记入流水」会指向一笔
        // 用户刚刚选择不记的、或者早被删掉的流水。
        clearTransactionId:
            status == WishlistItemStatus.bought && transactionId == null,
        updatedAt: now,
      ),
    );
    _refresh();
  }

  Future<void> deleteWishlistItem(WishlistEntry entry) async {
    await _repository.deleteWishlistEntry(entry.userId, entry.id);
    _refresh();
  }

  Future<void> addOvertimeEntry({
    required DateTime workDate,
    required int minutes,
    OvertimeCompensation compensation = OvertimeCompensation.paid,
    int payAmountMinor = 0,
    int extraCostMinor = 0,
    bool isRestDay = false,
    String? note,
  }) async {
    final userId = _userId;
    if (userId == null) {
      return;
    }
    await _repository.createOvertimeEntry(
      userId: userId,
      ledgerId: _ledgerId,
      workDate: workDate,
      minutes: minutes,
      compensation: compensation,
      payAmountMinor: payAmountMinor,
      extraCostMinor: extraCostMinor,
      isRestDay: isRestDay,
      note: note,
    );
    _refresh();
  }

  Future<void> deleteOvertimeEntry(OvertimeRecord record) async {
    await _repository.deleteOvertimeEntry(record.userId, record.id);
    _refresh();
  }
}

final lifeEnergyActionsProvider = Provider<LifeEnergyActions>((ref) {
  return LifeEnergyActions(ref);
});
