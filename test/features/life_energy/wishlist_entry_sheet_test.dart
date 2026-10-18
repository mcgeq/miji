import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';
import 'package:miji/features/life_energy/presentation/wishlist_entry_sheet.dart';
import 'package:miji/features/life_energy/providers/life_energy_providers.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';

/// 加一件想买的东西时，代价必须在**还没买**的时候出现：
/// 单件值多少天，以及「加进去之后整张清单要干多久」。
///
/// 面板上那张「换算器」删掉之后，这两个数字就成了唯一入口 —— 所以这两条
/// 用例钉住的是「换算只发生在清单里」这件事。
Future<void> _pumpSheet(
  WidgetTester tester, {
  WorkProfile? profile,
  List<WishlistEntry> wishlist = const <WishlistEntry>[],
}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentWorkProfileProvider.overrideWith(
          (ref) => AsyncData<WorkProfile?>(profile),
        ),
        currentWishlistProvider.overrideWith(
          (ref) => Stream<List<WishlistEntry>>.value(wishlist),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showWishlistEntrySheet(context),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

/// 月到手 12,000 · 22 天 · 8 小时 · 通勤 70 分 · 常规加班 12h · 开销 1,700
/// → 真实时薪 ¥48.2，一个工作日 9.71 小时。
const _profile = WorkProfile(
  userId: 'user-1',
  payAmountMinor: 1200000,
  workDaysPerMonth: 22,
  workMinutesPerDay: 480,
  commuteMinutesPerDay: 70,
  overtimeMinutesPerMonth: 720,
  costTransportMinor: 170000,
);

WishlistEntry _entry(String id, int amountMinor) => WishlistEntry(
  id: id,
  userId: 'user-1',
  title: '已有的一件',
  targetAmountMinor: amountMinor,
  desire: WishDesireLevel.want,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 1),
);

void main() {
  testWidgets('填价格的时候当场给出它值几小时 / 几个工作日', (tester) async {
    await _pumpSheet(tester, profile: _profile);

    await tester.enterText(
      find.descendant(
        of: find.byType(AppAmountField),
        matching: find.byType(TextField),
      ),
      '1299',
    );
    await tester.pumpAndSettle();

    // 1,299 ÷ 48.2 ≈ 26.9 小时 ≈ 2.8 个工作日。
    expect(find.textContaining('26.9 小时'), findsOneWidget);
    expect(find.textContaining('2.8 个工作日'), findsWidgets);
    // 备注：详情页要复述的那句「为什么想买」，表单得先给个入口。
    expect(find.text('为什么想买'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清单里已有别的，加之前就告诉你「一起要干多久」', (tester) async {
    await _pumpSheet(
      tester,
      profile: _profile,
      wishlist: [_entry('a', 300000), _entry('b', 200000)],
    );

    // 一件都没填金额时不显示合计：加进去的是 0 天，说了等于没说。
    expect(find.textContaining('加进去之后'), findsNothing);

    await tester.enterText(
      find.descendant(
        of: find.byType(AppAmountField),
        matching: find.byType(TextField),
      ),
      '1299',
    );
    await tester.pumpAndSettle();

    // 已有一件 3,000 + 一件 2,000 = 5,000 ÷ 48.2 ≈ 103.7 小时 ≈ 10.7 天；
    // 再加 1,299（2.8 天）→ 13.5 天。
    expect(find.textContaining('加进去之后 · 3 件 · 全买下来 13.5 个工作日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('清单是空的就不说「加进去之后」——总数就是这一件本身', (tester) async {
    await _pumpSheet(tester, profile: _profile);

    await tester.enterText(
      find.descendant(
        of: find.byType(AppAmountField),
        matching: find.byType(TextField),
      ),
      '1299',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('加进去之后'), findsNothing);
    expect(find.textContaining('2.8 个工作日'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
