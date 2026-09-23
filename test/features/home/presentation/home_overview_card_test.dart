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

  int? indexOfStack(WidgetTester tester) {
    return tester.widget<IndexedStack>(find.byType(IndexedStack)).index;
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
    expect(indexOfStack(tester), HomeOverviewTab.budget.index);
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
    expect(indexOfStack(tester), HomeOverviewTab.trend.index);

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(indexOfStack(tester), HomeOverviewTab.calendar.index);

    await tester.tap(find.text('本月预算'));
    await tester.pumpAndSettle();
    expect(indexOfStack(tester), HomeOverviewTab.budget.index);
  });

  testWidgets('高度锁在最高的那个视图上，切 tab 不跳', (tester) async {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        host(
          HomeOverviewCard(
            budgetView: const SizedBox(height: 100, child: Text('预算视图')),
            trendView: const SizedBox(height: 100, child: Text('趋势视图')),
            calendarView: const SizedBox(height: 160, child: Text('日历视图')),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pump(tester);
    final atBudget = tester.getSize(find.byType(IndexedStack)).height;
    expect(atBudget, 160, reason: '最高的视图（日历 160）决定整卡高度');

    await tester.tap(find.text('日历'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(IndexedStack)).height, atBudget);

    await tester.tap(find.text('支出趋势'));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(IndexedStack)).height, atBudget);
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
