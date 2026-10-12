import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/presentation/home_pager.dart';

/// 横向分页要能**绕回**：滑到最后一页继续滑回第一页，反向同理。
/// 否则用户滑到底会有「到头了」的断点，想回第一页只能一路倒着滑回去。
void main() {
  Widget host({bool tabs = true, int pageCount = 4}) {
    final labels = ['概览', '记账', '健康', '行动'];
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: HomePager(
          tabs: tabs,
          pages: [
            for (var i = 0; i < pageCount; i++)
              HomePagerPage(
                label: labels[i % labels.length],
                children: [Text('page-${labels[i % labels.length]}')],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> swipeToNext(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  Future<void> swipeToPrevious(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
  }

  testWidgets('从最后一页继续右滑绕回第一页', (tester) async {
    await tester.pumpWidget(host());

    expect(find.text('page-概览'), findsOneWidget);

    await swipeToNext(tester);
    expect(find.text('page-记账'), findsOneWidget);

    await swipeToNext(tester);
    expect(find.text('page-健康'), findsOneWidget);

    await swipeToNext(tester);
    expect(find.text('page-行动'), findsOneWidget);

    // 关键：最后一页再右滑一次，回到第一页而不是停在原地。
    await swipeToNext(tester);
    expect(find.text('page-概览'), findsOneWidget);
    expect(find.text('page-行动'), findsNothing);

    // 而且可以继续绕第二圈。
    await swipeToNext(tester);
    expect(find.text('page-记账'), findsOneWidget);
  });

  testWidgets('从第一页左滑绕回最后一页', (tester) async {
    await tester.pumpWidget(host());
    expect(find.text('page-概览'), findsOneWidget);

    await swipeToPrevious(tester);
    expect(find.text('page-行动'), findsOneWidget);
    expect(find.text('page-概览'), findsNothing);

    // 反向也能绕圈：最后一页再左滑 → 健康。
    await swipeToPrevious(tester);
    expect(find.text('page-健康'), findsOneWidget);
  });

  testWidgets('页签跳页走最短路径，不会横穿中间页', (tester) async {
    await tester.pumpWidget(host());

    // 「概览」→「行动」在循环里只隔一格（往回退），
    // 动画途中不应该扫过「记账」「健康」的内容。
    await tester.tap(find.byKey(const ValueKey('home-pager-tab-行动')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('page-记账'), findsNothing);
    expect(find.text('page-健康'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('page-行动'), findsOneWidget);

    // 跳回概览同样是相邻一格。
    await tester.tap(find.byKey(const ValueKey('home-pager-tab-概览')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('page-健康'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('page-概览'), findsOneWidget);
  });

  testWidgets('关闭顶部标签时循环依旧生效', (tester) async {
    await tester.pumpWidget(host(tabs: false));

    for (var i = 0; i < 4; i++) {
      await swipeToNext(tester);
    }
    expect(find.text('page-概览'), findsOneWidget);

    await swipeToPrevious(tester);
    expect(find.text('page-行动'), findsOneWidget);
  });

  testWidgets('只有一页时不循环，滑动保持在同一页', (tester) async {
    await tester.pumpWidget(host(pageCount: 1));
    expect(find.text('page-概览'), findsOneWidget);

    await swipeToNext(tester);
    expect(find.text('page-概览'), findsOneWidget);

    await swipeToPrevious(tester);
    expect(find.text('page-概览'), findsOneWidget);
  });
}
