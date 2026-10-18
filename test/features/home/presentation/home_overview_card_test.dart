import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/presentation/home_overview_card.dart';

/// 三视图合并卡的行为约束：
/// 默认停在「本月预算」、切 tab 不丢子视图状态、整卡高度按最高的视图锁住
/// （否则切 tab 会让下面所有内容上下跳）。
void main() {
  Widget host(Widget child) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 360, child: child)),
      ),
    );
  }

  /// Offstage 的子节点不绘制 → 默认的 find（skipOffstage: true）只找得到当前视图。
  void expectActive(String label) {
    expect(find.text(label), findsOneWidget);
  }

  testWidgets('默认显示本月预算，并且三个 tab 都在', (tester) async {
    await tester.pumpWidget(
      host(
        HomeOverviewCard(
          budgetView: const SizedBox(height: 100, child: Text('预算视图')),
          trendView: const SizedBox(height: 100, child: Text('趋势视图')),
          calendarView: const SizedBox(height: 100, child: Text('日历视图')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月预算'), findsOneWidget);
    expect(find.text('支出趋势'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expectActive('预算视图');
    expect(find.text('趋势视图'), findsNothing, reason: '未选中的视图处于 offstage');
    expect(find.text('日历视图', skipOffstage: false), findsOneWidget);
  });

  testWidgets('点 tab 切到趋势与日历', (tester) async {
    await tester.pumpWidget(
      host(
        HomeOverviewCard(
          budgetView: const SizedBox(height: 100, child: Text('预算视图')),
          trendView: const SizedBox(height: 100, child: Text('趋势视图')),
          calendarView: const SizedBox(height: 100, child: Text('日历视图')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('支出趋势'));
    await tester.pumpAndSettle();
    expectActive('趋势视图');

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expectActive('日历视图');

    await tester.tap(find.text('本月预算'));
    await tester.pumpAndSettle();
    expectActive('预算视图');
  });

  testWidgets('卡片高度跟着当前视图走，不留空白（回归：卡底曾锁在最高视图）', (tester) async {
    // 回归：原来用 IndexedStack，整卡高度被锁在最高的视图（日历 338dp）上，
    // 于是在「本月预算」（288dp）里卡底空出 50dp、遮罩后空出 70dp ——
    // 用户看到的就是「卡片离下面的内容间距太大」。
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          HomeOverviewCard(
            budgetView: const SizedBox(height: 100, child: Text('预算视图')),
            trendView: const SizedBox(height: 60, child: Text('趋势视图')),
            calendarView: const SizedBox(height: 160, child: Text('日历视图')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(tester);
    // 默认停在预算视图（100dp）→ 整卡高度约等于它，而不是最高的 160dp。
    expectActive('预算视图');
    final budgetHeight = tester.getSize(find.byType(HomeOverviewCard)).height;
    expect(budgetHeight, lessThan(160), reason: '整卡不该被最高的日历视图撑高');

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(HomeOverviewCard)).height,
      greaterThan(budgetHeight),
      reason: '切到更高的视图时卡片长高',
    );
  });

  testWidgets('切走再切回来，子视图状态还在', (tester) async {
    await tester.pumpWidget(
      host(
        HomeOverviewCard(
          budgetView: const _CounterView(label: '预算视图'),
          trendView: const SizedBox(height: 100, child: Text('趋势视图')),
          calendarView: const SizedBox(height: 100, child: Text('日历视图')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('预算视图 +1'));
    await tester.pumpAndSettle();
    expect(find.text('计数 1'), findsOneWidget);

    await tester.tap(find.text('支出趋势'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('本月预算'));
    await tester.pumpAndSettle();

    expect(find.text('计数 1'), findsOneWidget, reason: 'IndexedStack 保留子树状态');
  });
}

class _CounterView extends StatefulWidget {
  const _CounterView({required this.label});

  final String label;

  @override
  State<_CounterView> createState() => _CounterViewState();
}

class _CounterViewState extends State<_CounterView> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Column(
        children: [
          Text('计数 $_count'),
          TextButton(
            onPressed: () => setState(() => _count += 1),
            child: Text('${widget.label} +1'),
          ),
        ],
      ),
    );
  }
}
