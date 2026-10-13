import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/application/transaction_entry_defaults_store.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_leaf_selector.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/quick_entry_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';

/// 「一屏记账」：分类宫格 + 常驻键盘。
///
/// 这里断言的是**结构**（一屏里都有什么、点一下发生什么），而不是像素：
/// 格子尺寸在手机上会随宽度变，但「15 个常用 + 1 个全部」这个数量、
/// 键盘输入到金额显示的通路、提交前的校验，都是不会随屏幕变的行为。
void main() {
  testWidgets('宫格铺常用叶子，末尾一只是「全部 N」格', (tester) async {
    await _pump(tester);

    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('公交地铁'), findsOneWidget);
    expect(find.text('日用品'), findsOneWidget);
    // 「全部」格给出总数，用户知道宫格只是常用、不是全部。
    expect(find.text('全部 4'), findsOneWidget);

    final tiles = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_QuickCategoryTile',
    );
    expect(tiles, findsNWidgets(4));
  });

  testWidgets('键盘输入直接更新金额显示', (tester) async {
    await _pump(tester);

    // 初始 0。
    expect(find.textContaining('0.00'), findsWidgets);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('.'));
    await tester.pump();
    await tester.tap(find.text('5'));
    await tester.pump();

    expect(find.textContaining('12.50'), findsWidgets);
  });

  testWidgets('退格与清空（C）都能改回金额', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.textContaining('123.00'), findsWidgets);

    await tester.tap(find.text('⌫'));
    await tester.pump();
    expect(find.textContaining('12.00'), findsWidgets);

    await tester.tap(find.text('C'));
    await tester.pump();
    expect(find.textContaining('0.00'), findsWidgets);
  });

  testWidgets('dock 形态：不铺宫格，只出选中分类 + 金额 + 键盘', (tester) async {
    await _pump(tester, dock: true, leaf: _busLeaf);

    // 宫格不在这里——分类列表由外层渲染，dock 只负责收钱。
    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(const ValueKey('quick-entry-dock')), findsOneWidget);
    // 外部选中的分类显示在记账条上。
    expect(find.text('公交地铁'), findsOneWidget);
    // 键盘与保存照旧。
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('dock 把备注 / 账户 / 日期的**当前值**写出来', (tester) async {
    await _pump(tester, dock: true, leaf: _busLeaf);
    final dock = find.byKey(const ValueKey('quick-entry-dock'));

    // 回归：这三项曾经只是金额行右侧的图标，用户不点开就不知道这一笔会
    // 记到哪个账户、哪一天、有没有备注。
    expect(
      find.descendant(of: dock, matching: find.text('现金')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dock, matching: find.text('今天')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dock, matching: find.text('备注')),
      findsOneWidget,
    );

    // 备注写了之后，chip 上显示的是备注内容本身。
    await tester.tap(find.descendant(of: dock, matching: find.text('备注')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '和老王吃饭');
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: dock, matching: find.text('和老王吃饭')),
      findsOneWidget,
    );
  });

  testWidgets('dock 没选分类时把下一步写出来，而不是留白', (tester) async {
    await _pump(tester, dock: true);

    expect(find.text('点上方分类开始记账'), findsOneWidget);

    // 直接保存：提示选分类，不静默失败。
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请选择分类'), findsOneWidget);
  });

  testWidgets('没有金额就保存：给出提示而不是静默失败', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入大于 0 的金额'), findsOneWidget);
  });

  testWidgets('有金额没分类就保存：提示选分类', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请选择分类'), findsOneWidget);
  });

  testWidgets('选分类 + 输金额 → 组装出正确的草稿', (tester) async {
    final drafts = <MoneyTransactionDraft>[];
    await _pump(tester, drafts: drafts);

    // 12.50 + 交通（父分类即叶子，没有子分类）。
    await tester.tap(find.text('公交地铁'));
    await tester.pump();
    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('.'));
    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    // toast 自带 2 秒的自动隐藏定时器，等它走完再结束用例。
    await tester.pump(const Duration(seconds: 3));

    expect(drafts, hasLength(1));
    final draft = drafts.single;
    expect(draft.type, MoneyTransactionType.expense);
    expect(draft.amountMinor, 1250);
    expect(draft.categoryId, 'expense_transport');
    expect(draft.subCategoryId, 'expense_transport_bus');
    expect(draft.accountId, 'cash-1');
    expect(draft.currencyCode, 'CNY');
    // 没写名字时退回类型名：列表会把这类通用文案过滤掉，不会当成用户输入。
    expect(draft.description, '支出');
  });

  testWidgets('保存再记：提交后不关闭，清掉金额与备注但保留分类', (tester) async {
    final drafts = <MoneyTransactionDraft>[];
    await _pump(tester, drafts: drafts);

    await tester.tap(find.text('保存再记'));
    await tester.pump();
    expect(tester.widget<FilterChip>(find.byType(FilterChip)).selected, isTrue);
    await tester.tap(find.text('早餐'));
    await tester.pump();
    await tester.tap(find.text('9'));
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));

    expect(drafts, hasLength(1));
    // 界面还在（没被 pop 掉），金额被清空。
    expect(find.text('保存'), findsOneWidget);
    expect(find.textContaining('0.00'), findsWidgets);
  });

  testWidgets('「全部 N」格打开带搜索的全部分类面板', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('全部 4'));
    await tester.pumpAndSettle();

    // 面板里有搜索框与按父分类分组的标题。
    expect(find.text('搜索子分类 / 分类'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
  });

  testWidgets('切换到收入：分类与账户都换成收入侧的口径', (tester) async {
    await _pump(tester);

    expect(find.text('早餐'), findsOneWidget);

    await tester.tap(find.text('收入'));
    await tester.pumpAndSettle();

    // 收入目录里没有「早餐」，有「工资」。
    expect(find.text('早餐'), findsNothing);
    expect(find.text('工资'), findsOneWidget);

    // 收入不能进信用账户：账户面板里只剩现金。
    await tester.tap(find.text('现金'));
    await tester.pumpAndSettle();
    expect(find.text('招行信用卡'), findsNothing);
    expect(find.text('现金'), findsWidgets);
  });

  testWidgets('文本框聚焦时让位给系统键盘', (tester) async {
    await _pump(tester);

    expect(find.text('保存'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    // 自绘键盘收起，免得与系统键盘重叠。
    expect(find.text('保存'), findsNothing);
  });

  testWidgets('「详细填写」转老表单：已填内容带过去，取消后本页仍在', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('公交地铁'));
    await tester.pump();
    for (final key in ['1', '2', '.', '5']) {
      await tester.tap(find.text(key));
      await tester.pump();
    }

    // chip 行是横向滚动的，窄屏下这一格可能在视口外。
    await tester.ensureVisible(find.text('详细填写'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('详细填写'));
    await tester.pumpAndSettle();

    // 老表单接管——商家 / 地点 / 标签 / 分摊 / 分期只在那边有。
    expect(find.byType(TransactionFormDialog), findsOneWidget);
    // 关键是「不是一张空白表单」：金额已经跟着过来了。
    expect(
      find.descendant(
        of: find.byType(TransactionFormDialog),
        matching: find.textContaining('12.5'),
      ),
      findsWidgets,
    );

    // 取消回来后本页还在，填了一半的东西不能被一起关掉。
    await tester.tap(find.byTooltip('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionFormDialog), findsNothing);
    expect(find.byType(QuickEntrySheet), findsOneWidget);
    expect(find.textContaining('12.50'), findsWidgets);
  });

  testWidgets('宽屏走左右两栏：宫格收进左栏，键盘仍在右栏底部', (tester) async {
    await _pump(tester, size: const Size(1100, 900));

    expect(
      find.byKey(const ValueKey('quick-entry-two-column')),
      findsOneWidget,
    );
    // 宫格被限制在左栏（约半张卡片宽），不再铺满。
    expect(tester.getRect(find.byType(GridView)).width, lessThan(600));
    // 宫格与键盘都还在，只是换了位置。
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('窄屏不出现两栏容器', (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('quick-entry-two-column')), findsNothing);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('记住上次用的账户：不再退回第一个可用账户', (tester) async {
    await _pump(
      tester,
      session: const AuthSession(userId: 'user-1', isUnlocked: true),
      remembered: const TransactionEntryDefaults(accountId: 'credit-1'),
    );

    // 列表里第一个可用账户是现金，记住的是信用卡——chip 上应该是后者。
    expect(find.text('招行信用卡'), findsOneWidget);
    expect(find.text('现金'), findsNothing);
  });
}

class _StubAuthSessionController extends AuthSessionController {
  _StubAuthSessionController(this._session);

  final AuthSession _session;

  @override
  AuthSession build() => _session;
}

class _StubEntryDefaultsStore extends TransactionEntryDefaultsStore {
  const _StubEntryDefaultsStore(this.defaults);

  final TransactionEntryDefaults? defaults;

  @override
  Future<TransactionEntryDefaults?> readDefaults({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
  }) async {
    return defaults;
  }
}

class _RecordingTransactionActions extends CurrentUserMoneyTransactionActions {
  _RecordingTransactionActions(super.ref, this.drafts);

  final List<MoneyTransactionDraft> drafts;

  @override
  Future<MoneyTransactionEntity> createTransaction(
    MoneyTransactionDraft draft, {
    bool rememberDefaults = true,
  }) async {
    drafts.add(draft);
    // 用例关心的是「交给仓库的是什么」，返回一个由草稿拼出来的实体即可，
    // 不碰数据库——成功路径上的「保存再记」等分支才能被走到。
    return _entityFromDraft(draft);
  }
}

MoneyTransactionEntity _entityFromDraft(MoneyTransactionDraft draft) {
  return MoneyTransactionEntity(
    id: 'tx-1',
    userId: 'user-1',
    type: draft.type,
    status: draft.status,
    transactionAt: draft.transactionAt,
    amountMinor: draft.amountMinor,
    refundAmountMinor: 0,
    currencyCode: draft.currencyCode,
    description: draft.description,
    notes: draft.notes,
    merchant: draft.merchant,
    location: draft.location,
    accountId: draft.accountId,
    toAccountId: null,
    categoryId: draft.categoryId,
    subCategoryId: draft.subCategoryId,
    paymentMethod: draft.paymentMethod,
    customPaymentMethodName: draft.customPaymentMethodName,
    actualPayerAccount: draft.actualPayerAccount,
    relatedTransactionId: null,
    installmentPlanId: null,
    sourceTemplateRunId: null,
    interestRateBasisPoints: null,
    totalInterestMinor: 0,
    calcMethod: null,
    tags: draft.tags,
    isDeleted: false,
    createdAt: _createdAt,
    updatedAt: _createdAt,
  );
}

/// dock 形态（分类页吸底记账条）用的选中叶子。
final _busLeaf = CategoryLeaf(
  category: _expenseCatalog.categories.firstWhere(
    (category) => category.id == 'expense_transport',
  ),
  subCategory: _expenseCatalog.subCategories.firstWhere(
    (sub) => sub.id == 'expense_transport_bus',
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  List<MoneyTransactionDraft>? drafts,
  Size size = const Size(390, 900),
  AuthSession session = const AuthSession.locked(),
  TransactionEntryDefaults? remembered,
  bool dock = false,
  CategoryLeaf? leaf,
}) async {
  // 用 view 而不是 setSurfaceSize：后者在这个 Flutter 版本里不会改变
  // MediaQuery 的尺寸，宽屏 / 窄屏分栏永远测不到。
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 会话与「上次选择」都用桩：真实实现会去读 SharedPreferences，
        // 未注册插件的测试环境里那条路走不通。
        authSessionControllerProvider.overrideWith(
          () => _StubAuthSessionController(session),
        ),
        transactionEntryDefaultsStoreProvider.overrideWithValue(
          _StubEntryDefaultsStore(remembered),
        ),
        currentUserCategoryCatalogProvider.overrideWith(
          (ref, kind) => Stream.value(
            kind == MoneyCategoryKind.income ? _incomeCatalog : _expenseCatalog,
          ),
        ),
        currentUserCategoryUsageStatsProvider.overrideWith(
          (ref) async => const MoneyCategoryUsage.empty(),
        ),
        currentUserVisibleAccountsProvider.overrideWith(
          (ref) => Stream.value([_cashAccount, _creditAccount]),
        ),
        currentUserMoneyInternalAccountsProvider.overrideWith(
          (ref) => Stream.value(const <MoneyAccountEntity>[]),
        ),
        currentUserMoneyLedgersProvider.overrideWith(
          (ref) => Stream.value(const <MoneyLedgerEntity>[]),
        ),
        currentUserEffectiveTransactionLedgerValueProvider.overrideWithValue(
          null,
        ),
        if (drafts != null)
          currentUserMoneyTransactionActionsProvider.overrideWith(
            (ref) => _RecordingTransactionActions(ref, drafts),
          ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: dock
              ? QuickEntrySheet(
                  initialType: MoneyTransactionType.expense,
                  dock: true,
                  embedded: true,
                  selectedLeaf: leaf,
                )
              : const QuickEntrySheet(
                  initialType: MoneyTransactionType.expense,
                ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _expenseCatalog = MoneyCategoryCatalog(
  categories: const [
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
    MoneyCategoryEntity(
      id: 'expense_daily',
      userId: 'user-1',
      name: '日用',
      kind: MoneyCategoryKind.expense,
      color: '#0F766E',
      icon: 'shopping_bag',
      isSystem: true,
    ),
  ],
  subCategories: const [
    MoneySubCategoryEntity(
      id: 'expense_food_breakfast',
      categoryId: 'expense_food',
      userId: 'user-1',
      name: '早餐',
      kind: MoneyCategoryKind.expense,
      color: '#FDBA74',
      icon: 'free_breakfast',
      isSystem: true,
    ),
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
      id: 'expense_transport_bus',
      categoryId: 'expense_transport',
      userId: 'user-1',
      name: '公交地铁',
      kind: MoneyCategoryKind.expense,
      color: '#93C5FD',
      icon: 'directions_bus',
      isSystem: true,
    ),
    MoneySubCategoryEntity(
      id: 'expense_daily_goods',
      categoryId: 'expense_daily',
      userId: 'user-1',
      name: '日用品',
      kind: MoneyCategoryKind.expense,
      color: '#5EEAD4',
      icon: 'shopping_bag',
      isSystem: true,
    ),
  ],
);

final _incomeCatalog = MoneyCategoryCatalog(
  categories: const [
    MoneyCategoryEntity(
      id: 'income_salary',
      userId: 'user-1',
      name: '工资',
      kind: MoneyCategoryKind.income,
      color: '#006E30',
      icon: 'payments',
      isSystem: true,
    ),
  ],
  subCategories: const [],
);

final _cashAccount = MoneyAccountEntity(
  id: 'cash-1',
  userId: 'user-1',
  name: '现金',
  type: MoneyAccountType.cash,
  balanceMinor: 100000,
  initialBalanceMinor: 0,
  creditLimitMinor: 0,
  postedDebtMinor: 0,
  frozenCreditMinor: 0,
  statementDay: 1,
  budgetCycleStartDay: 1,
  repaymentDay: 1,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

final _creditAccount = MoneyAccountEntity(
  id: 'credit-1',
  userId: 'user-1',
  name: '招行信用卡',
  type: MoneyAccountType.creditCard,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: 2000000,
  postedDebtMinor: 0,
  frozenCreditMinor: 0,
  statementDay: 5,
  budgetCycleStartDay: 1,
  repaymentDay: 23,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

final _createdAt = DateTime(2026, 1, 1);
