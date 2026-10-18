import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/bookkeeping_page.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_card.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 面板入口（二级路由）在方案 A 之后落在哪里：
///
/// - 窄屏：内容区里**没有任何**导航 UI，入口是外壳底栏的「记账」（两态唤出
///   面板选择器），用例见 `test/features/shell/app_shell_navigation_test.dart`；
/// - 宽屏 / 桌面窄窗（`prefersRailNavigation` 为真时没有底栏）：工具行左端
///   一枚面板 chip。
///
/// 这里只测页面自己：不再有浮层、宽屏有 chip、深链与分类返回照旧。
void main() {
  testWidgets('页面不再有任何浮在内容上的导航', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    // 默认落在最高频的流水面板：搜索（折叠成图标）与「转账」分段都可见，
    // 账户页的空态不再出现。搜索图标 / 分段不依赖流水是否加载完成，比断言
    // 「还没有流水」更稳（锁态下流水会退化为「读取流水失败」）。
    expect(find.byTooltip('搜索流水'), findsOneWidget);
    expect(find.text('转账'), findsOneWidget);
    expect(find.text('还没有账户'), findsNothing);

    // 回归：入口曾是浮在内容右上角的一颗胶囊——它是 `Stack` 的兄弟节点，
    // 不占页面流、绘制并命中在内容之上，正好压住 8 个面板里 7 个的首行右侧
    // 动作（流水「筛选」、账户「新建账户」、统计动作组…），不是「看不全」而是
    // 「点不到」。整页不该再出现这两个节点，窄屏连页内入口都不该有。
    expect(find.byKey(const ValueKey('bookkeeping-nav-handle')), findsNothing);
    expect(find.byKey(const ValueKey('bookkeeping-nav-panel')), findsNothing);
    expect(
      find.byKey(const ValueKey('module-section-chip-bookkeeping')),
      findsNothing,
    );

    // 「筛选」就在首行最右端，正是过去被压住的位置：必须真的能点开。
    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();
    expect(find.text('全部状态'), findsOneWidget);
  });

  testWidgets('宽屏工具行左端是面板 chip，选完写回 URL 并跟着变', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    // 桌面 / 宽屏没有底栏，页内必须自备入口，否则面板就切不动了。
    await _pump(tester, database, router, width: 1280);

    final chip = find.byKey(const ValueKey('module-section-chip-bookkeeping'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.text('流水')),
      findsOneWidget,
      reason: 'chip 上要常驻当前面板名，否则用户不知道自己在哪',
    );

    await tester.tap(chip);
    await tester.pumpAndSettle();

    // 八个面板一次给出：面板之间只有单向通路（账户/预算/统计 → 流水），
    // 选择器必须一次列全，否则删掉旧 tab 行后会留下死胡同。
    for (final label in ['流水', '账户', '预算', '统计', '分类', '分期', '自动记账', '提醒']) {
      expect(sectionItem(label), findsOneWidget, reason: '选择器里缺少 $label');
    }

    await tester.tap(find.byKey(const ValueKey('module-section-item-budgets')));
    await tester.pumpAndSettle();

    expect(find.text('还没有预算'), findsOneWidget);
    // 面板状态进 URL：系统返回键 / 深链才能正确工作。
    expect(router.state.uri.queryParameters['section'], 'budgets');
    // 选完必须收起，否则又会压回内容上——这正是把它从浮层搬走的初衷。
    expect(find.byKey(const ValueKey('module-section-picker')), findsNothing);
    expect(
      find.descendant(of: chip, matching: find.text('预算')),
      findsOneWidget,
    );

    await tester.tap(chip);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('module-section-item-transactions')),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['section'], 'transactions');
  });

  testWidgets('分类页仍是整屏，返回回到进来时的那个面板', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router, width: 1280);

    Future<void> pick(String section) async {
      await tester.tap(
        find.byKey(const ValueKey('module-section-chip-bookkeeping')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('module-section-item-$section')));
      await tester.pumpAndSettle();
    }

    await pick('budgets');
    await pick('categories');

    // 分类页自带顶栏（返回 + 标题 + 分类管理），整屏留给列表与吸底记账条。
    expect(find.text('分类记账'), findsOneWidget);
    expect(find.byTooltip('分类管理'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(router.state.uri.queryParameters['section'], 'categories');

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['section'], 'budgets');
  });

  testWidgets('deep link opens the section from the query parameter', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router(initialLocation: '/app/bookkeeping?section=budgets');
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    expect(find.text('还没有预算'), findsOneWidget);
  });

  testWidgets(
    'type tabs are not covered by the trailing buttons on narrow phones',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final router = _router();
      addTearDown(router.dispose);

      // 360dp 是主流窄屏宽度：56dp 最小段宽 * 4 = 224dp > 可用宽度，
      // 曾经溢出到右侧图标按钮下面（既被遮住又点不到）。
      await _pump(tester, database, router, width: 360);

      final transfer = tester.getRect(find.text('转账'));
      // 导出与回收站已收进 ⋯，操作行最右侧现在是它。
      final trailing = tester.getRect(find.byTooltip('更多操作'));
      expect(
        transfer.right,
        lessThanOrEqualTo(trailing.left),
        reason: '「转账」标签被右侧按钮遮住',
      );

      final control = tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is AppSlidingSegmentedControl,
        ),
      );
      expect(
        transfer.right,
        lessThanOrEqualTo(control.right),
        reason: '「转账」标签超出了分段控件的可视区',
      );
    },
  );

  testWidgets('搜索默认折叠，点开在本行内展开、类型分段让位', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    // 折叠态：页头只有一行 —— 没有输入框，只有一枚搜索图标。
    expect(find.byType(TextField), findsNothing);
    final searchIcon = tester.getRect(find.byTooltip('搜索流水'));
    final filterIcon = tester.getRect(find.byTooltip('筛选'));
    final moreIcon = tester.getRect(find.byTooltip('更多操作'));
    expect(
      searchIcon.center.dy,
      closeTo(filterIcon.center.dy, 0.5),
      reason: '搜索图标要和右侧动作同排，不能自己占一行',
    );
    expect(moreIcon.left, greaterThan(filterIcon.left));

    await tester.tap(find.byTooltip('搜索流水'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // 展开中：输入框在本行内长出来（宽于图标、还没满宽），且与动作按钮同一行。
    final midway = tester.getRect(find.byType(TextField));
    expect(midway.center.dy, closeTo(searchIcon.center.dy, 6));
    expect(midway.width, greaterThan(40));

    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(TextField));
    expect(field.width, greaterThan(200), reason: '展开后输入框应接管类型分段那一整段宽度');
    // 动作按钮仍在本行右侧、且被推到最右。
    expect(field.right, closeTo(filterIcon.left - 8, 1));
    expect(
      tester.getRect(find.byTooltip('更多操作')).right,
      closeTo(moreIcon.right, 0.5),
    );
  });

  testWidgets('排序收进 ⋯，切换后状态留在菜单里', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    // 行上不再有独立的排序按钮。
    expect(find.byTooltip('排序'), findsNothing);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('排序'), findsOneWidget);
    expect(find.text('时间 ↓'), findsOneWidget);

    await tester.tap(find.text('金额'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('金额 ↓'), findsOneWidget);
    expect(find.text('时间'), findsOneWidget);
  });

  testWidgets('周期在收支卡标题上，状态与标签收进筛选面板', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    // 不再有独立的「统计周期」卡：周期就是收支卡的标题 chip。
    expect(find.text('统计周期'), findsNothing);
    expect(find.text('本月'), findsOneWidget);
    // 页头只剩一行：搜索是图标，状态 / 标签在面板里。
    expect(find.byTooltip('搜索流水'), findsOneWidget);
    expect(find.text('全部状态'), findsNothing);
    expect(find.text('本周'), findsNothing);

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();

    expect(find.text('全部状态'), findsOneWidget);
    expect(find.text('本周'), findsNothing);
    // 点遮罩关掉面板（它没有独立的关闭按钮，下滑 / 点外部都行）。
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('选择统计周期'));
    await tester.pumpAndSettle();
    expect(find.text('本周'), findsOneWidget);
    await tester.tap(find.text('全部时间').last);
    await tester.pumpAndSettle();
    expect(find.text('全部时间'), findsWidgets);
  });

  testWidgets('标签筛选有独立入口，选中后变成可移除的生效条件', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router, tagCandidates: const ['南京旅游']);

    // 折叠态不给标签入口（页头只有一行：搜索图标 + 类型 + 两个动作）。
    expect(find.text('标签'), findsNothing);

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();

    // 筛选面板里与状态同级。在此之前，标签筛选只能从统计页下钻带过来，
    // 列表里根本没有入口。
    expect(find.text('标签'), findsOneWidget);
    await tester.tap(find.text('南京旅游'));
    await tester.pumpAndSettle();

    // 选中后就变成生效条件里的一枚 chip，可单独移除。
    expect(find.text('#南京旅游'), findsOneWidget);
  });

  testWidgets('筛选面板里的条件默认收成一枚「更多条件」，点开才铺控件', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    await tester.tap(find.byTooltip('筛选'));
    await tester.pumpAndSettle();

    // 面板里原来并排铺着 6 个下拉 + 2 个输入框（共约四行），高度全靠滚；
    // 现在只剩「更多条件」一枚 chip。已生效的条件在页头就有可移除 chip，
    // 面板里没必要再铺一遍。
    expect(find.text('更多条件'), findsOneWidget);
    for (final key in _drawerFieldKeys) {
      expect(find.byKey(ValueKey(key)), findsNothing, reason: '$key 不该默认铺开');
    }
    // 两个搜索框删掉了：页头搜索框按名称 / 备注 / 商家三字段模糊匹配，
    // 同一件事说两遍。
    expect(find.text('搜索名称 / 备注'), findsNothing);
    expect(find.text('搜索商家（模糊匹配）'), findsNothing);

    await tester.tap(find.text('更多条件'));
    await tester.pumpAndSettle();

    for (final key in _drawerFieldKeys) {
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: '$key 展开后要在');
    }
    // 展开态靠 trailing 提示「收起」，chip 本体仍是那一枚（没选过条件时文案不变）。
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('transaction-budget-all')), findsNothing);
    expect(find.text('更多条件'), findsOneWidget);
  });

  testWidgets('筛选筛空时，空态给的是清除筛选而不是快速新增', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    // 默认先看本月；空结果不误报成「从未记过」，并提供清除周期条件。
    expect(find.text('没有符合条件的流水'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '清除筛选'), findsOneWidget);

    await tester.tap(find.text('支出').last);
    await tester.pumpAndSettle();

    // 筛过之后查不到 —— 该给的是改条件。继续劝「快速新增」会让用户在已经
    // 筛过的视图里记重复账，再疑惑「我刚记的那笔怎么不在列表里」。
    expect(find.text('没有符合条件的流水'), findsOneWidget);
    expect(find.text('还没有流水'), findsNothing);
    expect(find.widgetWithText(FilledButton, '清除筛选'), findsOneWidget);
  });

  testWidgets('populated流水 renders compact category and metadata row', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router, transactions: [_sampleTransaction()]);

    expect(find.byType(TransactionCard), findsOneWidget);
    expect(find.textContaining('午餐 · 便利店'), findsOneWidget);
    expect(find.textContaining('现金'), findsOneWidget);
  });

  testWidgets(
    'summary card visibly labels amounts and preserves privacy semantics',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      final router = _router();
      addTearDown(router.dispose);

      await _pump(tester, database, router);

      // 周期就是收支卡的标题（原来它是一张独立的「统计周期」卡，同一句
      // 「本月」在一屏里写了两遍）。
      expect(find.text('本月'), findsOneWidget);
      expect(find.text('0 笔'), findsOneWidget);

      // 三格金额同时有可见标签和读屏语义；隐私开关仍可独立控制金额显示。
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp(r'支出 ¥0\.00')), findsOneWidget);
      // 收入默认遮罩：语义标签里的金额是 `****` 而不是真实数字。
      expect(find.bySemanticsLabel(RegExp(r'收入 \*{4}')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'净 \+¥0\.00')), findsOneWidget);
      semantics.dispose();

      expect(find.byTooltip('支出'), findsOneWidget);
      expect(find.byTooltip('收入'), findsOneWidget);
      expect(find.byTooltip('净'), findsOneWidget);

      // 三类金额方向必须可见，不能只依靠红绿颜色提示。
      for (final label in ['支出', '收入', '净']) {
        expect(find.text(label), findsWidgets);
      }
    },
  );
}

/// 宽屏工具行上的账本选择器要落到静态形态用的假账本。
final _ledger = MoneyLedgerEntity(
  id: 'ledger-1',
  userId: 'user-1',
  name: '日常',
  ledgerType: 'personal',
  status: 'active',
  baseCurrencyCode: 'CNY',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

MoneyTransactionEntity _sampleTransaction() {
  final now = DateTime.now();
  return MoneyTransactionEntity(
    id: 'transaction-sample',
    userId: 'user-1',
    type: MoneyTransactionType.expense,
    status: MoneyTransactionStatus.completed,
    transactionAt: now,
    amountMinor: 1234,
    refundAmountMinor: 0,
    currencyCode: 'CNY',
    description: '午餐',
    notes: null,
    merchant: '便利店',
    location: null,
    accountId: 'account-1',
    toAccountId: null,
    categoryId: 'category-1',
    subCategoryId: null,
    paymentMethod: MoneyPaymentMethod.cash,
    customPaymentMethodName: null,
    actualPayerAccount: 'default',
    relatedTransactionId: null,
    installmentPlanId: null,
    sourceTemplateRunId: null,
    interestRateBasisPoints: null,
    totalInterestMinor: 0,
    calcMethod: null,
    tags: const [],
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}

/// 把流水的列表查询替换成内存里的模拟结果。
///
/// 流水页的 `listTransactions` 是动作调用，要经过「已解锁用户 → 当前账本」
/// 才能查到；测试里既没用户也没账本。这里顶掉列表查询，验证空态与真实卡片布局。
class _FakeTransactionActions extends CurrentUserMoneyTransactionActions {
  _FakeTransactionActions(super.ref, {this.transactions = const []});

  final List<MoneyTransactionEntity> transactions;

  @override
  Future<MoneyTransactionPage> listTransactions(
    MoneyTransactionQuery query,
  ) async {
    return MoneyTransactionPage(
      items: transactions,
      page: query.page,
      pageSize: query.pageSize,
      hasMore: false,
      total: 0,
    );
  }
}

/// 筛选面板折叠区里的控件 key（账户 / 渠道 / 分类 / 子分类 / 预算）。
const _drawerFieldKeys = <String>[
  'transaction-budget-all',
  'transaction-account-all',
  'transaction-payment-all',
  'transaction-category-all',
  'transaction-sub-category-all',
];

/// 面板选择器里的某一项。
///
/// 必须限定在选择器卡片里找：同名文本在页面上到处都是（面板名、记账条、
/// 筛选条的下拉），全屏找会把测试变成假阳性。
Finder sectionItem(String label) {
  return find.descendant(
    of: find.byKey(const ValueKey('module-section-picker')),
    matching: find.text(label),
  );
}

GoRouter _router({String initialLocation = '/app/bookkeeping'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/app/bookkeeping',
        // 真实外壳（AppShellPage）也把页面包在 Scaffold 里；测试必须提供
        // Material / Scaffold 祖先，否则 InkWell / TextField 会直接断言失败。
        builder: (context, state) => Scaffold(
          body: BookkeepingPage(
            initialSection: state.uri.queryParameters['section'],
            initialAccountId: state.uri.queryParameters['accountId'],
          ),
        ),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  GoRouter router, {
  double width = 390,
  List<String>? tagCandidates,
  List<MoneyTransactionEntity> transactions = const [],
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        currentUserMoneyTransactionActionsProvider.overrideWith(
          (ref) => _FakeTransactionActions(ref, transactions: transactions),
        ),
        // 宽屏工具行会渲染账本选择器：它加载中 / 空列表时画的是**不确定进度条**，
        // 会一直动，`pumpAndSettle` 永远等不到静止。给一个假账本让选择器落到
        // 静态形态（窄屏不渲染它，无副作用）。
        currentUserMoneyLedgersProvider.overrideWith(
          (ref) => Stream.value([_ledger]),
        ),
        if (tagCandidates != null)
          currentUserTagCandidatesProvider.overrideWith(
            (ref) => Stream.value(tagCandidates),
          ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );

  // 页面里有一个分三批 Future.delayed 的预取器（120/80/80ms），
  // 必须把时钟推过这些定时器，否则测试结束时会报「Timer is still pending」。
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
