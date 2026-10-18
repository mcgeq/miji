import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/features/life_energy/data/life_energy_repository.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

void main() {
  late AppDatabase database;
  late LifeEnergyRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = LifeEnergyRepository(database);
    final now = DateTime(2026, 10, 18, 9);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  group('收入与工时', () {
    test('没填过时是 null，而不是一份默认时薪', () async {
      expect(await repository.fetchProfile('user-1'), isNull);
      expect(await repository.watchProfile('user-1').first, isNull);
    });

    test('保存后能读回全部字段，重复保存是覆盖而不是插两条', () async {
      const profile = WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 21,
        workMinutesPerDay: 470,
        commuteMinutesPerDay: 80,
        overtimeMinutesPerMonth: 300,
        costTransportMinor: 50000,
      );
      await repository.saveProfile(profile);

      final first = await repository.fetchProfile('user-1');
      expect(first, isNotNull);
      expect(first!.workDaysPerMonth, 21);
      expect(first.commuteMinutesPerDay, 80);
      expect(first.costTransportMinor, 50000);
      expect(first.payCycle, LifeEnergyPayCycle.month);

      await repository.saveProfile(profile.copyWith(workDaysPerMonth: 23));
      final rows = await database.select(database.lifeEnergyProfiles).get();
      expect(rows, hasLength(1), reason: '主键是 userId，不该插出第二条');
      expect(rows.single.workDaysPerMonth, 23);
    });
  });

  group('想买清单', () {
    test('新建后出现在清单里，状态默认是等待、冷却期原样保存', () async {
      final deadline = DateTime(2026, 10, 25);
      await repository.createWishlistEntry(
        userId: 'user-1',
        ledgerId: 'ledger-1',
        title: '降噪耳机',
        targetAmountMinor: 189900,
        cooldownUntil: deadline,
        q1Satisfaction: true,
      );

      final entries = await repository.watchWishlist(userId: 'user-1').first;
      expect(entries, hasLength(1));
      expect(entries.single.title, '降噪耳机');
      expect(entries.single.ledgerId, 'ledger-1');
      expect(entries.single.storedStatus, WishlistItemStatus.waiting);
      expect(entries.single.q1Satisfaction, isTrue);
      expect(entries.single.answeredQuestionCount, 1);
      expect(entries.single.cooldownUntil!.toLocal(), deadline.toLocal());
    });

    test('按账本隔离，但不丢跨账本（ledgerId 为空）的记录', () async {
      await repository.createWishlistEntry(
        userId: 'user-1',
        ledgerId: 'ledger-1',
        title: '个人账本的东西',
        targetAmountMinor: 10000,
      );
      await repository.createWishlistEntry(
        userId: 'user-1',
        ledgerId: 'ledger-2',
        title: '家庭账本的东西',
        targetAmountMinor: 20000,
      );
      await repository.createWishlistEntry(
        userId: 'user-1',
        title: '还没建账本时记的',
        targetAmountMinor: 30000,
      );

      final forLedgerOne = await repository
          .watchWishlist(userId: 'user-1', ledgerId: 'ledger-1')
          .first;
      expect(forLedgerOne.map((entry) => entry.title).toSet(), {
        '个人账本的东西',
        '还没建账本时记的',
      });

      final all = await repository.watchWishlist(userId: 'user-1').first;
      expect(all, hasLength(3));
    });

    test('标记买了之后状态落库，软删除后从清单消失', () async {
      await repository.createWishlistEntry(
        userId: 'user-1',
        title: '耳机',
        targetAmountMinor: 189900,
      );
      final created =
          (await repository.watchWishlist(userId: 'user-1').first).single;

      await repository.updateWishlistEntry(
        created.copyWith(
          storedStatus: WishlistItemStatus.bought,
          decidedAt: DateTime(2026, 10, 20),
        ),
      );
      final settled =
          (await repository.watchWishlist(userId: 'user-1').first).single;
      expect(settled.storedStatus, WishlistItemStatus.bought);
      expect(settled.decidedAt, isNotNull);

      await repository.deleteWishlistEntry('user-1', created.id);
      expect(await repository.watchWishlist(userId: 'user-1').first, isEmpty);
      // 软删：行还在，只是 isDeleted 了（同步 / 恢复都要靠它）。
      final rows = await database.select(database.wishlistItems).get();
      expect(rows.single.isDeleted, isTrue);
    });
  });

  group('加班记录', () {
    test('按月份取，别的月份不会混进来', () async {
      await repository.createOvertimeEntry(
        userId: 'user-1',
        workDate: DateTime(2026, 10, 12),
        minutes: 120,
        compensation: OvertimeCompensation.paid,
        payAmountMinor: 20000,
      );
      await repository.createOvertimeEntry(
        userId: 'user-1',
        workDate: DateTime(2026, 9, 30),
        minutes: 60,
      );

      final october = await repository
          .watchOvertimeEntries(
            userId: 'user-1',
            monthStart: DateTime(2026, 10),
          )
          .first;
      expect(october, hasLength(1));
      expect(october.single.minutes, 120);
      expect(october.single.compensation, OvertimeCompensation.paid);
      expect(october.single.payAmountMinor, 20000);

      final september = await repository
          .watchOvertimeEntries(userId: 'user-1', monthStart: DateTime(2026, 9))
          .first;
      expect(september, hasLength(1));
      expect(september.single.minutes, 60);
    });

    test('删除后不再计入本期，但行保留（软删）', () async {
      final id = await repository.createOvertimeEntry(
        userId: 'user-1',
        workDate: DateTime(2026, 10, 12),
        minutes: 120,
      );
      await repository.deleteOvertimeEntry('user-1', id);

      expect(
        await repository
            .watchOvertimeEntries(
              userId: 'user-1',
              monthStart: DateTime(2026, 10),
            )
            .first,
        isEmpty,
      );
      expect(
        (await database.select(database.overtimeEntries).get())
            .single
            .isDeleted,
        isTrue,
      );
    });
  });

  group('职业段', () {
    late LifeEnergyRepository fixed;
    final october = DateTime(2026, 10, 18, 9);

    setUp(() {
      // 钉住「现在」：段解析、当前段判定都看 today，测试不能跟着系统日期漂。
      fixed = LifeEnergyRepository(database, now: () => october);
    });

    Future<void> seedProfile({int commute = 70, int workCost = 80000}) {
      return fixed.saveProfile(
        WorkProfile(
          userId: 'user-1',
          payAmountMinor: 1200000,
          payCycle: LifeEnergyPayCycle.month,
          commuteMinutesPerDay: commute,
          costTransportMinor: workCost,
        ),
      );
    }

    test('第一次保存档案会落下当前段，工作单位有地方存', () async {
      await fixed.saveProfile(
        const WorkProfile(
          userId: 'user-1',
          payAmountMinor: 1200000,
          payCycle: LifeEnergyPayCycle.month,
          employer: '云图科技',
        ),
      );

      final segments = await fixed.fetchSalarySegments('user-1');
      expect(segments, hasLength(1));
      expect(segments.single.employer, '云图科技');
      expect(segments.single.effectiveYear, october.year);
      expect(segments.single.effectiveMonth, october.month);
      expect(segments.single.amountMinor, 1200000);
    });

    test('再建一段时，上一段的继承值被冻结成显式值', () async {
      await seedProfile(commute: 70, workCost: 80000);
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2025,
        effectiveMonth: 1,
        amountMinor: 1600000,
      );

      final before = (await fixed.fetchSalarySegments(
        'user-1',
      )).firstWhere((s) => s.effectiveYear == 2025);
      expect(before.commuteMinutesPerDay, isNull);

      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2026,
        effectiveMonth: 7,
        amountMinor: 2000000,
        employer: '云图科技',
        commuteMinutesPerDay: 70,
        workCostMonthlyMinor: 170000,
      );

      final after = await fixed.fetchSalarySegments('user-1');
      final first = after.firstWhere((s) => s.effectiveYear == 2025);
      // 冻结：原来 null（继承档案），现在写成了显式值。
      expect(first.commuteMinutesPerDay, 70);
      expect(first.workCostMonthlyMinor, 80000);
      expect(first.payCycle, LifeEnergyPayCycle.month);
    });

    test('冻结之后改档案，旧段的时薪不再跟着动', () async {
      await seedProfile(commute: 70, workCost: 80000);
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2025,
        effectiveMonth: 1,
        amountMinor: 1600000,
      );
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2026,
        effectiveMonth: 7,
        amountMinor: 2000000,
      );

      await seedProfile(commute: 120, workCost: 200000);

      final segments = await fixed.fetchSalarySegments('user-1');
      final first = segments.firstWhere((s) => s.effectiveYear == 2025);
      expect(first.commuteMinutesPerDay, 70);
      expect(first.workCostMonthlyMinor, 80000);
    });

    test('保存档案只改当前段，历史段一分不动', () async {
      await seedProfile();
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2025,
        effectiveMonth: 1,
        amountMinor: 1600000,
      );
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2026,
        effectiveMonth: 7,
        amountMinor: 2000000,
      );

      await seedProfile();
      await fixed.saveProfile(
        const WorkProfile(
          userId: 'user-1',
          payAmountMinor: 2500000,
          payCycle: LifeEnergyPayCycle.month,
          employer: '云图科技',
        ),
      );

      final segments = await fixed.fetchSalarySegments('user-1');
      // 2025-01 历史段 · 2026-07 涨薪段 · 2026-10 当前段（保存档案时建的）
      expect(segments, hasLength(3));
      expect(
        segments.firstWhere((s) => s.effectiveYear == 2025).amountMinor,
        1600000,
      );
      expect(
        segments
            .firstWhere((s) => s.effectiveYear == 2026 && s.effectiveMonth == 7)
            .amountMinor,
        2000000,
      );
      // 只有当前段跟着档案变成 25,000
      expect(
        segments
            .firstWhere(
              (s) => s.effectiveYear == 2026 && s.effectiveMonth == 10,
            )
            .amountMinor,
        2500000,
      );
    });

    test('新建段时把上一段的五险一金参数封口，之后改档案不动历史', () async {
      await fixed.saveProfile(
        const WorkProfile(
          userId: 'user-1',
          payAmountMinor: 1200000,
          payCycle: LifeEnergyPayCycle.month,
          grossMonthlyMinor: 2000000,
          compensationMode: LifeEnergyCompensationMode.gross,
        ),
      );
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2025,
        effectiveMonth: 1,
        amountMinor: 1600000,
        grossAmountMinor: 2000000,
      );
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2026,
        effectiveMonth: 7,
        amountMinor: 2000000,
        grossAmountMinor: 2500000,
      );

      final frozen = (await fixed.fetchSalarySegments(
        'user-1',
      )).firstWhere((s) => s.effectiveYear == 2025);
      expect(frozen.payroll, isNotNull, reason: '被合上的那一段要冻住参数');
      expect(
        frozen.payroll,
        SocialInsuranceConfig.defaults,
        reason: '冻结的就是当时档案里那一份',
      );

      // 现在人在别的城市：改档案的比例。
      final moved = SocialInsuranceConfig.defaults.copyWith(
        housingFundBp: 500,
        baseFloorMinor: 352300,
      );
      await fixed.saveProfile(
        WorkProfile(
          userId: 'user-1',
          payAmountMinor: 1200000,
          payCycle: LifeEnergyPayCycle.month,
          grossMonthlyMinor: 2000000,
          compensationMode: LifeEnergyCompensationMode.gross,
          payroll: moved,
        ),
      );

      final afterMove = (await fixed.fetchSalarySegments(
        'user-1',
      )).firstWhere((s) => s.effectiveYear == 2025);
      expect(afterMove.payroll!.housingFundBp, 1200, reason: '历史段不该跟着变');

      // 当前段（未冻结）跟着档案走。
      final current = (await fixed.fetchSalarySegments('user-1')).last;
      expect(current.payroll, isNull);
    });

    test('按生效年月升序返回，跨年也排得对', () async {
      await seedProfile();
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2026,
        effectiveMonth: 1,
        amountMinor: 900000,
      );
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2025,
        effectiveMonth: 12,
        amountMinor: 800000,
      );

      final segments = await fixed.fetchSalarySegments('user-1');
      expect(segments.map((s) => '${s.effectiveYear}-${s.effectiveMonth}'), [
        '2025-12',
        '2026-1',
        '2026-10',
      ]);
    });

    test('当前段删不掉：删了档案就没有归属', () async {
      await seedProfile();
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2025,
        effectiveMonth: 1,
        amountMinor: 1600000,
      );
      await fixed.createSalarySegment(
        userId: 'user-1',
        effectiveYear: 2026,
        effectiveMonth: 7,
        amountMinor: 2000000,
      );

      final segments = await fixed.fetchSalarySegments('user-1');
      expect(segments, hasLength(3));

      // 当前段（2026-10）删不动
      await fixed.deleteSalarySegment('user-1', segments.last.id);
      expect(await fixed.fetchSalarySegments('user-1'), hasLength(3));

      // 历史段可以删
      await fixed.deleteSalarySegment('user-1', segments.first.id);
      expect(await fixed.fetchSalarySegments('user-1'), hasLength(2));
    });
  });

  group('年终奖', () {
    late LifeEnergyRepository fixed;
    final october = DateTime(2026, 10, 18, 9);

    setUp(() {
      fixed = LifeEnergyRepository(database, now: () => october);
    });

    Future<void> seedUser() => fixed.saveProfile(
      const WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        payCycle: LifeEnergyPayCycle.month,
      ),
    );

    test('不同年度各存一条，互不覆盖 —— 换公司也分得清', () async {
      await seedUser();
      await fixed.saveBonus(
        userId: 'user-1',
        taxYear: 2025,
        amountMinor: 6000000,
        sourceLabel: '星野科技',
      );
      await fixed.saveBonus(
        userId: 'user-1',
        taxYear: 2026,
        amountMinor: 4000000,
        sourceLabel: '云图科技',
      );

      final bonuses = await fixed.fetchBonuses('user-1');
      expect(bonuses, hasLength(2));
      // 倒序：最近的年度在前。
      expect(bonuses.first.taxYear, 2026);
      expect(bonuses.first.amountMinor, 4000000);
      expect(bonuses.first.sourceLabel, '云图科技');
      expect(bonuses.last.taxYear, 2025);
      expect(bonuses.last.amountMinor, 6000000);
      expect(bonuses.last.sourceLabel, '星野科技');
    });

    test('同一年再填一次是覆盖，不是加第二条', () async {
      await seedUser();
      await fixed.saveBonus(
        userId: 'user-1',
        taxYear: 2026,
        amountMinor: 4000000,
        sourceLabel: '云图科技',
      );
      final first = (await fixed.fetchBonuses('user-1')).single;

      await fixed.saveBonus(
        userId: 'user-1',
        taxYear: 2026,
        amountMinor: 4500000,
        sourceLabel: '云图科技',
      );

      final bonuses = await fixed.fetchBonuses('user-1');
      expect(bonuses, hasLength(1), reason: '一年只能用一次单独计税，不能有两条');
      expect(bonuses.single.id, first.id, reason: '改的是同一条，不是新加一条');
      expect(bonuses.single.amountMinor, 4500000);
    });

    test('买了之后把交易 id 写回清单项（一条记录，不是两份真相）', () async {
      await seedUser();
      await fixed.createWishlistEntry(
        userId: 'user-1',
        title: '降噪耳机',
        targetAmountMinor: 129900,
      );
      final entry = (await fixed.watchWishlist(userId: 'user-1').first).single;
      expect(entry.transactionId, isNull);

      final now = october;
      await fixed.updateWishlistEntry(
        entry.copyWith(
          storedStatus: WishlistItemStatus.bought,
          decidedAt: now,
          transactionId: 'txn-1',
          updatedAt: now,
        ),
      );

      final read = (await fixed.watchWishlist(userId: 'user-1').first).single;
      expect(read.transactionId, 'txn-1');
      expect(read.statusAt(now), WishlistItemStatus.bought);
    });

    test('删掉是软删：行还在，但不再返回', () async {
      await seedUser();
      await fixed.saveBonus(
        userId: 'user-1',
        taxYear: 2026,
        amountMinor: 4000000,
      );
      final bonus = (await fixed.fetchBonuses('user-1')).single;

      await fixed.deleteBonus('user-1', bonus.id);
      expect(await fixed.fetchBonuses('user-1'), isEmpty);
    });
  });

  group('税前推算', () {
    late LifeEnergyRepository fixed;
    final october = DateTime(2026, 10, 18, 9);

    setUp(() {
      fixed = LifeEnergyRepository(database, now: () => october);
    });

    WorkProfile gross() => const WorkProfile(
      userId: 'user-1',
      payAmountMinor: 1465000,
      payCycle: LifeEnergyPayCycle.month,
      compensationMode: LifeEnergyCompensationMode.gross,
      grossMonthlyMinor: 2000000,
      payroll: SocialInsuranceConfig(
        baseMode: SocialBaseMode.manual,
        baseOverrideMinor: 1800000,
        baseFloorMinor: 738400,
        baseCeilingMinor: 3692100,
        housingFundBp: 700,
        specialDeductionMinor: 200000,
      ),
    );

    test('税前口径的参数整存整取，比例是万分比整数', () async {
      await fixed.saveProfile(gross());

      final read = await fixed.fetchProfile('user-1');
      expect(read!.compensationMode, LifeEnergyCompensationMode.gross);
      expect(read.grossMonthlyMinor, 2000000);
      expect(read.payroll.baseMode, SocialBaseMode.manual);
      expect(read.payroll.baseOverrideMinor, 1800000);
      expect(read.payroll.baseFloorMinor, 738400);
      expect(read.payroll.housingFundBp, 700);
      expect(read.payroll.specialDeductionMinor, 200000);
      // 没改的项沿用默认值，不会因为改了一个比例而整组清零。
      expect(read.payroll.pensionBp, 800);
    });

    test('当前段跟着写税前；切回「直接填到手」时把税前清掉', () async {
      await fixed.saveProfile(gross());

      var segments = await fixed.fetchSalarySegments('user-1');
      expect(segments, hasLength(1));
      expect(segments.single.grossAmountMinor, 2000000);
      // 到手那一列恒为到手，切口径不会把它重新解释。
      expect(segments.single.amountMinor, 1465000);

      await fixed.saveProfile(
        gross().copyWith(
          compensationMode: LifeEnergyCompensationMode.net,
          grossMonthlyMinor: 0,
        ),
      );

      segments = await fixed.fetchSalarySegments('user-1');
      expect(
        segments.single.grossAmountMinor,
        isNull,
        reason: '留着税前会让这段在切回 net 之后仍然走推算',
      );
    });

    test('缺省档案是 net 口径：老用户升级后看到的界面不变', () async {
      await fixed.saveProfile(
        const WorkProfile(
          userId: 'user-1',
          payAmountMinor: 1200000,
          payCycle: LifeEnergyPayCycle.month,
        ),
      );

      final read = await fixed.fetchProfile('user-1');
      expect(read!.compensationMode, LifeEnergyCompensationMode.net);
      expect(read.grossMonthlyMinor, 0);
    });
  });
}
