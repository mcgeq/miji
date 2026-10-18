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
    test('orders used leaves by usage', () {
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

    test('无使用记录时按父分类轮询补位（不再退化成目录顺序）', () {
      final leaves = buildCategoryLeaves(_catalog);

      // 目录顺序是 午餐 / 晚餐 / 交通。目录顺序的前 2 个会把「餐饮」连铺两个格子；
      // 轮询的第 1 轮是「每个父分类各取 1 个」→ 午餐（餐饮）+ 交通。
      expect(
        pickFrequentLeaves(leaves, null, count: 2).map((leaf) => leaf.name),
        ['午餐', '交通'],
      );
      // 目录顺序仍保留在轮询的轮次里：第 3 格才是餐饮的第 2 个叶子。
      expect(
        pickFrequentLeaves(leaves, null, count: 3).map((leaf) => leaf.name),
        ['午餐', '交通', '晚餐'],
      );
    });

    test('只用过 3 类时，空位按父分类轮询补而不是被同一批叶子填满', () {
      final leaves = buildCategoryLeaves(_roundRobinCatalog);
      // 只用过「日用品 d0」（昨天 5 次）→ 它排第一，其余空位交给轮询。
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {},
        subCategoryStats: {
          'p2_d0': MoneyUsageStat(
            useCount: 5,
            lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        },
      );

      final picked = pickFrequentLeaves(leaves, usage, count: 5);

      // 第 1 格用过的；后面 4 格轮询第 1 轮依次取 p0 / p1 / p2 / p3 各一个
      // （p2 的一个已被用过占走，轮到它的第 2 个叶子）。旧口径下这里会是
      // 餐饮的 s0 / s1 / s2 / s3 连着铺满，一格换不到一个新分类。
      expect(picked.map((leaf) => leaf.name).toList(), [
        '日用品0',
        '餐饮0',
        '交通0',
        '日用品1',
        '房租',
      ]);
      expect(picked.map((leaf) => leaf.categoryId).toSet(), {
        'p0',
        'p1',
        'p2',
        'p3',
      });
    });

    test('用过的叶子够填满时不再轮询补位', () {
      final leaves = buildCategoryLeaves(_roundRobinCatalog);
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {
          'p3': MoneyUsageStat(useCount: 9, lastUsedAt: null),
        },
        subCategoryStats: {
          'p0_s1': MoneyUsageStat(
            useCount: 3,
            lastUsedAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
        },
      );

      final picked = pickFrequentLeaves(leaves, usage, count: 2);

      // 两个都用过 → 直接按 B1 排（p0_s1 近 2 天 > p3 无最近时间），不掺轮询。
      expect(picked.map((leaf) => leaf.key).toList(), ['p0::p0_s1', 'p3::']);
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
    // 用相对日期：B1 是时间分层口径，写死日期会随运行日期跨档而失效。
    final usage = MoneyCategoryUsage.fromStats(
      categoryStats: const {},
      subCategoryStats: {
        'expense_food_dinner': MoneyUsageStat(
          useCount: 2,
          lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
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
      // 相对日期：B1 按「距今天数」分档，写死日期会随运行日期跨档而失效。
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {
          'expense_transport': MoneyUsageStat(useCount: 50, lastUsedAt: null),
        },
        subCategoryStats: {
          'expense_food_lunch': MoneyUsageStat(
            useCount: 1,
            lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          'expense_food_dinner': MoneyUsageStat(
            useCount: 30,
            lastUsedAt: DateTime.now().subtract(const Duration(days: 35)),
          ),
        },
      );

      final picked = pickFrequentLeaves(leaves, usage, count: 3);

      // 午餐最近用过 → 第一；晚餐其次；从未用过的交通最后。
      expect(picked.map((leaf) => leaf.name).toList(), ['午餐', '晚餐', '交通']);
    });

    test('同档内高频优先：昨天只记一次的不再压过同档高频', () {
      final leaves = buildCategoryLeaves(_catalog);
      // 午餐昨天记 1 次、晚餐 5 天前记 30 次 —— 同属「近 7 天」档。
      // 旧口径（纯最近优先）会把午餐排第一；B1 同档内看次数 → 晚餐第一。
      final usage = MoneyCategoryUsage.fromStats(
        categoryStats: const {},
        subCategoryStats: {
          'expense_food_lunch': MoneyUsageStat(
            useCount: 1,
            lastUsedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
          'expense_food_dinner': MoneyUsageStat(
            useCount: 30,
            lastUsedAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        },
      );

      final picked = pickFrequentLeaves(leaves, usage, count: 3);

      expect(picked.map((leaf) => leaf.name).toList(), ['晚餐', '午餐', '交通']);
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

      expect(heights[0], 60);
      expect(heights[1], 60);
      expect(heights[2], 60, reason: '宽度变化不该改变格高');
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
      expect(grid.height, 126, reason: '2 行 × 60dp + 6dp 行距');
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

    testWidgets('格子只留子分类名，父分类名退到读屏里', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pump(tester, width: 390);

      // 格子里只剩一行文字。原来那一行是父分类名（9.5px 浅灰小字），
      // 删掉它换来的正是 76 → 60dp。
      final tile = find
          .byWidgetPredicate((w) => w.runtimeType.toString() == '_LeafTile')
          .first;
      expect(
        find.descendant(of: tile, matching: find.byType(Text)),
        findsOneWidget,
        reason: '一个格子只该有一行文字',
      );
      // 注意：本用例的 fixture 里多个分类共用了同一批子分类名，
      // 所以「餐饮外卖0」会出现多次，只能断言存在。
      expect(find.text('餐饮外卖0'), findsWidgets, reason: '子分类名还在');
      expect(find.text('餐饮'), findsNothing, reason: '父分类名不该再出现在格子里');

      // 归属没有丢：读屏仍念「父 子」，否则只听到「外卖」不知是哪一类。
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '餐饮 餐饮外卖0',
        ),
        findsOneWidget,
      );
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
        60,
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

/// 轮询补位的 fixture：复现真实种子数据的形状——「餐饮」下叶子最多且排在
/// 目录最前面，所以任何「按目录顺序取前 N」的兜底都会连着铺一堆餐饮。
final _roundRobinCatalog = MoneyCategoryCatalog(
  categories: const [
    MoneyCategoryEntity(
      id: 'p0',
      userId: 'user-1',
      name: '餐饮',
      kind: MoneyCategoryKind.expense,
      color: '#F97316',
      icon: 'restaurant',
      isSystem: true,
    ),
    MoneyCategoryEntity(
      id: 'p1',
      userId: 'user-1',
      name: '交通',
      kind: MoneyCategoryKind.expense,
      color: '#4F7DD9',
      icon: 'directions_bus',
      isSystem: true,
    ),
    MoneyCategoryEntity(
      id: 'p2',
      userId: 'user-1',
      name: '日用品',
      kind: MoneyCategoryKind.expense,
      color: '#0F766E',
      icon: 'shopping_bag',
      isSystem: true,
    ),
    MoneyCategoryEntity(
      id: 'p3',
      userId: 'user-1',
      name: '房租',
      kind: MoneyCategoryKind.expense,
      color: '#7C3AED',
      icon: 'home',
      isSystem: true,
    ),
  ],
  subCategories: [
    for (var i = 0; i < 10; i++)
      MoneySubCategoryEntity(
        id: 'p0_s$i',
        categoryId: 'p0',
        userId: 'user-1',
        name: '餐饮$i',
        kind: MoneyCategoryKind.expense,
        color: '#FDBA74',
        icon: 'lunch_dining',
        isSystem: true,
      ),
    for (var i = 0; i < 3; i++)
      MoneySubCategoryEntity(
        id: 'p1_t$i',
        categoryId: 'p1',
        userId: 'user-1',
        name: '交通$i',
        kind: MoneyCategoryKind.expense,
        color: '#93C5FD',
        icon: 'directions_bus',
        isSystem: true,
      ),
    for (var i = 0; i < 2; i++)
      MoneySubCategoryEntity(
        id: 'p2_d$i',
        categoryId: 'p2',
        userId: 'user-1',
        name: '日用品$i',
        kind: MoneyCategoryKind.expense,
        color: '#5EEAD4',
        icon: 'shopping_bag',
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
