import 'package:miji/features/life_energy/domain/bonus_payment.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';

/// 记录一次「年终奖保存」的入参。
class SavedBonus {
  const SavedBonus({
    required this.taxYear,
    required this.amountMinor,
    this.sourceLabel,
    this.note,
    this.editing,
  });

  final int taxYear;
  final int amountMinor;
  final String? sourceLabel;
  final String? note;

  /// 是否为「改已有的一条」（编辑入口带 entry）。
  final bool? editing;
}

/// 记录一次「加一段薪资」的入参。
class SavedSegment {
  const SavedSegment({
    required this.effectiveYear,
    required this.effectiveMonth,
    required this.amountMinor,
    this.grossAmountMinor,
    this.employer,
    this.payroll,
  });

  final int effectiveYear;
  final int effectiveMonth;
  final int amountMinor;
  final int? grossAmountMinor;
  final String? employer;

  /// 这一段是否单独存了一份五险一金参数（段表单里那个开关）。
  final SocialInsuranceConfig? payroll;
}

/// 记录一次「加一件想买的」的入参。
class SavedWishItem {
  const SavedWishItem({
    required this.title,
    required this.targetAmountMinor,
    this.notes,
    this.desire,
    this.cooldownUntil,
    this.q1,
    this.q2,
    this.q3,
  });

  final String title;
  final int targetAmountMinor;
  final String? notes;
  final WishDesireLevel? desire;
  final DateTime? cooldownUntil;
  final bool? q1;
  final bool? q2;
  final bool? q3;
}

/// 只记入参、不落库的 actions。
///
/// 为什么要它：`LifeEnergyActions` 是具体类，方法都是虚的，子类覆盖掉要测的
/// 那几条就能把「表单 → action」这一段单独测起来 —— 不必拉 auth session、
/// 数据库和刷新链路。没覆盖的方法仍然会走真实现，所以测试里只点那些被覆盖的。
class FakeLifeEnergyActions extends LifeEnergyActions {
  FakeLifeEnergyActions(super.ref);

  final List<SavedBonus> savedBonuses = <SavedBonus>[];
  final List<SavedSegment> savedSegments = <SavedSegment>[];
  final List<SavedWishItem> savedWishItems = <SavedWishItem>[];
  final List<WorkProfile> savedProfiles = <WorkProfile>[];

  @override
  Future<void> saveBonus({
    required int taxYear,
    required int amountMinor,
    String? sourceLabel,
    String? note,
    BonusPayment? bonus,
  }) async {
    savedBonuses.add(
      SavedBonus(
        taxYear: taxYear,
        amountMinor: amountMinor,
        sourceLabel: sourceLabel,
        note: note,
        editing: bonus != null,
      ),
    );
  }

  @override
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
    savedSegments.add(
      SavedSegment(
        effectiveYear: effectiveYear,
        effectiveMonth: effectiveMonth,
        amountMinor: amountMinor,
        grossAmountMinor: grossAmountMinor,
        employer: employer,
        payroll: payroll,
      ),
    );
  }

  @override
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
    savedWishItems.add(
      SavedWishItem(
        title: title,
        targetAmountMinor: targetAmountMinor,
        notes: notes,
        desire: desire,
        cooldownUntil: cooldownUntil,
        q1: q1Satisfaction,
        q2: q2Aligned,
        q3: q3NoJob,
      ),
    );
  }

  @override
  Future<void> saveProfile(WorkProfile profile) async {
    savedProfiles.add(profile);
  }
}
