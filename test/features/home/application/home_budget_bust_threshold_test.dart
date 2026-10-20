import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

HomeMonthBudgetSummary _summary({
  int totalMinor = 800000,
  int usedMinor = 0,
  int committedMinor = 0,
  bool hasBudget = true,
}) {
  return HomeMonthBudgetSummary(
    hasBudget: hasBudget,
    currencyCode: 'CNY',
    budgetId: hasBudget ? 'b1' : null,
    budgetName: hasBudget ? '本月预算' : null,
    totalMinor: totalMinor,
    usedMinor: usedMinor,
    remainingMinor: totalMinor - usedMinor,
    committedMinor: committedMinor,
    progress: totalMinor <= 0 ? 0 : usedMinor / totalMinor,
    periodProgress: 0.6,
    paceRatio: 1,
    paceLabel: '正常',
    remainingDays: 10,
  );
}

void main() {
  // 超支是「破了」这个终态，只能由**严格大于**触发：
  // 已用 + 已预留 恰好等于预算时，钱一分不剩但不是负数，
  // 报「已超支 ¥0.00」既没有信息量也会让用户以为算错了。
  group('超支判据边界：等于不算超支', () {
    test('已用 + 已预留 恰好等于预算 → 不算超支', () {
      final summary = _summary(usedMinor: 500000, committedMinor: 300000);

      expect(summary.occupiedMinor, 800000);
      expect(summary.isBusted, isFalse);
      expect(summary.bustedMinor, 0);
      expect(summary.availableMinor, 0);
      // 一分不剩，但「已入账的钱」确实没超预算。
      expect(summary.isUsedOverBudget, isFalse);
    });

    test('已用恰好等于预算、无预留 → 不算超支', () {
      final summary = _summary(usedMinor: 800000);

      expect(summary.isBusted, isFalse);
      expect(summary.bustedMinor, 0);
      expect(summary.availableMinor, 0);
    });

    test('多出最小货币单位才算超支', () {
      final summary = _summary(usedMinor: 500000, committedMinor: 300001);

      expect(summary.isBusted, isTrue);
      expect(summary.bustedMinor, 1);
      expect(summary.availableMinor, -1);
    });

    test('只有已用超预算时，超出金额就是已用减预算', () {
      final summary = _summary(usedMinor: 800001);

      expect(summary.isBusted, isTrue);
      expect(summary.isUsedOverBudget, isTrue);
      expect(summary.bustedMinor, 1);
      expect(summary.availableMinor, -1);
    });

    test('已用没超、是预留把额度撑破时，仍算超支但分开报来源', () {
      final summary = _summary(usedMinor: 400000, committedMinor: 400300);

      expect(summary.isBusted, isTrue);
      // 主值说「超支」，明细行要靠这个标记区分是花超了还是被预留吃穿。
      expect(summary.isUsedOverBudget, isFalse);
      expect(summary.bustedMinor, 300);
      expect(summary.availableMinor, -300);
    });

    test('预算为 0 或未设预算时不判超支', () {
      expect(_summary(totalMinor: 0).isBusted, isFalse);
      expect(_summary(totalMinor: 0).bustedMinor, 0);
      expect(_summary(hasBudget: false).isBusted, isFalse);
      expect(_summary(hasBudget: false).bustedMinor, 0);
    });
  });

  group('超支与其它口径保持一致', () {
    test('isBusted 与「还可花 < 0」等价（Hero 与记账卡共用结论）', () {
      for (final used in [0, 400000, 800000, 800001, 900000]) {
        for (final committed in [0, 300000, 800000, 900000]) {
          final summary = _summary(usedMinor: used, committedMinor: committed);
          expect(
            summary.isBusted,
            summary.availableMinor < 0,
            reason: 'used=$used committed=$committed',
          );
          expect(
            summary.bustedMinor,
            summary.availableMinor < 0 ? -summary.availableMinor : 0,
            reason: 'used=$used committed=$committed',
          );
        }
      }
    });

    test('占用进度在恰好用完时是 100%，不是被 clamp 的假值', () {
      final summary = _summary(usedMinor: 500000, committedMinor: 300000);

      expect(summary.occupiedProgress, 1.0);
      // 超支后不 clamp 成 1，环才画得出「破了」。
      final busted = _summary(usedMinor: 900000);
      expect(busted.occupiedProgress, greaterThan(1.0));
    });

    test('额度被预留占满时日均可花为 0，但不报超支', () {
      final summary = _summary(usedMinor: 0, committedMinor: 800000);

      expect(summary.dailyAllowanceMinor, 0);
      expect(summary.isBusted, isFalse);
    });
  });
}
