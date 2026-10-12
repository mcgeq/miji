import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

void main() {
  test('money cell prefers month remaining when a budget exists', () {
    final cell = buildMoneyBoardCell(
      todayExpenseMinor: 5117,
      monthRemainingMinor: 41332,
      monthNetMinor: 12000000,
      currencyCode: 'CNY',
      masked: false,
    );
    expect(cell.value, contains('413'));
    expect(cell.sub, contains('51.17'));
  });

  test('money cell falls back to net when no budget', () {
    final cell = buildMoneyBoardCell(
      todayExpenseMinor: 5117,
      monthRemainingMinor: null,
      monthNetMinor: 12000000,
      currencyCode: 'CNY',
      masked: false,
    );
    expect(cell.value, contains('12w'));
  });

  test('money cell masks amounts', () {
    final cell = buildMoneyBoardCell(
      todayExpenseMinor: 5117,
      monthRemainingMinor: 41332,
      monthNetMinor: 12000000,
      currencyCode: 'CNY',
      masked: true,
    );
    expect(cell.value.contains('413'), isFalse);
    expect(cell.sub, contains('••••'));
  });

  test('money cell shows placeholder without data', () {
    final cell = buildMoneyBoardCell(
      todayExpenseMinor: null,
      monthRemainingMinor: null,
      monthNetMinor: null,
      currencyCode: 'CNY',
      masked: false,
    );
    expect(cell.value, '—');
    expect(cell.sub, '还没有流水');
  });

  test('health cell shows period day and today logged', () {
    final cell = buildHealthBoardCell(
      hint: const HomeHealthHint(
        kind: HomeHealthHintKind.period,
        title: '经期第 3 天',
        detail: '今天已记录',
      ),
    );
    expect(cell.value, '经期第 3 天');
    expect(cell.sub, '今天已记录');
  });

  test('health cell falls back when hint is null', () {
    final cell = buildHealthBoardCell(hint: null);
    expect(cell.value, '未开启');
    expect(cell.sub, '去开启追踪');
  });

  test('action cell shows progress and next item', () {
    final cell = buildActionBoardCell(
      const TodayActionView(items: [], completedCount: 2, totalCount: 5),
    );
    expect(cell.value, '2 / 5');
  });

  test('action cell marks all done', () {
    final cell = buildActionBoardCell(
      const TodayActionView(items: [], completedCount: 5, totalCount: 5),
    );
    expect(cell.sub, contains('全部完成'));
  });

  test('action cell without tasks', () {
    final cell = buildActionBoardCell(
      const TodayActionView(items: [], completedCount: 0, totalCount: 0),
    );
    expect(cell.value, '—');
    expect(cell.sub, '今天没有待办');
  });
}
