import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_leaf_selector.dart';

/// 记账表单扁平化到叶子：点一次直接选完，父分类由叶子反推。
void main() {
  group('buildCategoryLeaves', () {
    test('flattens sub categories and keeps parent-only categories', () {
      final leaves = buildCategoryLeaves(_catalog);

      // 餐饮 有子分类 → 叶子是 午餐/晚餐；交通 没有子分类 → 自己就是叶子。
      expect(leaves.map((leaf) => leaf.name).toList(), ['午餐', '晚餐', '交通']);
      expect(leaves[0].categoryId, 'expense_food');
      expect(leaves[0].subCategoryId, 'expense_food_lunch');
      expect(leaves[0].isChild, isTrue);
      expect(leaves[2].categoryId, 'expense_transport');
      expect(leaves[2].subCategoryId, isNull);
      expect(leaves[2].isChild, isFalse);
    });

    test('skips deleted categories and sub categories', () {
      final leaves = buildCategoryLeaves(_catalogWithDeleted);

      expect(leaves.map((leaf) => leaf.name), ['午餐']);
    });

    test('fixedCategoryId only returns that category leaves', () {
      final leaves = buildCategoryLeaves(
        _catalog,
        fixedCategoryId: 'expense_transport',
      );

      expect(leaves.length, 1);
      expect(leaves.single.name, '交通');
    });
  });

  group('pickFrequentLeaves', () {
    test('orders by usage and pads with catalog order', () {
      final leaves = buildCategoryLeaves(_catalog);
      // 父分类自己作叶子 → 用量记在 categoryStats；子分类记在 subCategoryStats。
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {'expense_transport': MoneyUsageStat(useCount: 9)},
        subCategoryStats: const {
          'expense_food_lunch': MoneyUsageStat(useCount: 1),
        },
      );

      final picked = pickFrequentLeaves(leaves, usage, count: 2);

      expect(picked.first.name, '交通');
      expect(picked.map((leaf) => leaf.name), contains('午餐'));
    });

    test('falls back to catalog order without usage', () {
      final leaves = buildCategoryLeaves(_catalog);

      expect(
        pickFrequentLeaves(leaves, null, count: 2).map((leaf) => leaf.name),
        ['午餐', '晚餐'],
      );
    });
  });

  testWidgets('tapping a leaf reports the derived parent category', (
    tester,
  ) async {
    String? pickedCategoryId;
    String? pickedSubCategoryId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryLeafSelector(
              catalog: _catalog,
              selectedCategoryId: null,
              selectedSubCategoryId: null,
              onChanged: (categoryId, subCategoryId) {
                pickedCategoryId = categoryId;
                pickedSubCategoryId = subCategoryId;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 一次点击就选完「餐饮·午餐」（父名与子名同一行，省掉一行 13dp）。
    await tester.tap(find.text('午餐'));
    await tester.pumpAndSettle();

    expect(pickedCategoryId, 'expense_food');
    expect(pickedSubCategoryId, 'expense_food_lunch');
  });

  testWidgets('parent-only leaf selects the category without a sub category', (
    tester,
  ) async {
    String? pickedCategoryId;
    String? pickedSubCategoryId;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryLeafSelector(
              catalog: _catalog,
              selectedCategoryId: null,
              selectedSubCategoryId: null,
              onChanged: (categoryId, subCategoryId) {
                pickedCategoryId = categoryId;
                pickedSubCategoryId = subCategoryId;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('交通'));
    await tester.pumpAndSettle();

    expect(pickedCategoryId, 'expense_transport');
    expect(pickedSubCategoryId, isNull);
  });

  testWidgets('sheet shows leaves in the same 常用 order as the grid', (
    tester,
  ) async {
    // 晚餐最近用过 → 网格里第一个；打开面板后它也应该在「餐饮」分组的最前面，
    // 而不是按目录顺序或另一套口径。
    final usage = MoneyCategoryUsage.fromStats(
      categoryStats: const {},
      subCategoryStats: {
        'expense_food_dinner': MoneyUsageStat(
          useCount: 2,
          lastUsedAt: DateTime(2026, 9, 21),
        ),
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryLeafSelector(
              catalog: _catalog,
              usage: usage,
              selectedCategoryId: null,
              selectedSubCategoryId: null,
              onChanged: (categoryId, subCategoryId) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 网格里晚餐排在午餐前面。
    expect(
      tester.getTopLeft(find.text('晚餐').first).dx,
      lessThan(tester.getTopLeft(find.text('午餐').first).dx),
    );

    await tester.tap(find.textContaining('全部分类'));
    await tester.pumpAndSettle();

    // 面板里同样晚餐在前。
    expect(
      tester.getTopLeft(find.text('晚餐').last).dy,
      lessThan(tester.getTopLeft(find.text('午餐').last).dy),
    );
  });

  testWidgets('all-categories sheet groups by parent and supports search', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategoryLeafSelector(
              catalog: _catalog,
              selectedCategoryId: null,
              selectedSubCategoryId: null,
              onChanged: (categoryId, subCategoryId) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('全部分类'));
    await tester.pumpAndSettle();

    // 分组标题 + 叶子都在（「晚餐」在常用格子和面板里各一个）。
    expect(find.text('餐饮'), findsWidgets);
    expect(find.text('晚餐'), findsWidgets);

    // 搜索也命中父分类名。
    await tester.enterText(find.byType(TextField), '交通');
    await tester.pumpAndSettle();
    expect(find.text('交通'), findsWidgets);
  });

  group('统一「常用」口径', () {
    test('最近使用优先于历史次数（月初不再归零）', () {
      final leaves = buildCategoryLeaves(_catalog);
      // 午餐：本月没用过（窗口口径会归零）但昨天用过 → 仍应排前。
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {
          'expense_transport': MoneyUsageStat(useCount: 50, lastUsedAt: null),
        },
        subCategoryStats: {
          'expense_food_lunch': MoneyUsageStat(
            useCount: 1,
            lastUsedAt: DateTime(2026, 9, 21),
          ),
          'expense_food_dinner': MoneyUsageStat(
            useCount: 30,
            lastUsedAt: DateTime(2026, 9, 10),
          ),
        },
      );

      final picked = pickFrequentLeaves(leaves, usage, count: 3);

      // 午餐最近用过 → 第一；晚餐其次；从未用过的交通最后。
      expect(picked.map((leaf) => leaf.name).toList(), ['午餐', '晚餐', '交通']);
    });

    test('从未用过的叶子退回目录顺序，且排在用过的之后', () {
      final leaves = buildCategoryLeaves(_catalog);
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {'expense_transport': MoneyUsageStat(useCount: 1)},
        subCategoryStats: const {},
      );

      final picked = pickFrequentLeaves(leaves, usage, count: 3);

      expect(picked.first.name, '交通');
      // 其余两个保持目录顺序：午餐 → 晚餐。
      expect(picked.map((leaf) => leaf.name).toList(), ['交通', '午餐', '晚餐']);
    });

    test('sortLeavesByUsage 与 pickFrequentLeaves 顺序一致（同一比较器）', () {
      final leaves = buildCategoryLeaves(_catalog);
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {'expense_transport': MoneyUsageStat(useCount: 9)},
        subCategoryStats: const {
          'expense_food_dinner': MoneyUsageStat(useCount: 3),
        },
      );

      final sorted = sortLeavesByUsage(leaves, usage);
      final frequent = pickFrequentLeaves(leaves, usage, count: 3);

      expect(
        frequent.map((leaf) => leaf.key),
        sorted.take(3).map((leaf) => leaf.key),
      );
    });
  });

  testWidgets('keeps the search field and results above the keyboard', (
    tester,
  ) async {
    const screenHeight = 844.0;
    const keyboardInset = 320.0;
    tester.view.physicalSize = const Size(390 * 3, screenHeight * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // 模拟系统键盘弹起。
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: const EdgeInsets.only(bottom: keyboardInset)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showCategoryLeafSheet(
                  context: context,
                  leaves: buildCategoryLeaves(_catalog),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    final keyboardTop = screenHeight - keyboardInset;

    // 搜索框整体在键盘上方。
    final searchField = find.byType(TextField).first;
    expect(tester.getRect(searchField).bottom, lessThanOrEqualTo(keyboardTop));

    // 搜索结果（叶子行）也在键盘上方，没有被盖住。
    final dinnerRow = find.text('晚餐').last;
    expect(tester.getRect(dinnerRow).bottom, lessThanOrEqualTo(keyboardTop));

    // 面板底部同样不越过键盘。
    final sheetBottom = tester.getRect(find.byType(Material).last).bottom;
    expect(sheetBottom, lessThanOrEqualTo(keyboardTop));
  });

  group('分类格紧凑化', () {
    Future<void> pump(
      WidgetTester tester, {
      required double width,
      int subCount = 2,
      double textScale = 1,
      int frequentCount = 8,
    }) async {
      final catalog = MoneyCategoryCatalog(
        categories: [
          for (var i = 0; i < 10; i++)
            MoneyCategoryEntity(
              id: 'c$i',
              userId: 'user-1',
              name: i == 0 ? '餐饮' : '信用卡还款$i',
              kind: MoneyCategoryKind.expense,
              color: '#F97316',
              icon: 'restaurant',
              isSystem: true,
            ),
        ],
        subCategories: [
          for (var i = 0; i < 10; i++)
            for (var j = 0; j < subCount; j++)
              MoneySubCategoryEntity(
                id: 'c${i}_s$j',
                categoryId: 'c$i',
                userId: 'user-1',
                name: '餐饮外卖$j',
                kind: MoneyCategoryKind.expense,
                color: '#FDBA74',
                icon: 'label',
                isSystem: true,
              ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: width,
                  child: CategoryLeafSelector(
                    key: UniqueKey(),
                    catalog: catalog,
                    selectedCategoryId: null,
                    selectedSubCategoryId: null,
                    usage: const MoneyCategoryUsage.empty(),
                    frequentCount: frequentCount,
                    onChanged: (categoryId, subCategoryId) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// 回归：格子高度原来由 childAspectRatio 按**宽度**反推 ——
    /// 手机 79.5dp、宽弹窗能到 120dp+，而格子里只有图标 + 一行文字。
    testWidgets('格子高度不再随可用宽度变化', (tester) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final heights = <double>[];
      for (final width in [390.0, 560.0, 820.0]) {
        await pump(tester, width: width);
        heights.add(
          tester
              .getSize(
                find
                    .byWidgetPredicate(
                      (w) => w.runtimeType.toString() == '_LeafTile',
                    )
                    .first,
              )
              .height,
        );
      }

      expect(heights[0], 76);
      expect(heights[1], 76);
      expect(heights[2], 76, reason: '宽度变化不该改变格高');
    });

    testWidgets('4 列 × 8 个常用位正好两行', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester, width: 390);
      final tiles = find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == '_LeafTile',
      );
      expect(tiles, findsNWidgets(8));

      final grid = tester.getSize(find.byType(GridView));
      expect(grid.height, 158, reason: '2 行 × 76dp + 6dp 行距');
      // 一行的前 4 个在同一个 y 上。
      expect(
        tester.getTopLeft(tiles.at(0)).dy,
        tester.getTopLeft(tiles.at(3)).dy,
      );
      expect(
        tester.getTopLeft(tiles.at(4)).dy,
        greaterThan(tester.getTopLeft(tiles.at(0)).dy),
      );
    });

    testWidgets('格子两行：第一行子分类、第二行父分类', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester, width: 390);

      // 第一行是子分类名，第二行是父分类名（浅色小字）。
      final sub = tester.getRect(find.text('餐饮外卖0').first);
      final parent = tester.getRect(find.text('餐饮').first);
      expect(sub.top, lessThan(parent.top));
      expect(sub.center.dx, closeTo(parent.center.dx, 2), reason: '两行在同一列内居中');
      // 不再出现合并写法。
      expect(find.text('餐饮·餐饮外卖0'), findsNothing);
    });

    testWidgets('长名字与放大字体都不会溢出', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester, width: 390);
      expect(tester.takeException(), isNull);

      await pump(tester, width: 390, textScale: 1.5);
      expect(tester.takeException(), isNull, reason: '字体放大时 FittedBox 整体缩小');
    });

    testWidgets('转账表单只要 3 个常用格时只占一行', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester, width: 390, frequentCount: 3);
      expect(
        tester.getSize(find.byType(GridView)).height,
        76,
        reason: '3 个格子在 4 列布局下是一行',
      );
    });
  });
}

const _catalog = MoneyCategoryCatalog(
  categories: [
    MoneyCategoryEntity(
      id: 'expense_food',
      userId: 'user-1',
      name: '餐饮',
      kind: MoneyCategoryKind.expense,
      color: '#F97316',
      icon: 'restaurant',
      isSystem: true,
    ),
    MoneyCategoryEntity(
      id: 'expense_transport',
      userId: 'user-1',
      name: '交通',
      kind: MoneyCategoryKind.expense,
      color: '#4F7DD9',
      icon: 'directions_bus',
      isSystem: true,
    ),
  ],
  subCategories: [
    MoneySubCategoryEntity(
      id: 'expense_food_lunch',
      categoryId: 'expense_food',
      userId: 'user-1',
      name: '午餐',
      kind: MoneyCategoryKind.expense,
      color: '#FDBA74',
      icon: 'lunch_dining',
      isSystem: true,
    ),
    MoneySubCategoryEntity(
      id: 'expense_food_dinner',
      categoryId: 'expense_food',
      userId: 'user-1',
      name: '晚餐',
      kind: MoneyCategoryKind.expense,
      color: '#FB923C',
      icon: 'dinner_dining',
      isSystem: true,
    ),
  ],
);

const _catalogWithDeleted = MoneyCategoryCatalog(
  categories: [
    MoneyCategoryEntity(
      id: 'expense_food',
      userId: 'user-1',
      name: '餐饮',
      kind: MoneyCategoryKind.expense,
      color: '#F97316',
      icon: 'restaurant',
      isSystem: true,
    ),
    MoneyCategoryEntity(
      id: 'expense_old',
      userId: 'user-1',
      name: '旧分类',
      kind: MoneyCategoryKind.expense,
      color: '#475569',
      icon: 'category',
      isSystem: false,
      isDeleted: true,
    ),
  ],
  subCategories: [
    MoneySubCategoryEntity(
      id: 'expense_food_lunch',
      categoryId: 'expense_food',
      userId: 'user-1',
      name: '午餐',
      kind: MoneyCategoryKind.expense,
      color: '#FDBA74',
      icon: 'lunch_dining',
      isSystem: true,
    ),
    MoneySubCategoryEntity(
      id: 'expense_food_old',
      categoryId: 'expense_food',
      userId: 'user-1',
      name: '旧子分类',
      kind: MoneyCategoryKind.expense,
      color: '#FDBA74',
      icon: 'label',
      isSystem: false,
      isDeleted: true,
    ),
  ],
);
