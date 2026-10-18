import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/presentation/components/bookkeeping_panel_header.dart';

void main() {
  testWidgets('lays search, toolbar and filters out in a fixed order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: BookkeepingPanelHeader(
            searchRow: Text('SEARCH'),
            leading: Text('LEADING'),
            actions: [Icon(Icons.add)],
            filtersRow: Text('FILTERS'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchY = tester.getTopLeft(find.text('SEARCH')).dy;
    final leadingY = tester.getTopLeft(find.text('LEADING')).dy;
    final filtersY = tester.getTopLeft(find.text('FILTERS')).dy;
    // 搜索在最上，工具行其次，筛选行最后。
    expect(searchY, lessThan(leadingY));
    expect(leadingY, lessThan(filtersY));

    // leading 在左，动作在右。
    final leadingX = tester.getTopLeft(find.text('LEADING')).dx;
    final actionX = tester.getTopLeft(find.byIcon(Icons.add)).dx;
    expect(leadingX, lessThan(actionX));
  });

  testWidgets('renders only the slots it is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: BookkeepingPanelHeader(actions: [Icon(Icons.add)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('search field shows a clear button only when there is text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changed = 'seed';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookkeepingPanelSearchField(
            controller: controller,
            hintText: '搜索',
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('清除搜索'), findsNothing);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();
    expect(find.byTooltip('清除搜索'), findsOneWidget);

    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    expect(controller.text, '');
    expect(changed, '');
    expect(find.byTooltip('清除搜索'), findsNothing);
  });

  group('可展开搜索行', () {
    testWidgets('折叠时只有搜索图标，与动作按钮同排居中；点开才出现输入框', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: _rowWidth,
                child: BookkeepingPanelExpandableSearchRow(
                  controller: controller,
                  hintText: '搜索预算名称 / 备注',
                  searchTooltip: '搜索预算',
                  onChanged: (_) {},
                  actions: const [
                    Icon(Icons.filter_list_rounded),
                    Icon(Icons.add_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 默认只有一枚搜索图标：那一行输入框不再常驻占位。
      expect(find.byType(TextField), findsNothing);
      final searchButton = tester.getRect(find.byTooltip('搜索预算'));
      expect(searchButton.width, 40);

      // 三枚按钮作为一组水平居中：左右留白相等。
      final row = tester.getRect(
        find.byType(BookkeepingPanelExpandableSearchRow),
      );
      final lastAction = tester.getRect(find.byIcon(Icons.add_rounded));
      expect(
        searchButton.left - row.left,
        closeTo(row.right - lastAction.right, 0.5),
      );

      await tester.tap(find.byTooltip('搜索预算'));
      // 第一帧只是把输入框换进来（ticker 在这一帧才起算），再推 150ms 才是半路。
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final midway = tester.getRect(find.byType(TextField));
      expect(midway.width, greaterThan(40));
      expect(midway.width, lessThan(_rowWidth));

      await tester.pumpAndSettle();

      // 展开完成：输入框铺满左侧，动作按钮被推到最右，间距仍是 8。
      final field = tester.getRect(find.byType(TextField));
      expect(field.left, closeTo(row.left, 0.5));
      expect(
        tester.getRect(find.byIcon(Icons.filter_list_rounded)).left -
            field.right,
        closeTo(8, 0.5),
      );
      expect(
        tester.getRect(find.byIcon(Icons.add_rounded)).right,
        closeTo(row.right, 0.5),
        reason: '展开后动作按钮要贴最右',
      );
    });

    testWidgets('再点一次同一处放大镜就收起，关键词保留且图标变实心', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: _rowWidth,
                child: BookkeepingPanelExpandableSearchRow(
                  controller: controller,
                  hintText: '搜索预算名称 / 备注',
                  searchTooltip: '搜索预算',
                  onChanged: (_) {},
                  actions: const [Icon(Icons.add_rounded)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('搜索预算'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '餐饮');
      await tester.pumpAndSettle();

      // 展开态的放大镜就在折叠态那枚图标的同一位置：点它收起，不用先清空再点空处。
      await tester.tap(find.byTooltip('收起搜索'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(controller.text, '餐饮', reason: '收起不等于清空搜索条件');

      // 关键词还在生效，但收起后整页只剩这枚图标能交代 → 用实心（与「筛选」已生效同款）。
      final button = tester.widget<AppIconActionButton>(
        find.byType(AppIconActionButton),
      );
      expect(button.variant, AppIconActionVariant.filled);

      // 再点开还是原来那个词，不是被清空后的空框。
      await tester.tap(find.byTooltip('搜索预算'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, '餐饮');
    });

    testWidgets('失焦且没填内容就收回；有内容时保留', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: _rowWidth,
                child: BookkeepingPanelExpandableSearchRow(
                  controller: controller,
                  hintText: '搜索预算名称 / 备注',
                  searchTooltip: '搜索预算',
                  onChanged: (_) {},
                  actions: const [Icon(Icons.add_rounded)],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 空着失焦 → 收回图标态（否则这一行会一直占着高度）。
      await tester.tap(find.byTooltip('搜索预算'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);

      // 有内容时失焦不收回：收起来会看不见搜索词，可筛选其实还在生效。
      await tester.tap(find.byTooltip('搜索预算'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '餐饮');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(controller.text, '餐饮');
    });
  });
}

/// 组件级用例里给这一行一个固定宽度，几何断言才算得准（与真实面板同量级）。
const _rowWidth = 320.0;
