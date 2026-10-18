import 'package:drift/drift.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';

/// `tax_year = 0` = 「还没填年度」（见 `BonusPayment.unspecifiedYear`）。
/// 这里写常量而不引 domain：apply 只依赖数据库与同步模型。
const int _unspecifiedTaxYear = 0;

/// 把远端变更落到时薪那五张表。
///
/// 与记账的 apply 分开：记账那份要维护账户余额、用量统计这类派生量，时薪这边
/// 五张表都是**纯输入**（没有任何派生列），所以可以直接写行 —— 唯一需要留意
/// 的是「档案与段的镜像」和年终奖的「一年一条」。
///
/// 不做 `_logChange`：应用远端变更不该再产生一条本地变更日志，否则两端会
/// 互相回传，永远同步不完。
extension LifeEnergyRemoteApply on AppDatabase {
  /// 应用一条远端变更。返回值表示**是否真的写了库**（false = 这张表不认识）。
  Future<bool> applyRemoteLifeEnergyChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    // 快照优先：`changedFields` 是本地日志里那行**原始 SQLite 值**（布尔存成
    // 0/1、时间存成 unix 秒），而快照来自 `_readLocalRecordFromDatabase`，
    // 是干净的 snake_case 类型。两者都带上时，不能拿原始值盖掉干净的。
    final fields = <String, Object?>{
      ...change.changedFields,
      ...change.recordSnapshot,
    };
    switch (change.table) {
      case SyncChangeLogger.lifeEnergyProfilesTableName:
        await _applyProfile(change, fields);
        return true;
      case SyncChangeLogger.salarySegmentsTableName:
        await _applySalarySegment(change, fields);
        return true;
      case SyncChangeLogger.bonusPaymentsTableName:
        await _applyBonusPayment(change, fields);
        return true;
      case SyncChangeLogger.wishlistItemsTableName:
        await _applyWishlistItem(change, fields);
        return true;
      case SyncChangeLogger.overtimeEntriesTableName:
        await _applyOvertimeEntry(change, fields);
        return true;
      default:
        return false;
    }
  }

  // ───────────────────────── 各表 ─────────────────────────

  Future<void> _applyProfile(
    DeltaChangeRecord change,
    Map<String, Object?> f,
  ) async {
    final userId = _str(f, 'user_id') ?? change.recordId;
    final version = change.newVersion ?? 1;
    final deleted = _bool(f, 'is_deleted', false);
    await into(lifeEnergyProfiles).insertOnConflictUpdate(
      LifeEnergyProfilesCompanion(
        userId: Value(userId),
        payAmountMinor: Value(_int(f, 'pay_amount_minor', 0)),
        payCycle: Value(_str(f, 'pay_cycle') ?? 'month'),
        currencyCode: Value(_str(f, 'currency_code') ?? 'CNY'),
        compensationMode: Value(_str(f, 'compensation_mode') ?? 'net'),
        grossMonthlyMinor: Value(_int(f, 'gross_monthly_minor', 0)),
        socialBaseMode: Value(_str(f, 'social_base_mode') ?? 'auto'),
        socialBaseMinor: Value(_int(f, 'social_base_minor', 0)),
        socialBaseFloorMinor: Value(_int(f, 'social_base_floor_minor', 682100)),
        socialBaseCeilingMinor: Value(
          _int(f, 'social_base_ceiling_minor', 3581100),
        ),
        ratePensionBp: Value(_int(f, 'rate_pension_bp', 800)),
        rateMedicalBp: Value(_int(f, 'rate_medical_bp', 200)),
        rateUnemploymentBp: Value(_int(f, 'rate_unemployment_bp', 50)),
        rateHousingFundBp: Value(_int(f, 'rate_housing_fund_bp', 1200)),
        ratePensionErBp: Value(_int(f, 'rate_pension_er_bp', 1600)),
        rateMedicalErBp: Value(_int(f, 'rate_medical_er_bp', 950)),
        rateUnemploymentErBp: Value(_int(f, 'rate_unemployment_er_bp', 50)),
        rateInjuryErBp: Value(_int(f, 'rate_injury_er_bp', 40)),
        rateHousingFundErBp: Value(_int(f, 'rate_housing_fund_er_bp', 1200)),
        medicalFixedMinor: Value(_int(f, 'medical_fixed_minor', 0)),
        specialDeductionMinor: Value(_int(f, 'special_deduction_minor', 0)),
        workDaysPerMonth: Value(_int(f, 'work_days_per_month', 22)),
        workMinutesPerDay: Value(_int(f, 'work_minutes_per_day', 480)),
        commuteMinutesPerDay: Value(_int(f, 'commute_minutes_per_day', 0)),
        overtimeMinutesPerMonth: Value(
          _int(f, 'overtime_minutes_per_month', 0),
        ),
        costTransportMinor: Value(_int(f, 'cost_transport_minor', 0)),
        costMealMinor: Value(_int(f, 'cost_meal_minor', 0)),
        costClothingMinor: Value(_int(f, 'cost_clothing_minor', 0)),
        costChildcareMinor: Value(_int(f, 'cost_childcare_minor', 0)),
        costDecompressMinor: Value(_int(f, 'cost_decompress_minor', 0)),
        costOtherMinor: Value(_int(f, 'cost_other_minor', 0)),
        deviceId: Value(_str(f, 'device_id')),
        version: Value(version),
        isDeleted: Value(deleted),
        deletedAt: Value(_date(f, 'deleted_at')),
        createdAt: Value(_date(f, 'created_at') ?? DateTime.now().toUtc()),
        updatedAt: Value(_date(f, 'updated_at') ?? DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _applySalarySegment(
    DeltaChangeRecord change,
    Map<String, Object?> f,
  ) async {
    final version = change.newVersion ?? 1;
    final deleted = _bool(f, 'is_deleted', false);
    await into(salarySegments).insertOnConflictUpdate(
      SalarySegmentsCompanion(
        id: Value(change.recordId),
        userId: Value(_str(f, 'user_id') ?? ''),
        employer: Value(_str(f, 'employer')),
        effectiveYear: Value(_int(f, 'effective_year', 0)),
        effectiveMonth: Value(_int(f, 'effective_month', 1)),
        amountMinor: Value(_int(f, 'amount_minor', 0)),
        grossAmountMinor: Value(_nullableInt(f, 'gross_amount_minor')),
        payCycle: Value(_str(f, 'pay_cycle')),
        workDaysPerMonth: Value(_nullableInt(f, 'work_days_per_month')),
        workMinutesPerDay: Value(_nullableInt(f, 'work_minutes_per_day')),
        commuteMinutesPerDay: Value(_nullableInt(f, 'commute_minutes_per_day')),
        overtimeMinutesPerMonth: Value(
          _nullableInt(f, 'overtime_minutes_per_month'),
        ),
        workCostMonthlyMinor: Value(_nullableInt(f, 'work_cost_monthly_minor')),
        // 参数快照原样落地，不解析。
        payrollJson: Value(_str(f, 'payroll_json')),
        note: Value(_str(f, 'note')),
        deviceId: Value(_str(f, 'device_id')),
        version: Value(version),
        isDeleted: Value(deleted),
        deletedAt: Value(_date(f, 'deleted_at')),
        createdAt: Value(_date(f, 'created_at') ?? DateTime.now().toUtc()),
        updatedAt: Value(_date(f, 'updated_at') ?? DateTime.now().toUtc()),
      ),
    );
  }

  /// 年终奖的**一年一条**在这里兜底。
  ///
  /// 两台设备在同一年各记一笔时：`(user_id, tax_year) WHERE is_deleted=0` 的
  /// 唯一索引会让「插进去」直接失败。做法不是丢数据也不是插两条，而是**把远端
  /// 这一笔写到本地同年那一行上**（保留本地 id）：一年一条是领域不变量，而
  /// 「这一年的奖金是多少」这个事实只有一个答案，后来到达的那个说了算。
  ///
  /// 代价：这不是一次真正的合并（两笔金额不同时不会提示用户）。但其它表在
  /// 「同版本不同设备」时也是先到先得，这里保持一致，不单独发明一套。
  Future<void> _applyBonusPayment(
    DeltaChangeRecord change,
    Map<String, Object?> f,
  ) async {
    final userId = _str(f, 'user_id') ?? '';
    final taxYear = _int(f, 'tax_year', _unspecifiedTaxYear);
    final version = change.newVersion ?? 1;
    final deleted = _bool(f, 'is_deleted', false);

    final sameYear =
        await (select(bonusPayments)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.taxYear.equals(taxYear) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    final targetId = sameYear?.id ?? change.recordId;

    await into(bonusPayments).insertOnConflictUpdate(
      BonusPaymentsCompanion(
        id: Value(targetId),
        userId: Value(userId),
        taxYear: Value(taxYear),
        amountMinor: Value(_int(f, 'amount_minor', 0)),
        sourceLabel: Value(_str(f, 'source_label')),
        note: Value(_str(f, 'note')),
        deviceId: Value(_str(f, 'device_id')),
        version: Value(version),
        isDeleted: Value(deleted),
        deletedAt: Value(_date(f, 'deleted_at')),
        createdAt: Value(
          _date(f, 'created_at') ??
              sameYear?.createdAt ??
              DateTime.now().toUtc(),
        ),
        updatedAt: Value(_date(f, 'updated_at') ?? DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _applyWishlistItem(
    DeltaChangeRecord change,
    Map<String, Object?> f,
  ) async {
    final version = change.newVersion ?? 1;
    await into(wishlistItems).insertOnConflictUpdate(
      WishlistItemsCompanion(
        id: Value(change.recordId),
        userId: Value(_str(f, 'user_id') ?? ''),
        ledgerId: Value(_str(f, 'ledger_id')),
        title: Value(_str(f, 'title') ?? ''),
        notes: Value(_str(f, 'notes')),
        targetAmountMinor: Value(_int(f, 'target_amount_minor', 0)),
        desireLevel: Value(_str(f, 'desire_level') ?? 'want'),
        status: Value(_str(f, 'status') ?? 'waiting'),
        cooldownUntil: Value(_date(f, 'cooldown_until')),
        q1Satisfaction: Value(_nullableBool(f, 'q1_satisfaction')),
        q2Aligned: Value(_nullableBool(f, 'q2_aligned')),
        q3NoJob: Value(_nullableBool(f, 'q3_no_job')),
        decidedAt: Value(_date(f, 'decided_at')),
        transactionId: Value(_str(f, 'transaction_id')),
        deviceId: Value(_str(f, 'device_id')),
        version: Value(version),
        isDeleted: Value(_bool(f, 'is_deleted', false)),
        deletedAt: Value(_date(f, 'deleted_at')),
        createdAt: Value(_date(f, 'created_at') ?? DateTime.now().toUtc()),
        updatedAt: Value(_date(f, 'updated_at') ?? DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> _applyOvertimeEntry(
    DeltaChangeRecord change,
    Map<String, Object?> f,
  ) async {
    final version = change.newVersion ?? 1;
    await into(overtimeEntries).insertOnConflictUpdate(
      OvertimeEntriesCompanion(
        id: Value(change.recordId),
        userId: Value(_str(f, 'user_id') ?? ''),
        ledgerId: Value(_str(f, 'ledger_id')),
        workDate: Value(_date(f, 'work_date') ?? DateTime.now().toUtc()),
        minutes: Value(_int(f, 'minutes', 0)),
        compType: Value(_str(f, 'comp_type') ?? 'paid'),
        payAmountMinor: Value(_int(f, 'pay_amount_minor', 0)),
        extraCostMinor: Value(_int(f, 'extra_cost_minor', 0)),
        isRestDay: Value(_bool(f, 'is_rest_day', false)),
        note: Value(_str(f, 'note')),
        deviceId: Value(_str(f, 'device_id')),
        version: Value(version),
        isDeleted: Value(_bool(f, 'is_deleted', false)),
        deletedAt: Value(_date(f, 'deleted_at')),
        createdAt: Value(_date(f, 'created_at') ?? DateTime.now().toUtc()),
        updatedAt: Value(_date(f, 'updated_at') ?? DateTime.now().toUtc()),
      ),
    );
  }

  // ───────────────────────── 快照取值 ─────────────────────────

  String? _str(Map<String, Object?> f, String key) {
    final value = f[key];
    return value is String ? value : null;
  }

  int _int(Map<String, Object?> f, String key, int fallback) {
    final value = f[key];
    return value is num ? value.toInt() : fallback;
  }

  int? _nullableInt(Map<String, Object?> f, String key) {
    final value = f[key];
    return value is num ? value.toInt() : null;
  }

  /// 布尔：既认 `true/false`，也认 SQLite 原始行里的 `1/0`（旧包可能有）。
  bool _bool(Map<String, Object?> f, String key, bool fallback) {
    final value = f[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return fallback;
  }

  bool? _nullableBool(Map<String, Object?> f, String key) {
    final value = f[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    return null;
  }

  /// 时间：ISO 字符串（快照）与 unix 秒 / 毫秒（原始行）都认。
  ///
  /// drift 默认把 DateTime 存成整秒。日志里的 `changedFields` 就是原始行，
  /// 所以这里必须两种都吃，否则 `cooldown_until`、`work_date` 会静默变 null。
  DateTime? _date(Map<String, Object?> f, String key) {
    final value = f[key];
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    if (value is num) {
      final intValue = value.toInt();
      // 13 位是毫秒，10 位是秒。
      return intValue.abs() > 100000000000
          ? DateTime.fromMillisecondsSinceEpoch(intValue, isUtc: true)
          : DateTime.fromMillisecondsSinceEpoch(intValue * 1000, isUtc: true);
    }
    return null;
  }
}
