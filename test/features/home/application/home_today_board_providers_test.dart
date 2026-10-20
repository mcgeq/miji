import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

void main() {
  group('buildMoneyBoardCell', () {
    test('主值是有预算时的「还可花」，今日支出降为带名称的次要指标', () {
      final cell = buildMoneyBoardCell(
        todayExpenseMinor: 5117,
        monthRemainingMinor: 41332,
        monthNetMinor: 12000000,
        currencyCode: 'CNY',
        masked: false,
      );
      expect(cell.title, '记账');
      expect(cell.value, contains('413'));
      expect(cell.label, '本月还可花');
      expect(cell.noteLabel, '今日支出');
      expect(cell.noteValue, contains('51.17'));
      expect(cell.valueAlert, isFalse);
    });

    test('额度刚好用完（还可花 0）不算超支，不进告警态', () {
      // 已用 + 已预留 == 预算 → 还可花为 0。这与 Hero 的 isBusted 是同一个
      // 判据（availableMinor < 0），边界上必须是「还可花 ¥0」而非「已超支 ¥0」。
      final cell = buildMoneyBoardCell(
        todayExpenseMinor: 5117,
        monthRemainingMinor: 0,
        monthNetMinor: 12000000,
        currencyCode: 'CNY',
        masked: false,
      );
      expect(cell.label, '本月还可花');
      expect(cell.valueAlert, isFalse);
      expect(cell.value, contains('0.00'));
      expect(cell.value, isNot(contains('-')));
    });

    test('超支时把主值标成告警并改写口径标签', () {
      final cell = buildMoneyBoardCell(
        todayExpenseMinor: 5117,
        monthRemainingMinor: -4200,
        monthNetMinor: 12000000,
        currencyCode: 'CNY',
        masked: false,
      );
      expect(cell.label, '本月已超支');
      expect(cell.valueAlert, isTrue);
      // 超支金额按正数展示：`-¥42.00` 配「本月已超支」读起来像「超支了负四十二」。
      expect(cell.value, contains('42'));
      expect(cell.value, isNot(contains('-')));
    });

    test('没有预算时退化为本月结余', () {
      final cell = buildMoneyBoardCell(
        todayExpenseMinor: 5117,
        monthRemainingMinor: null,
        monthNetMinor: 12000000,
        currencyCode: 'CNY',
        masked: false,
      );
      expect(cell.value, contains('12w'));
      expect(cell.label, '本月结余');
    });

    test('隐藏金额时主值与次要指标一起打码', () {
      final cell = buildMoneyBoardCell(
        todayExpenseMinor: 5117,
        monthRemainingMinor: 41332,
        monthNetMinor: 12000000,
        currencyCode: 'CNY',
        masked: true,
      );
      expect(cell.value.contains('413'), isFalse);
      expect(cell.noteValue, '••••');
    });

    test('完全没有数据时只留一句说明，不留下空标签', () {
      final cell = buildMoneyBoardCell(
        todayExpenseMinor: null,
        monthRemainingMinor: null,
        monthNetMinor: null,
        currencyCode: 'CNY',
        masked: false,
      );
      expect(cell.value, '—');
      expect(cell.noteLabel, '还没有流水');
      expect(cell.noteValue, isNull);
    });
  });

  group('buildHealthBoardCell', () {
    test('用短主值 + 口径标签，而不是整句标题', () {
      final cell = buildHealthBoardCell(
        hint: const HomeHealthHint(
          kind: HomeHealthHintKind.period,
          title: '经期第 3 天',
          detail: '今天已记录',
          digest: (value: '第 3 天', label: '经期', note: '今天已记录'),
        ),
      );
      expect(cell.title, '健康');
      expect(cell.value, '第 3 天');
      expect(cell.label, '经期');
      expect(cell.noteLabel, '今天已记录');
    });

    test('没有提示时回落到「未开启」', () {
      final cell = buildHealthBoardCell(hint: null);
      expect(cell.value, '未开启');
      expect(cell.label, '周期追踪');
      expect(cell.noteLabel, '点这里开启');
    });
  });

  group('buildActionBoardCell', () {
    test('主值是完成度，下一件降为次要指标', () {
      final cell = buildActionBoardCell(
        const TodayActionView(items: [], completedCount: 2, totalCount: 5),
      );
      expect(cell.title, '计划');
      expect(cell.value, '2 / 5');
      expect(cell.label, '今日已完成');
      expect(cell.noteLabel, '下一件');
    });

    test('全部完成时不再渲染下一件', () {
      final cell = buildActionBoardCell(
        const TodayActionView(items: [], completedCount: 5, totalCount: 5),
      );
      expect(cell.noteLabel, contains('全部完成'));
      expect(cell.noteValue, isNull);
    });

    test('没有待办时给出占位', () {
      final cell = buildActionBoardCell(
        const TodayActionView(items: [], completedCount: 0, totalCount: 0),
      );
      expect(cell.value, '—');
      expect(cell.noteLabel, '今天没有待办');
    });
  });
}
