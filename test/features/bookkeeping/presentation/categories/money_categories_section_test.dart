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
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/categories/money_categories_section.dart';

void main() {
  testWidgets('keeps a create-category entry point when categories exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_category]));
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);

    // 回归：非空分支以前只有 ListView，没有任何新增入口，
    // 而种子数据总让 categories 非空 → 用户永远无法新增分类。
    expect(find.byTooltip('新增分类'), findsWidgets);

    await tester.tap(find.byTooltip('新增分类').first);
    await tester.pumpAndSettle();
    expect(find.text('新增分类'), findsWidgets);
  });

  testWidgets('renders the real category icon instead of the icon name', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_category]));
    await tester.pumpAndSettle();

    expect(find.text('restaurant'), findsNothing);
    expect(find.byIcon(Icons.restaurant), findsWidgets);
  });

  testWidgets('shows the create action in the empty state too', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('暂无分类'), findsOneWidget);
    expect(find.byTooltip('新增分类'), findsWidgets);
  });

  testWidgets('shows this month usage and filters by search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap([_category, _transport], usageMinor: {'expense_food': 30000}),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('本月 ¥300.00'), findsOneWidget);
    expect(find.textContaining('早餐'), findsWidgets);
    expect(find.text('交通'), findsOneWidget);

    // 搜索名命中子分类名时也要保留父分类。
    await tester.enterText(find.byType(TextField), '早餐');
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsNothing);
  });

  testWidgets('sort mode offers drag handles and reset, and hides search', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_category, _transport]));
    await tester.pumpAndSettle();

    // 非排序模式：有搜索、没有拖拽手柄。
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);

    await tester.tap(find.byTooltip('排序'));
    await tester.pumpAndSettle();

    // 排序模式：搜索收起、每个分类一个手柄、底部有恢复默认顺序。
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNWidgets(2));
    expect(find.text('恢复默认顺序'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    expect(find.textContaining('记账页仍会把常用的分类排前面'), findsOneWidget);

    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
  });

  testWidgets('keeps deactivated categories in a collapsed section', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_category, _transport, _deactivated]));
    await tester.pumpAndSettle();

    // 停用项默认折叠，不和在用项混排。
    expect(find.text('已停用 1 个'), findsOneWidget);
    expect(find.text('旧分类'), findsNothing);

    await tester.tap(find.text('已停用 1 个'));
    await tester.pumpAndSettle();
    expect(find.text('旧分类'), findsOneWidget);
  });
  testWidgets(
    'dragging a category writes the new order through the repository',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = _RecordingCategoryRepository();
      await tester.pumpWidget(
        _wrap([_category, _transport], repository: repository),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('排序'));
      await tester.pumpAndSettle();

      // 把「交通」拖到「餐饮」上面。
      final handle = find.byIcon(Icons.drag_indicator_rounded).last;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(repository.reorderedIds, isNotNull);
      expect(repository.reorderedIds!.first, 'expense_transport');
      expect(repository.reorderedIds, containsAll(['expense_food']));
    },
  );

  testWidgets('reset order asks the repository to restore defaults', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _RecordingCategoryRepository();
    await tester.pumpWidget(
      _wrap([_category, _transport], repository: repository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('排序'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('恢复默认顺序'));
    await tester.pumpAndSettle();

    expect(repository.resetKind, MoneyCategoryKind.expense);
  });

  testWidgets('collapses long sub category lists behind +N', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap([_category, _transport], subCategories: _manySubCategories),
    );
    await tester.pumpAndSettle();

    // 默认只展开 6 个，其余折叠成「+9 个」（共 15 个）。
    expect(find.text('早餐'), findsOneWidget);
    expect(find.text('子分类10'), findsNothing);
    expect(find.text('+9 个'), findsOneWidget);

    await tester.tap(find.text('+9 个'));
    await tester.pumpAndSettle();
    expect(find.text('子分类10'), findsOneWidget);
    expect(find.text('+9 个'), findsNothing);
    expect(find.text('收起'), findsOneWidget);

    await tester.tap(find.text('收起'));
    await tester.pumpAndSettle();
    expect(find.text('+9 个'), findsOneWidget);
  });

  testWidgets('pull to refresh bumps the global money refresh version', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 需要拿到 container 才能断言刷新版本号，所以这里自己建 scope。
    final container = ProviderContainer(
      overrides: [
        currentUserCategoryManagementCatalogProvider.overrideWith(
          (ref, kind) => Stream.value(
            const MoneyCategoryCatalog(
              categories: [_category, _transport],
              subCategories: [],
            ),
          ),
        ),
        currentUserMonthCategoryUsageProvider.overrideWith(
          (ref, kind) async => const MoneyCategoryUsage.empty(),
        ),
        authSessionControllerProvider.overrideWith(_UnlockedSession.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: CategoryManagerPanel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = container.read(moneyDataRefreshVersionProvider);

    await tester.fling(find.byType(ListView), const Offset(0, 320), 1200);
    await tester.pumpAndSettle();

    expect(
      container.read(moneyDataRefreshVersionProvider),
      greaterThan(before),
    );
  });

  testWidgets('分类 tab 上半屏是分类列表、底部是吸底记账条', (tester) async {
    await tester.pumpWidget(_wrapSection());
    await tester.pumpAndSettle();

    // 分类必须看得见：父分类卡片 + 它的子分类 chip。
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('早餐'), findsOneWidget);
    // 记账条吸底，键盘常驻、右下是保存。
    expect(find.byKey(const ValueKey('quick-entry-dock')), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
    // 顶栏自带返回、标题与分类管理——一级导航被收起后它是唯一出口。
    expect(find.text('分类记账'), findsOneWidget);
    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byTooltip('分类管理'), findsOneWidget);
  });

  testWidgets('点子分类即选中，记账条跟着显示它', (tester) async {
    await tester.pumpWidget(_wrapSection());
    await tester.pumpAndSettle();

    await tester.tap(find.text('早餐'));
    await tester.pumpAndSettle();

    final dock = find.byKey(const ValueKey('quick-entry-dock'));
    expect(dock, findsOneWidget);
    expect(
      find.descendant(of: dock, matching: find.text('早餐')),
      findsOneWidget,
    );
  });

  testWidgets('顶栏「返回」把退出交给外层', (tester) async {
    var exited = 0;
    await tester.pumpWidget(_wrapSection(onExit: () => exited++));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();

    expect(exited, 1);
  });

  testWidgets('搜索默认收起，展开后顶替标题而不多占一行', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapSection());
    await tester.pumpAndSettle();

    // 默认没有输入框：这一页的纵向预算被分类列表与吸底键盘两头夹着。
    expect(find.byType(TextField), findsNothing);
    expect(find.text('分类记账'), findsOneWidget);

    await tester.tap(find.byTooltip('搜索分类'));
    await tester.pumpAndSettle();

    // 展开时输入框占的是标题的位置，不是新的一行。
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('分类记账'), findsNothing);

    await tester.enterText(find.byType(TextField), '早餐');
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsNothing);

    // 收起顺手清空关键词：列表不能带着看不见的过滤条件。
    await tester.tap(find.byTooltip('关闭搜索'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('分类记账'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);
  });

  testWidgets('记账条把账户与日期的值写出来', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapSection());
    await tester.pumpAndSettle();

    final dock = find.byKey(const ValueKey('quick-entry-dock'));
    expect(dock, findsOneWidget);
    // 回归：账户与日期曾经只是图标，不点开看不出这一笔的参数。
    expect(
      find.descendant(of: dock, matching: find.text('现金')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dock, matching: find.text('今天')),
      findsOneWidget,
    );
  });

  testWidgets('「分类管理」仍能打开原来的管理面板', (tester) async {
    await tester.pumpWidget(_wrapSection());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('分类管理'));
    await tester.pumpAndSettle();

    // 管理该有的一个都没少：新增、排序、分类卡片。
    expect(find.byTooltip('新增分类'), findsWidgets);
    expect(find.byTooltip('排序'), findsOneWidget);
    expect(find.text('餐饮'), findsWidgets);
  });
}

/// 整个分类 tab（分类列表 + 吸底记账条 + 管理入口）的脚手架。
Widget _wrapSection({VoidCallback? onExit}) {
  return ProviderScope(
    overrides: [
      currentUserCategoryManagementCatalogProvider.overrideWith(
        (ref, kind) => Stream.value(_sectionCatalog),
      ),
      currentUserMonthCategoryUsageProvider.overrideWith(
        (ref, kind) async => const MoneyCategoryUsage.empty(),
      ),
      // 一屏记账那一半要的 provider：不挂桩就会去读真实数据库。
      currentUserCategoryCatalogProvider.overrideWith(
        (ref, kind) => Stream.value(_sectionCatalog),
      ),
      currentUserCategoryUsageStatsProvider.overrideWith(
        (ref) async => const MoneyCategoryUsage.empty(),
      ),
      currentUserVisibleAccountsProvider.overrideWith(
        (ref) => Stream.value([_cashAccount]),
      ),
      currentUserMoneyInternalAccountsProvider.overrideWith(
        (ref) => Stream.value(const <MoneyAccountEntity>[]),
      ),
      currentUserEffectiveTransactionLedgerValueProvider.overrideWithValue(
        null,
      ),
      authSessionControllerProvider.overrideWith(_UnlockedSession.new),
      transactionEntryDefaultsStoreProvider.overrideWithValue(
        const _NoDefaultsStore(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: MoneyCategoriesSection(onExit: onExit)),
    ),
  );
}

const _sectionCatalog = MoneyCategoryCatalog(
  categories: [_category, _transport],
  subCategories: [_breakfast],
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

final _createdAt = DateTime(2026, 1, 1);

/// 没有「上次选择」可读：一屏记账会去读它，测试环境里不能碰真实存储。
class _NoDefaultsStore extends TransactionEntryDefaultsStore {
  const _NoDefaultsStore();

  @override
  Future<TransactionEntryDefaults?> readDefaults({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
  }) async {
    return null;
  }
}

/// 管理面板的测试脚手架。
///
/// 默认挂载的就是 [CategoryManagerPanel]（而不是整个分类 tab）——这些断言
/// 全部只关于管理，直接从面板进入，不用每条都先穿过记账界面点弹窗。
Widget _wrap(
  List<MoneyCategoryEntity> categories, {
  Map<String, int> usageMinor = const {},
  MoneyRepository? repository,
  List<MoneySubCategoryEntity>? subCategories,
}) {
  final catalog = MoneyCategoryCatalog(
    categories: categories,
    subCategories: subCategories ?? const [_breakfast],
  );
  return ProviderScope(
    overrides: [
      currentUserCategoryManagementCatalogProvider.overrideWith(
        (ref, kind) => Stream.value(catalog),
      ),
      currentUserMonthCategoryUsageProvider.overrideWith(
        (ref, kind) async => MoneyCategoryUsage.fromStats(
          categoryStats: {
            for (final entry in usageMinor.entries)
              entry.key: MoneyUsageStat(amountMinor: entry.value),
          },
          subCategoryStats: const {},
        ),
      ),
      authSessionControllerProvider.overrideWith(_UnlockedSession.new),
      if (repository != null)
        moneyRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: CategoryManagerPanel()),
    ),
  );
}

const _breakfast = MoneySubCategoryEntity(
  id: 'expense_food_breakfast',
  categoryId: 'expense_food',
  userId: 'user-1',
  name: '早餐',
  kind: MoneyCategoryKind.expense,
  color: '#FDBA74',
  icon: 'breakfast_dining',
  isSystem: true,
);

const _deactivated = MoneyCategoryEntity(
  id: 'expense_old',
  userId: 'user-1',
  name: '旧分类',
  kind: MoneyCategoryKind.expense,
  color: '#475569',
  icon: 'category',
  isSystem: false,
  sortOrder: 99,
  isDeleted: true,
);

const _transport = MoneyCategoryEntity(
  id: 'expense_transport',
  userId: 'user-1',
  name: '交通',
  kind: MoneyCategoryKind.expense,
  color: '#4F7DD9',
  icon: 'directions_bus',
  isSystem: true,
);

const _category = MoneyCategoryEntity(
  id: 'expense_food',
  userId: 'user-1',
  name: '餐饮',
  kind: MoneyCategoryKind.expense,
  color: '#F97316',
  icon: 'restaurant',
  isSystem: true,
);

/// 只记录「重排/重置」调用，其余方法不会被用到。
class _RecordingCategoryRepository implements MoneyRepository {
  List<String>? reorderedIds;
  MoneyCategoryKind? resetKind;

  @override
  Future<void> reorderCategories(
    String userId,
    MoneyCategoryKind kind,
    List<String> orderedIds,
  ) async {
    reorderedIds = orderedIds;
  }

  @override
  Future<void> resetCategoryOrder(String userId, MoneyCategoryKind kind) async {
    resetKind = kind;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// 已解锁会话：排序要落地必须能拿到 userId。
class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}

final _manySubCategories = <MoneySubCategoryEntity>[
  _breakfast,
  for (var index = 2; index <= 15; index++)
    MoneySubCategoryEntity(
      id: 'expense_food_sub_$index',
      categoryId: 'expense_food',
      userId: 'user-1',
      name: index == 10 ? '子分类10' : '子分类$index',
      kind: MoneyCategoryKind.expense,
      color: '#FDBA74',
      icon: 'lunch_dining',
      isSystem: true,
    ),
];
