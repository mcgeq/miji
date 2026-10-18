import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/life_energy/domain/life_energy_prefs.dart';

/// 「上次停在哪」这一列是 JSON，坏数据不许把面板打不开。
void main() {
  test('往返：写进去什么读出来什么', () {
    const prefs = LifeEnergyPrefs(
      tab: 'wishlist',
      sort: 'cost',
      payrollYear: 2025,
    );
    final parsed = LifeEnergyPrefs.fromJsonString(prefs.encode());
    expect(parsed.tab, 'wishlist');
    expect(parsed.sort, 'cost');
    expect(parsed.payrollYear, 2025);
  });

  test('空值 / 坏 JSON / 类型不对都退回默认，不抛', () {
    expect(LifeEnergyPrefs.fromJsonString(null).tab, isNull);
    expect(LifeEnergyPrefs.fromJsonString('  ').sort, isNull);
    expect(LifeEnergyPrefs.fromJsonString('{不是 json').tab, isNull);
    expect(LifeEnergyPrefs.fromJsonString('[1,2,3]').tab, isNull);
    // 年份必须是像样的数字：字符串、0、5000 都不认。
    expect(
      LifeEnergyPrefs.fromJsonString('{"payrollYear": "2025"}').payrollYear,
      isNull,
    );
    expect(
      LifeEnergyPrefs.fromJsonString('{"payrollYear": 0}').payrollYear,
      isNull,
    );
    expect(
      LifeEnergyPrefs.fromJsonString('{"payrollYear": 5000}').payrollYear,
      isNull,
    );
    expect(
      LifeEnergyPrefs.fromJsonString('{"payrollYear": 2025.0}').payrollYear,
      2025,
    );
  });

  test('copyWith 只改给定的一项，其余保持', () {
    const base = LifeEnergyPrefs(
      tab: 'wishlist',
      sort: 'cost',
      payrollYear: 2025,
    );
    expect(base.copyWith(sort: 'recent').tab, 'wishlist');
    expect(base.copyWith(sort: 'recent').payrollYear, 2025);
    expect(base.copyWith(clearPayrollYear: true).payrollYear, isNull);
  });

  test('只有非空项才写进 JSON，读回来不会把 null 当成值', () {
    const prefs = LifeEnergyPrefs(sort: 'dueSoon');
    expect(prefs.toJson().keys, ['sort']);
    expect(LifeEnergyPrefs.fromJsonString(prefs.encode()).payrollYear, isNull);
  });
}
