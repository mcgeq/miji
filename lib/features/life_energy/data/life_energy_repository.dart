import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/features/life_energy/domain/bonus_payment.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/overtime_record.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/salary_segment.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 时薪功能的数据访问。
///
/// 独立于 `DriftMoneyRepository`（那个已经 5000 行、按业务切成 15 个 part）：
/// 这三张表与流水之间没有事务耦合，唯一的交叉是「本月支出」——那一笔走
/// `MoneyRepository.summarizeTransactions`，不在这里重写一遍聚合逻辑。
class LifeEnergyRepository {
  LifeEnergyRepository(
    this._database, {
    Uuid? uuid,
    DateTime Function()? now,
    this._syncLogger,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final Uuid _uuid;
  final DateTime Function() _now;

  /// 变更日志。null = 不记（单元测试、没登录的场景）。
  ///
  /// 为什么在仓库里记而不是在 action 里：一次保存可能写多行（改档案会同时
  /// 改当前段、建段会顺带冻结上一段），只有仓库知道到底写了哪几行。
  final SyncChangeLogger? _syncLogger;

  /// 读出某行的当前版本号，并算出「写完之后应该是多少」。
  ///
  /// 同步的冲突判定比的是 `local.version != baseVersion`。这些表建表时就有
  /// `version` 列，但写路径从来没递增过（恒为 1）—— 那样冲突永远不会被检出，
  /// 远端变更会静默覆盖本地。所以每一次写都要经过这里。
  Future<({int? before, int after})> _versions(
    String table,
    String keyColumn,
    String key,
  ) async {
    final rows = await _database
        .customSelect(
          'SELECT version FROM $table WHERE $keyColumn = ? LIMIT 1',
          variables: [Variable.withString(key)],
        )
        .get();
    if (rows.isEmpty) {
      return (before: null, after: 1);
    }
    final before = rows.first.read<int>('version');
    return (before: before, after: before + 1);
  }

  /// 记一条变更日志：整行快照当 `changedFields`。
  ///
  /// 整行而不是差异：时薪这五张表的冲突粒度就是整行（没有金额组 / 分类组
  /// 那种可拆字段），而且这些数据写入频率很低，多带几列换「快照永远完整」
  /// 是划算的。
  Future<void> _logChange({
    required String table,
    required String keyColumn,
    required String recordId,
    required String userId,
    required SyncChangeOperation operation,
    required int? beforeVersion,
    required int afterVersion,
  }) async {
    final logger = _syncLogger;
    if (logger == null) {
      return;
    }
    final rows = await _database
        .customSelect(
          'SELECT * FROM $table WHERE $keyColumn = ? LIMIT 1',
          variables: [Variable.withString(recordId)],
        )
        .get();
    if (rows.isEmpty) {
      return;
    }
    await logger.recordChange(
      userId: userId,
      tableName: table,
      recordId: recordId,
      operation: operation,
      changedFields: rows.first.data,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  // ───────────────────────── 收入与工时 ─────────────────────────

  Stream<WorkProfile?> watchProfile(String userId) {
    return (_database.select(_database.lifeEnergyProfiles)
          ..where((row) => row.userId.equals(userId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _profileFromRow(row));
  }

  Future<WorkProfile?> fetchProfile(String userId) async {
    final row =
        await (_database.select(_database.lifeEnergyProfiles)..where(
              (row) => row.userId.equals(userId) & row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    return row == null ? null : _profileFromRow(row);
  }

  Future<void> saveProfile(WorkProfile profile) async {
    final now = _now();
    final versions = await _versions(
      SyncChangeLogger.lifeEnergyProfilesTableName,
      'user_id',
      profile.userId,
    );
    await _database
        .into(_database.lifeEnergyProfiles)
        .insertOnConflictUpdate(
          LifeEnergyProfilesCompanion(
            userId: Value(profile.userId),
            payAmountMinor: Value(profile.payAmountMinor),
            payCycle: Value(profile.payCycle.dbValue),
            currencyCode: Value(profile.currencyCode),
            compensationMode: Value(profile.compensationMode.dbValue),
            grossMonthlyMinor: Value(profile.grossMonthlyMinor),
            socialBaseMode: Value(profile.payroll.baseMode.dbValue),
            socialBaseMinor: Value(profile.payroll.baseOverrideMinor),
            socialBaseFloorMinor: Value(profile.payroll.baseFloorMinor),
            socialBaseCeilingMinor: Value(profile.payroll.baseCeilingMinor),
            ratePensionBp: Value(profile.payroll.pensionBp),
            rateMedicalBp: Value(profile.payroll.medicalBp),
            rateUnemploymentBp: Value(profile.payroll.unemploymentBp),
            rateHousingFundBp: Value(profile.payroll.housingFundBp),
            ratePensionErBp: Value(profile.payroll.pensionErBp),
            rateMedicalErBp: Value(profile.payroll.medicalErBp),
            rateUnemploymentErBp: Value(profile.payroll.unemploymentErBp),
            rateInjuryErBp: Value(profile.payroll.injuryErBp),
            rateHousingFundErBp: Value(profile.payroll.housingFundErBp),
            medicalFixedMinor: Value(profile.payroll.medicalFixedMinor),
            specialDeductionMinor: Value(profile.payroll.specialDeductionMinor),
            workDaysPerMonth: Value(profile.workDaysPerMonth),
            workMinutesPerDay: Value(profile.workMinutesPerDay),
            commuteMinutesPerDay: Value(profile.commuteMinutesPerDay),
            overtimeMinutesPerMonth: Value(profile.overtimeMinutesPerMonth),
            costTransportMinor: Value(profile.costTransportMinor),
            costMealMinor: Value(profile.costMealMinor),
            costClothingMinor: Value(profile.costClothingMinor),
            costChildcareMinor: Value(profile.costChildcareMinor),
            costDecompressMinor: Value(profile.costDecompressMinor),
            costOtherMinor: Value(profile.costOtherMinor),
            version: Value(versions.after),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await _logChange(
      table: SyncChangeLogger.lifeEnergyProfilesTableName,
      keyColumn: 'user_id',
      recordId: profile.userId,
      userId: profile.userId,
      operation: versions.before == null
          ? SyncChangeOperation.insert
          : SyncChangeOperation.update,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );

    // 档案的金额与条件也是「当前那一段」的镜像：改档案就等于改当前段。
    // 历史段一律不碰 —— 那正是「之前的保持不变」。
    final current = await _segmentAt(profile.userId, now);
    if (current == null) {
      // 段表空 = 还没建过历史。补一条当前段，让「工作单位」有地方落。
      await createSalarySegment(
        userId: profile.userId,
        effectiveYear: now.year,
        effectiveMonth: now.month,
        amountMinor: profile.payAmountMinor,
        grossAmountMinor: profile.isGrossMode
            ? profile.grossMonthlyMinor
            : null,
        employer: profile.employer,
        payCycle: profile.payCycle,
        workDaysPerMonth: profile.workDaysPerMonth,
        workMinutesPerDay: profile.workMinutesPerDay,
        commuteMinutesPerDay: profile.commuteMinutesPerDay,
        overtimeMinutesPerMonth: profile.overtimeMinutesPerMonth,
        workCostMonthlyMinor: profile.monthlyWorkCostMinor,
      );
      return;
    }
    await upsertSalarySegment(
      current.copyWith(
        amountMinor: profile.payAmountMinor,
        // 税前只在税前口径下写：切回「直接填到手」时把这一列清掉，否则段会被
        // 当成「有税前记录」，切换模式之后历史段仍然走推算。
        grossAmountMinor: profile.isGrossMode
            ? profile.grossMonthlyMinor
            : null,
        clearGrossAmount: !profile.isGrossMode,
        employer: profile.employer,
        clearEmployer: profile.employer == null,
        payCycle: profile.payCycle,
        workDaysPerMonth: profile.workDaysPerMonth,
        workMinutesPerDay: profile.workMinutesPerDay,
        commuteMinutesPerDay: profile.commuteMinutesPerDay,
        overtimeMinutesPerMonth: profile.overtimeMinutesPerMonth,
        workCostMonthlyMinor: profile.monthlyWorkCostMinor,
        updatedAt: now,
      ),
    );
  }

  // ───────────────────────── 职业段 ─────────────────────────

  Stream<List<SalarySegment>> watchSalarySegments(String userId) {
    return (_database.select(_database.salarySegments)
          ..where(
            (row) => row.userId.equals(userId) & row.isDeleted.equals(false),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.effectiveYear),
            (row) => OrderingTerm.asc(row.effectiveMonth),
          ]))
        .watch()
        .map((rows) => rows.map(_segmentFromRow).toList(growable: false));
  }

  Future<List<SalarySegment>> fetchSalarySegments(String userId) async {
    final rows =
        await (_database.select(_database.salarySegments)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.effectiveYear),
                (row) => OrderingTerm.asc(row.effectiveMonth),
              ]))
            .get();
    return rows.map(_segmentFromRow).toList(growable: false);
  }

  Future<void> upsertSalarySegment(SalarySegment segment) async {
    final versions = await _versions(
      SyncChangeLogger.salarySegmentsTableName,
      'id',
      segment.id,
    );
    await _database
        .into(_database.salarySegments)
        .insertOnConflictUpdate(
          SalarySegmentsCompanion(
            id: Value(segment.id),
            userId: Value(segment.userId),
            employer: Value(segment.employer),
            effectiveYear: Value(segment.effectiveYear),
            effectiveMonth: Value(segment.effectiveMonth),
            amountMinor: Value(segment.amountMinor),
            grossAmountMinor: Value(segment.grossAmountMinor),
            payCycle: Value(segment.payCycle?.dbValue),
            workDaysPerMonth: Value(segment.workDaysPerMonth),
            workMinutesPerDay: Value(segment.workMinutesPerDay),
            commuteMinutesPerDay: Value(segment.commuteMinutesPerDay),
            overtimeMinutesPerMonth: Value(segment.overtimeMinutesPerMonth),
            workCostMonthlyMinor: Value(segment.workCostMonthlyMinor),
            payrollJson: Value(
              segment.payroll == null
                  ? null
                  : jsonEncode(segment.payroll!.toJson()),
            ),
            note: Value(segment.note),
            version: Value(versions.after),
            createdAt: Value(segment.createdAt),
            updatedAt: Value(segment.updatedAt),
          ),
        );
    await _logChange(
      table: SyncChangeLogger.salarySegmentsTableName,
      keyColumn: 'id',
      recordId: segment.id,
      userId: segment.userId,
      operation: versions.before == null
          ? SyncChangeOperation.insert
          : SyncChangeOperation.update,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );
  }

  /// 新增一段，并**冻结上一段的继承值**。
  ///
  /// 冻结这一步是整个模型的关键：上一段原来靠「null = 继承档案」取值，如果
  /// 不固化，用户以后在档案里把通勤改成 90 分钟，三年前那段的时薪会跟着变。
  /// 冻结之后，历史段有自己的条件，档案只影响当前段。
  Future<String> createSalarySegment({
    required String userId,
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
    final now = _now();
    final profile = await fetchProfile(userId);
    final segments = await fetchSalarySegments(userId);
    final start = DateTime(effectiveYear, effectiveMonth);

    // 新段「之前」的相邻段（可能是中间插入）。
    SalarySegment? previous;
    for (final segment in segments) {
      if (!segment.start.isAfter(start)) {
        previous = segment;
      }
    }

    if (previous != null && profile != null) {
      await upsertSalarySegment(
        previous.copyWith(
          payCycle: previous.payCycle ?? profile.payCycle,
          workDaysPerMonth:
              previous.workDaysPerMonth ?? profile.workDaysPerMonth,
          workMinutesPerDay:
              previous.workMinutesPerDay ?? profile.workMinutesPerDay,
          commuteMinutesPerDay:
              previous.commuteMinutesPerDay ?? profile.commuteMinutesPerDay,
          overtimeMinutesPerMonth:
              previous.overtimeMinutesPerMonth ??
              profile.overtimeMinutesPerMonth,
          workCostMonthlyMinor:
              previous.workCostMonthlyMinor ?? profile.monthlyWorkCostMinor,
          // 参数同样要封口：不封的话，用户下次在档案里换城市（或等 7 月基数
          // 调整后改数），这一段历史会跟着重算 —— 到手和时薪一起变，而用户
          // 看不出是哪天错的。
          payroll: previous.payroll ?? profile.payroll,
          updatedAt: now,
        ),
      );
    }

    final id = _uuid.v4();
    await upsertSalarySegment(
      SalarySegment(
        id: id,
        userId: userId,
        employer: employer,
        effectiveYear: effectiveYear,
        effectiveMonth: effectiveMonth,
        amountMinor: amountMinor,
        grossAmountMinor: grossAmountMinor,
        payCycle: payCycle,
        workDaysPerMonth: workDaysPerMonth,
        workMinutesPerDay: workMinutesPerDay,
        commuteMinutesPerDay: commuteMinutesPerDay,
        overtimeMinutesPerMonth: overtimeMinutesPerMonth,
        workCostMonthlyMinor: workCostMonthlyMinor,
        // 新段默认不冻参数（null = 跟随档案）：它还在用，跟着档案改才对。
        payroll: payroll,
        note: note,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return id;
  }

  Future<void> deleteSalarySegment(String userId, String id) async {
    final now = _now();
    final segments = await fetchSalarySegments(userId);
    // 最后一段是「当前」，删掉它会让档案失去归属。要求先改档案，再删历史。
    if (segments.isNotEmpty && segments.last.id == id) {
      return;
    }
    final versions = await _versions(
      SyncChangeLogger.salarySegmentsTableName,
      'id',
      id,
    );
    await (_database.update(
      _database.salarySegments,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).write(
      SalarySegmentsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        version: Value(versions.after),
        updatedAt: Value(now),
      ),
    );
    await _logChange(
      table: SyncChangeLogger.salarySegmentsTableName,
      keyColumn: 'id',
      recordId: id,
      userId: userId,
      operation: SyncChangeOperation.delete,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );
  }

  Future<SalarySegment?> _segmentAt(String userId, DateTime at) async {
    final segments = await fetchSalarySegments(userId);
    SalarySegment? found;
    for (final segment in segments) {
      if (!segment.isEffectiveAt(at)) {
        break;
      }
      found = segment;
    }
    return found ?? (segments.isEmpty ? null : segments.first);
  }

  // ───────────────────────── 年终奖 ─────────────────────────

  /// 按年度倒序。未指定年度（`taxYear = 0`）排最前，提醒人先把它认领掉。
  Stream<List<BonusPayment>> watchBonuses(String userId) {
    return (_database.select(_database.bonusPayments)
          ..where(
            (row) => row.userId.equals(userId) & row.isDeleted.equals(false),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.taxYear)]))
        .watch()
        .map((rows) => rows.map(_bonusFromRow).toList(growable: false));
  }

  Future<List<BonusPayment>> fetchBonuses(String userId) async {
    final rows =
        await (_database.select(_database.bonusPayments)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.taxYear)]))
            .get();
    return rows.map(_bonusFromRow).toList(growable: false);
  }

  /// 保存一笔年终奖。**同一年已有一条就覆盖它** —— 「一个纳税年度只能用一次
  /// 单独计税」是税法规定，不是界面的便利：两笔同年奖金各按单独计税算，
  /// 算出来的税是错的（第二笔该并入综合所得）。
  ///
  /// 覆盖是静默的：用户在同一个年份上再填一次，意图几乎必然是「填错了，改」。
  Future<String> saveBonus({
    required String userId,
    required int taxYear,
    required int amountMinor,
    String? sourceLabel,
    String? note,
    String? id,
  }) async {
    final now = _now();
    final existing = await fetchBonuses(userId);
    // 同一年已有一条就覆盖它（见上面的说明）。`firstOrNull` 在 core 里没有，
    // 这里手写一个循环 —— 一条 group by 的查询能省一次遍历，但没必要。
    BonusPayment? sameYear;
    for (final bonus in existing) {
      if (bonus.taxYear == taxYear) {
        sameYear = bonus;
        break;
      }
    }
    final targetId = id ?? sameYear?.id ?? _uuid.v4();
    final versions = await _versions(
      SyncChangeLogger.bonusPaymentsTableName,
      'id',
      targetId,
    );

    await _database
        .into(_database.bonusPayments)
        .insertOnConflictUpdate(
          BonusPaymentsCompanion(
            id: Value(targetId),
            userId: Value(userId),
            taxYear: Value(taxYear),
            amountMinor: Value(amountMinor),
            sourceLabel: Value(
              (sourceLabel == null || sourceLabel.trim().isEmpty)
                  ? null
                  : sourceLabel.trim(),
            ),
            note: Value(
              (note == null || note.trim().isEmpty) ? null : note.trim(),
            ),
            version: Value(versions.after),
            createdAt: Value(
              id == null && sameYear == null
                  ? now
                  : (sameYear?.createdAt ?? now),
            ),
            updatedAt: Value(now),
          ),
        );
    await _logChange(
      table: SyncChangeLogger.bonusPaymentsTableName,
      keyColumn: 'id',
      recordId: targetId,
      userId: userId,
      operation: versions.before == null
          ? SyncChangeOperation.insert
          : SyncChangeOperation.update,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );
    return targetId;
  }

  Future<void> deleteBonus(String userId, String id) async {
    final now = _now();
    final versions = await _versions(
      SyncChangeLogger.bonusPaymentsTableName,
      'id',
      id,
    );
    await (_database.update(
      _database.bonusPayments,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).write(
      BonusPaymentsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        version: Value(versions.after),
        updatedAt: Value(now),
      ),
    );
    await _logChange(
      table: SyncChangeLogger.bonusPaymentsTableName,
      keyColumn: 'id',
      recordId: id,
      userId: userId,
      operation: SyncChangeOperation.delete,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );
  }

  BonusPayment _bonusFromRow(BonusPaymentRecord row) {
    return BonusPayment(
      id: row.id,
      userId: row.userId,
      taxYear: row.taxYear,
      amountMinor: row.amountMinor,
      sourceLabel: row.sourceLabel,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  // ───────────────────────── 想买清单 ─────────────────────────

  /// 按账本隔离，但**不丢**跨账本创建（`ledgerId` 为空）的记录：那可能是
  /// 用户还没建账本时先记下来的东西，静默消失比混着显示更糟。
  Stream<List<WishlistEntry>> watchWishlist({
    required String userId,
    String? ledgerId,
  }) {
    final query = _database.select(_database.wishlistItems)
      ..where((row) => row.userId.equals(userId) & row.isDeleted.equals(false))
      ..orderBy([
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ]);
    if (ledgerId != null && ledgerId.isNotEmpty) {
      query.where(
        (row) => row.ledgerId.isNull() | row.ledgerId.equals(ledgerId),
      );
    }
    return query.watch().map(
      (rows) => rows.map(_wishlistFromRow).toList(growable: false),
    );
  }

  Future<String> createWishlistEntry({
    required String userId,
    required String title,
    required int targetAmountMinor,
    String? ledgerId,
    String? notes,
    WishDesireLevel desire = WishDesireLevel.want,
    DateTime? cooldownUntil,
    bool? q1Satisfaction,
    bool? q2Aligned,
    bool? q3NoJob,
  }) async {
    final now = _now();
    final id = _uuid.v4();
    await _database
        .into(_database.wishlistItems)
        .insert(
          WishlistItemsCompanion.insert(
            id: id,
            userId: userId,
            ledgerId: Value(ledgerId),
            title: title,
            notes: Value(notes),
            targetAmountMinor: targetAmountMinor,
            desireLevel: Value(desire.dbValue),
            cooldownUntil: Value(cooldownUntil),
            q1Satisfaction: Value(q1Satisfaction),
            q2Aligned: Value(q2Aligned),
            q3NoJob: Value(q3NoJob),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _logChange(
      table: SyncChangeLogger.wishlistItemsTableName,
      keyColumn: 'id',
      recordId: id,
      userId: userId,
      operation: SyncChangeOperation.insert,
      beforeVersion: null,
      afterVersion: 1,
    );
    return id;
  }

  /// 整体写回一条记录（编辑 / 标记买了 / 放弃）。
  Future<void> updateWishlistEntry(WishlistEntry entry) async {
    final versions = await _versions(
      SyncChangeLogger.wishlistItemsTableName,
      'id',
      entry.id,
    );
    await (_database.update(
      _database.wishlistItems,
    )..where((row) => row.id.equals(entry.id))).write(
      WishlistItemsCompanion(
        title: Value(entry.title),
        notes: Value(entry.notes),
        targetAmountMinor: Value(entry.targetAmountMinor),
        desireLevel: Value(entry.desire.dbValue),
        status: Value(entry.storedStatus.dbValue),
        cooldownUntil: Value(entry.cooldownUntil),
        q1Satisfaction: Value(entry.q1Satisfaction),
        q2Aligned: Value(entry.q2Aligned),
        q3NoJob: Value(entry.q3NoJob),
        decidedAt: Value(entry.decidedAt),
        transactionId: Value(entry.transactionId),
        version: Value(versions.after),
        updatedAt: Value(_now()),
      ),
    );
    await _logChange(
      table: SyncChangeLogger.wishlistItemsTableName,
      keyColumn: 'id',
      recordId: entry.id,
      userId: entry.userId,
      operation: SyncChangeOperation.update,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );
  }

  Future<void> deleteWishlistEntry(String userId, String id) async {
    final now = _now();
    final versions = await _versions(
      SyncChangeLogger.wishlistItemsTableName,
      'id',
      id,
    );
    await (_database.update(
      _database.wishlistItems,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).write(
      WishlistItemsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        version: Value(versions.after),
        updatedAt: Value(now),
      ),
    );
    await _logChange(
      table: SyncChangeLogger.wishlistItemsTableName,
      keyColumn: 'id',
      recordId: id,
      userId: userId,
      operation: SyncChangeOperation.delete,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );
  }

  // ───────────────────────── 加班记录 ─────────────────────────

  /// 某个月的加班记录（`[monthStart, nextMonthStart)`）。
  ///
  /// 只按月份取，不按账本：时薪是账号级的，本月加班算在哪个账本头上对
  /// 时薪没有影响；硬按账本过滤会让「家庭账本里加了一周班」从个人账本
  /// 的本期视图里消失。
  Stream<List<OvertimeRecord>> watchOvertimeEntries({
    required String userId,
    required DateTime monthStart,
  }) {
    final monthEnd = DateTime(monthStart.year, monthStart.month + 1);
    return (_database.select(_database.overtimeEntries)..where(
          (row) =>
              row.userId.equals(userId) &
              row.isDeleted.equals(false) &
              row.workDate.isBiggerOrEqualValue(monthStart) &
              row.workDate.isSmallerThanValue(monthEnd),
        ))
        .watch()
        .map(
          (rows) =>
              rows.map(_overtimeFromRow).toList(growable: false)
                ..sort((a, b) => b.workDate.compareTo(a.workDate)),
        );
  }

  Future<String> createOvertimeEntry({
    required String userId,
    required DateTime workDate,
    required int minutes,
    String? ledgerId,
    OvertimeCompensation compensation = OvertimeCompensation.paid,
    int payAmountMinor = 0,
    int extraCostMinor = 0,
    bool isRestDay = false,
    String? note,
  }) async {
    final now = _now();
    final id = _uuid.v4();
    await _database
        .into(_database.overtimeEntries)
        .insert(
          OvertimeEntriesCompanion.insert(
            id: id,
            userId: userId,
            ledgerId: Value(ledgerId),
            workDate: workDate,
            minutes: minutes,
            compType: Value(compensation.dbValue),
            payAmountMinor: Value(payAmountMinor),
            extraCostMinor: Value(extraCostMinor),
            isRestDay: Value(isRestDay),
            note: Value(note),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await _logChange(
      table: SyncChangeLogger.overtimeEntriesTableName,
      keyColumn: 'id',
      recordId: id,
      userId: userId,
      operation: SyncChangeOperation.insert,
      beforeVersion: null,
      afterVersion: 1,
    );
    return id;
  }

  Future<void> deleteOvertimeEntry(String userId, String id) async {
    final now = _now();
    final versions = await _versions(
      SyncChangeLogger.overtimeEntriesTableName,
      'id',
      id,
    );
    await (_database.update(
      _database.overtimeEntries,
    )..where((row) => row.id.equals(id) & row.userId.equals(userId))).write(
      OvertimeEntriesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        version: Value(versions.after),
        updatedAt: Value(now),
      ),
    );
    await _logChange(
      table: SyncChangeLogger.overtimeEntriesTableName,
      keyColumn: 'id',
      recordId: id,
      userId: userId,
      operation: SyncChangeOperation.delete,
      beforeVersion: versions.before,
      afterVersion: versions.after,
    );
  }

  // ───────────────────────── 映射 ─────────────────────────

  WorkProfile _profileFromRow(LifeEnergyProfile row) {
    return WorkProfile(
      userId: row.userId,
      payAmountMinor: row.payAmountMinor,
      payCycle: LifeEnergyPayCycle.fromDb(row.payCycle),
      currencyCode: row.currencyCode,
      compensationMode: LifeEnergyCompensationMode.fromDb(row.compensationMode),
      grossMonthlyMinor: row.grossMonthlyMinor,
      payroll: _configFromRow(row),
      workDaysPerMonth: row.workDaysPerMonth,
      workMinutesPerDay: row.workMinutesPerDay,
      commuteMinutesPerDay: row.commuteMinutesPerDay,
      overtimeMinutesPerMonth: row.overtimeMinutesPerMonth,
      costTransportMinor: row.costTransportMinor,
      costMealMinor: row.costMealMinor,
      costClothingMinor: row.costClothingMinor,
      costChildcareMinor: row.costChildcareMinor,
      costDecompressMinor: row.costDecompressMinor,
      costOtherMinor: row.costOtherMinor,
    );
  }

  SocialInsuranceConfig _configFromRow(LifeEnergyProfile row) {
    return SocialInsuranceConfig(
      baseMode: SocialBaseMode.fromDb(row.socialBaseMode),
      baseOverrideMinor: row.socialBaseMinor,
      baseFloorMinor: row.socialBaseFloorMinor,
      baseCeilingMinor: row.socialBaseCeilingMinor,
      pensionBp: row.ratePensionBp,
      medicalBp: row.rateMedicalBp,
      unemploymentBp: row.rateUnemploymentBp,
      housingFundBp: row.rateHousingFundBp,
      pensionErBp: row.ratePensionErBp,
      medicalErBp: row.rateMedicalErBp,
      unemploymentErBp: row.rateUnemploymentErBp,
      injuryErBp: row.rateInjuryErBp,
      housingFundErBp: row.rateHousingFundErBp,
      medicalFixedMinor: row.medicalFixedMinor,
      specialDeductionMinor: row.specialDeductionMinor,
    );
  }

  SalarySegment _segmentFromRow(SalarySegmentRow row) {
    return SalarySegment(
      id: row.id,
      userId: row.userId,
      employer: row.employer,
      effectiveYear: row.effectiveYear,
      effectiveMonth: row.effectiveMonth,
      amountMinor: row.amountMinor,
      grossAmountMinor: row.grossAmountMinor,
      payCycle: row.payCycle == null
          ? null
          : LifeEnergyPayCycle.fromDb(row.payCycle!),
      workDaysPerMonth: row.workDaysPerMonth,
      workMinutesPerDay: row.workMinutesPerDay,
      commuteMinutesPerDay: row.commuteMinutesPerDay,
      overtimeMinutesPerMonth: row.overtimeMinutesPerMonth,
      workCostMonthlyMinor: row.workCostMonthlyMinor,
      payroll: _payrollFromJson(row.payrollJson),
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// 快照解析：坏了就当没有（跟随档案），不让一整页历史因为一行 JSON 打不开。
  SocialInsuranceConfig? _payrollFromJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) {
        return null;
      }
      return SocialInsuranceConfig.fromJson(decoded);
    } on FormatException {
      return null;
    }
  }

  WishlistEntry _wishlistFromRow(WishlistItem row) {
    return WishlistEntry(
      id: row.id,
      userId: row.userId,
      ledgerId: row.ledgerId,
      title: row.title,
      notes: row.notes,
      targetAmountMinor: row.targetAmountMinor,
      desire: WishDesireLevel.fromDb(row.desireLevel),
      storedStatus: WishlistItemStatus.fromDb(row.status),
      cooldownUntil: row.cooldownUntil,
      q1Satisfaction: row.q1Satisfaction,
      q2Aligned: row.q2Aligned,
      q3NoJob: row.q3NoJob,
      decidedAt: row.decidedAt,
      transactionId: row.transactionId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  OvertimeRecord _overtimeFromRow(OvertimeEntry row) {
    return OvertimeRecord(
      id: row.id,
      userId: row.userId,
      ledgerId: row.ledgerId,
      workDate: row.workDate,
      minutes: row.minutes,
      compensation: OvertimeCompensation.fromDb(row.compType),
      payAmountMinor: row.payAmountMinor,
      extraCostMinor: row.extraCostMinor,
      isRestDay: row.isRestDay,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
