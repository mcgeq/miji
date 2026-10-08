# 收入金额独立显隐（Income Amount Privacy）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 所有收入金额默认显示 `****`，点任意一处收入金额即全部切换显隐；该状态与全局「隐藏金额」开关完全正交、只存会话内存。

**Architecture:** 与现有 `MoneyPrivacy` 同构的第二套作用域——会话态 `Notifier<bool>` provider → `IncomePrivacy` InheritedWidget（挂 `main.dart` 的 `ProviderScope` 内）→ `MoneyText` 在 `tone == MoneyAmountTone.income` 分流读它并自带点击手势；字符串拼接处用 `maskedIncomeOr` / `maskedMoneyValue` 两个 helper。

**Tech Stack:** Flutter、flutter_riverpod 3（`NotifierProvider` / `ConsumerWidget`）、flutter_test。规格见 `openspec/changes/income-amount-privacy/spec.md`，设计见同目录 `design.md`。

**约定（全任务通用）：**

- 收入遮罩占位符 **`****`**；全局遮罩占位符保持 **`••••`**。
- 收入判定一律基于 `MoneyAmountTone.income` / 明确的 `isIncome` 标志，**不**用金额正负或颜色推断。
- 净额、结余、百分比、混合汇总**不是**收入（见 design.md「例外清单」），保持全局遮罩逻辑不动。
- 每个任务结束跑一次该任务涉及的测试，然后 commit（消息风格与仓库一致：`feat:` / `fix:`）。

---

## 文件结构

**新增**

| 文件 | 职责 |
|---|---|
| `lib/core/presentation/providers/income_privacy_providers.dart` | 会话态 `incomeMaskedProvider`（默认 `true`，不落库） |
| `test/core/presentation/components/income_privacy_test.dart` | 收入遮罩全部单元/组件测试 |

**修改（基础设施）**

| 文件 | 职责 |
|---|---|
| `lib/core/presentation/components/money_text.dart` | `IncomePrivacy`、`IncomePrivacyScope`、`IncomeAmountTap`、`maskedIncomeOr`、`maskedMoneyValue`、`maskedMoneyOr` 加 `placeholder`、`MoneyText` 收入分支 |
| `lib/core/presentation/components/money_amount_text.dart` | `maskedPlaceholder` 参数 |
| `lib/main.dart` | 挂 `IncomePrivacyScope` |

**修改（调用点）**：见任务 4–10，逐文件列在各任务里。

---

### Task 1: 会话态 provider + `IncomePrivacy` 作用域 + 根挂载

**Files:**
- Create: `lib/core/presentation/providers/income_privacy_providers.dart`
- Modify: `lib/core/presentation/components/money_text.dart:1-48`（顶部 import 与 `MoneyPrivacy` 之后插入）
- Modify: `lib/main.dart:43`
- Test: `test/core/presentation/components/income_privacy_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/core/presentation/components/income_privacy_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/providers/income_privacy_providers.dart';
import 'package:miji/core/theme/app_theme.dart';

/// 收入金额独立显隐：默认 `****`、点按切换、与全局「隐藏金额」正交。
void main() {
  Widget scopeHost(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: IncomePrivacyScope(child: child)),
      ),
    );
  }

  testWidgets('作用域默认遮罩（state 初始 true）', (tester) async {
    bool? read;
    await tester.pumpWidget(
      scopeHost(
        Builder(
          builder: (context) {
            read = IncomePrivacy.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(read, isTrue);
  });

  testWidgets('作用域外兜底为 true（失败安全）', (tester) async {
    bool? read;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                read = IncomePrivacy.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(read, isTrue);
  });

  testWidgets('后代可读到 toggle 并切换状态，状态被依赖方重建', (tester) async {
    await tester.pumpWidget(
      scopeHost(
        Column(
          children: [
            Builder(
              builder: (context) => Text(
                'masked=${IncomePrivacy.of(context)}',
                key: const ValueKey('state'),
              ),
            ),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => IncomePrivacy.toggleOf(context)!(),
                child: const Text('toggle'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('state')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('state'))).data,
        'masked=true');

    await tester.tap(find.text('toggle'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.byKey(const ValueKey('state'))).data,
        'masked=false');
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/core/presentation/components/income_privacy_test.dart`
Expected: **FAIL**（编译错误：`IncomePrivacy` / `incomeMaskedProvider` 未定义）

- [ ] **Step 3: 实现 provider**

创建 `lib/core/presentation/providers/income_privacy_providers.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 收入金额显隐（会话内存态，默认遮罩）。
///
/// 与全局「隐藏金额」（`moneyAmountsMaskedProvider`）**正交**：收入只看这里，
/// 全局开关只管支出/转账/中性金额。刻意不落库、不进同步通道 —— 隐私状态
/// 重启即复原为遮罩，是本功能的安全默认。
final incomeMaskedProvider = NotifierProvider<IncomeMaskedController, bool>(
  IncomeMaskedController.new,
);

class IncomeMaskedController extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}
```

- [ ] **Step 4: 实现 `IncomePrivacy` / `IncomePrivacyScope`**

在 `lib/core/presentation/components/money_text.dart` 中：

1) 顶部 import 区加一行（放在 `preferences_providers.dart` 的 import 之后）：

```dart
import 'package:miji/core/presentation/providers/income_privacy_providers.dart';
```

2) 在 `MoneyPrivacyScope` 类结束（`money_text.dart:48` 之后）插入：

```dart
/// 收入金额显隐作用域。
///
/// 与全局 [MoneyPrivacy] 并列的第二套遮罩：收入默认遮罩（`****`）、
/// 点按任意一处收入金额即全部切换、与全局开关互不影响。
///
/// 挂在 `main.dart` 的 `ProviderScope` 内（不是 Shell 里）：收入状态必须
/// 在对话框 / 根导航器路由里也能读、也能点。
class IncomePrivacy extends InheritedWidget {
  const IncomePrivacy({
    super.key,
    required this.masked,
    required this.toggle,
    required super.child,
  });

  final bool masked;

  /// 切换全部收入金额显隐（后代在不接 Riverpod 的情况下也能用）。
  final VoidCallback toggle;

  /// 兜底 `true`：读不到作用域的上下文显示 `****`，失败安全。
  ///
  /// 与 [MoneyPrivacy.of] 的 `?? false` 刻意相反 —— 收入的默认态是遮罩。
  static bool of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<IncomePrivacy>()?.masked ??
        true;
  }

  static VoidCallback? toggleOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<IncomePrivacy>()
        ?.toggle;
  }

  @override
  bool updateShouldNotify(IncomePrivacy oldWidget) {
    return oldWidget.masked != masked || oldWidget.toggle != toggle;
  }
}

/// 读取会话态收入显隐并提供给子树（挂在 `main.dart` 的 ProviderScope 内一次）。
class IncomePrivacyScope extends ConsumerWidget {
  const IncomePrivacyScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IncomePrivacy(
      masked: ref.watch(incomeMaskedProvider),
      toggle: () => ref.read(incomeMaskedProvider.notifier).toggle(),
      child: child,
    );
  }
}
```

- [ ] **Step 5: 挂到 `main.dart`**

`lib/main.dart:43` 由：

```dart
  runApp(const ProviderScope(child: MijiApp()));
```

改为（同时新增 import，放在 `app_theme.dart` import 附近）：

```dart
import 'package:miji/core/presentation/components/money_text.dart';
```

```dart
  runApp(
    const ProviderScope(
      child: IncomePrivacyScope(child: MijiApp()),
    ),
  );
```

注意：**不动** `lib/features/shell/presentation/app_shell_page.dart` 里的 `MoneyPrivacyScope`。

- [ ] **Step 6: 跑测试确认通过**

Run: `flutter test test/core/presentation/components/income_privacy_test.dart`
Expected: **PASS**（3 个用例）

- [ ] **Step 7: Commit**

```bash
git add lib/core/presentation/providers/income_privacy_providers.dart lib/core/presentation/components/money_text.dart lib/main.dart test/core/presentation/components/income_privacy_test.dart
git commit -m "feat: add income privacy scope"
```

---

### Task 2: `MoneyAmountText.maskedPlaceholder` + `MoneyText` 收入分支（含点击）

**Files:**
- Modify: `lib/core/presentation/components/money_amount_text.dart:7-49`
- Modify: `lib/core/presentation/components/money_text.dart:54-87`（`MoneyText.build`）
- Test: `test/core/presentation/components/income_privacy_test.dart`

- [ ] **Step 1: 写失败测试**

在 `income_privacy_test.dart` 的 `main()` 内追加：

```dart
  group('MoneyText 收入分支', () {
    Widget host({required Widget child, bool globalMasked = false}) {
      return ProviderScope(
        overrides: [
          currentUserPreferencesProvider.overrideWith(
            (ref) async => _preferences(maskMoneyAmounts: globalMasked),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: IncomePrivacyScope(child: child)),
        ),
      );
    }

    const income = MoneyText(
      amountMinor: 414000,
      currencyCode: 'CNY',
      tone: MoneyAmountTone.income,
    );
    const expense = MoneyText(amountMinor: 5234000, currencyCode: 'CNY');

    testWidgets('收入默认 ****，支出默认明文（全局开关关闭时）', (tester) async {
      await tester.pumpWidget(
        host(child: const Column(children: [income, expense])),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsOneWidget);
      expect(find.text('¥4,140.00'), findsNothing);
      expect(find.text('¥52,340.00'), findsOneWidget);
    });

    testWidgets('点击收入金额显示，再点隐藏', (tester) async {
      await tester.pumpWidget(host(child: const Column(children: [income])));
      await tester.pumpAndSettle();
      expect(find.text('****'), findsOneWidget);

      await tester.tap(find.text('****'));
      await tester.pumpAndSettle();
      expect(find.text('¥4,140.00'), findsOneWidget);

      await tester.tap(find.text('¥4,140.00'));
      await tester.pumpAndSettle();
      expect(find.text('****'), findsOneWidget);
      expect(find.text('¥4,140.00'), findsNothing);
    });

    testWidgets('点一处，另一处收入同步切换', (tester) async {
      await tester.pumpWidget(
        host(
          child: const Column(
            children: [
              income,
              MoneyText(
                amountMinor: 9900,
                currencyCode: 'CNY',
                tone: MoneyAmountTone.income,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('****'), findsNWidgets(2));

      await tester.tap(find.text('****').first);
      await tester.pumpAndSettle();
      expect(find.text('¥4,140.00'), findsOneWidget);
      expect(find.text('¥99.00'), findsOneWidget);
      expect(find.text('****'), findsNothing);
    });

    testWidgets('全局开：支出 ••••、收入 ****；点收入后收入明文、支出仍 ••••',
        (tester) async {
      await tester.pumpWidget(
        host(
          globalMasked: true,
          child: const Column(children: [income, expense]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('••••'), findsOneWidget);
      expect(find.text('****'), findsOneWidget);

      await tester.tap(find.text('****'));
      await tester.pumpAndSettle();
      expect(find.text('¥4,140.00'), findsOneWidget); // 收入独立，仍可见
      expect(find.text('••••'), findsOneWidget); // 支出不受收入点击影响
    });

    testWidgets('作用域外的收入金额显示 ****（兜底）', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserPreferencesProvider.overrideWith(
              (ref) async => _preferences(maskMoneyAmounts: false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(body: income),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsOneWidget);
      expect(find.text('¥4,140.00'), findsNothing);
    });

    testWidgets('点收入金额不触发外层行的 onTap', (tester) async {
      var rowTapped = false;
      await tester.pumpWidget(
        host(
          child: InkWell(
            onTap: () => rowTapped = true,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: income,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('****'));
      await tester.pumpAndSettle();

      expect(rowTapped, isFalse);
      expect(find.text('¥4,140.00'), findsOneWidget);
    });
  });
```

同时在文件顶部 import 区补：

```dart
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
```

并在 `main()` 之后加复用的工厂函数（与 `money_privacy_test.dart:96-107` 相同实现）：

```dart
UserPreferencesEntity _preferences({required bool maskMoneyAmounts}) {
  final now = DateTime(2026, 1, 1);
  return UserPreferencesEntity(
    userId: 'user-1',
    themeMode: AppThemeModePreference.system,
    sensitiveAccessTtl: SensitiveAccessTtlOption.defaultOption,
    currencyCode: 'CNY',
    maskMoneyAmounts: maskMoneyAmounts,
    createdAt: now,
    updatedAt: now,
  );
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/core/presentation/components/income_privacy_test.dart`
Expected: **FAIL** —— 收入当前渲染明文（`MoneyText` 未分流），`****` 找不到。

- [ ] **Step 3: `MoneyAmountText` 增加占位符参数**

`lib/core/presentation/components/money_amount_text.dart`：

构造函数参数列表 `this.hidden = false,` 之后加 `this.maskedPlaceholder = '••••',`；字段区 `final bool hidden;` 之后加：

```dart
  /// 遮罩态渲染的占位文本（全局遮罩 `••••`，收入遮罩 `****`）。
  final String maskedPlaceholder;
```

`build` 中：

```dart
    final text = hidden
        ? maskedPlaceholder
        : '$sign${formatMoneyMinor(amountMinor, currencyCode)}';
```

- [ ] **Step 4: `MoneyText` 收入分流 + 点击手势**

`lib/core/presentation/components/money_text.dart`，把 `MoneyText.build` 整体替换为：

```dart
  @override
  Widget build(BuildContext context) {
    if (tone == MoneyAmountTone.income) {
      // 收入：只看收入显隐（忽略全局 MoneyPrivacy），并自带点击切换。
      final masked = IncomePrivacy.of(context);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: IncomePrivacy.toggleOf(context),
        child: Semantics(
          button: true,
          label: masked ? '显示金额' : '隐藏金额',
          child: MoneyAmountText(
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            tone: tone,
            hidden: masked,
            maskedPlaceholder: '****',
            textStyle: textStyle,
            color: color,
            showSign: showSign,
            textAlign: textAlign,
          ),
        ),
      );
    }
    return MoneyAmountText(
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      tone: tone,
      hidden: MoneyPrivacy.of(context),
      textStyle: textStyle,
      color: color,
      showSign: showSign,
      textAlign: textAlign,
    );
  }
```

- [ ] **Step 5: 跑测试确认通过**

Run: `flutter test test/core/presentation/components/income_privacy_test.dart`
Expected: **PASS**（3 个旧用例 + 6 个新用例）

- [ ] **Step 6: Commit**

```bash
git add lib/core/presentation/components/money_text.dart lib/core/presentation/components/money_amount_text.dart test/core/presentation/components/income_privacy_test.dart
git commit -m "feat: mask income amounts by default with tap toggle"
```

---

### Task 3: `maskedIncomeOr` / `maskedMoneyValue` / `maskedMoneyOr.placeholder` / `IncomeAmountTap`

**Files:**
- Modify: `lib/core/presentation/components/money_text.dart:89-94`（helper 区）
- Test: `test/core/presentation/components/income_privacy_test.dart`

- [ ] **Step 1: 写失败测试**

在 `income_privacy_test.dart` 的 `main()` 内追加：

```dart
  group('拼接文案 helper', () {
    testWidgets('maskedIncomeOr：遮罩时返回 ****，且随点按切换', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: IncomePrivacyScope(
                child: Column(
                  children: [
                    Builder(
                      builder: (context) => Text(
                        maskedIncomeOr('收入 ¥800.00', context),
                        key: const ValueKey('income-str'),
                      ),
                    ),
                    const MoneyText(
                      amountMinor: 100,
                      currencyCode: 'CNY',
                      tone: MoneyAmountTone.income,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('income-str')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('income-str'))).data,
        '****',
      );

      await tester.tap(find.text('****').last); // 点 MoneyText 那处
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('income-str'))).data,
        '收入 ¥800.00',
      );
    });

    testWidgets('maskedMoneyValue：isIncome 选收入遮罩，否则选全局遮罩',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: IncomePrivacyScope(
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      Text(
                        maskedMoneyValue(
                          '¥1,000.00',
                          isIncome: true,
                          context: context,
                        ),
                        key: const ValueKey('v-income'),
                      ),
                      Text(
                        maskedMoneyValue(
                          '¥2,000.00',
                          isIncome: false,
                          context: context,
                        ),
                        key: const ValueKey('v-expense'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('v-income'))).data,
        '****',
      );
      // 全局开关默认关闭 → 支出侧保持明文
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('v-expense'))).data,
        '¥2,000.00',
      );
    });

    testWidgets('maskedMoneyOr 支持自定义占位符', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: IncomePrivacyScope(
                child: Builder(
                  builder: (context) => Text(
                    maskedMoneyOr(
                      '¥3,000.00',
                      true,
                      placeholder: '****',
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsOneWidget);
    });

    testWidgets('IncomeAmountTap 包住的文案可点按切换', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: IncomePrivacyScope(
                child: Column(
                  children: [
                    Builder(
                      builder: (context) => IncomeAmountTap(
                        child: Text(
                          maskedIncomeOr('收入 ¥800.00', context),
                          key: const ValueKey('tappable'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('tappable'))).data,
        '****',
      );

      await tester.tap(find.byKey(const ValueKey('tappable')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('tappable'))).data,
        '收入 ¥800.00',
      );
    });
  });
```

- [ ] **Step 2: 跑测试确认失败**

Run: `flutter test test/core/presentation/components/income_privacy_test.dart`
Expected: **FAIL**（`maskedIncomeOr` / `maskedMoneyValue` / `IncomeAmountTap` 未定义；`maskedMoneyOr` 不接受 `placeholder`）

- [ ] **Step 3: 实现 helper 与点击包装**

`lib/core/presentation/components/money_text.dart`，把文件末尾的 `maskedMoneyOr` 替换为：

```dart
/// 需要自己拼字符串时的遮罩（例如「支出 ¥1,240」「日均 ¥138」）。
///
/// 组件形式覆盖不了这类拼接文案，用这个保证同一处开关也生效。
String maskedMoneyOr(
  String formatted,
  bool masked, {
  String placeholder = '••••',
}) {
  return masked ? placeholder : formatted;
}

/// 拼接**收入**文案时的遮罩（例如「收入 ¥800」「本月收入 ¥1.2w」）。
///
/// 读 [IncomePrivacy]：默认 `****`，点任意一处收入金额后同步刷新。
String maskedIncomeOr(String formatted, BuildContext context) {
  return IncomePrivacy.of(context) ? '****' : formatted;
}

/// 同一处可能展示收入也可能展示支出时的二选一
/// （统计焦点、分类 kind、预算是否收入目标、交易类型）。
///
/// 收入看 [IncomePrivacy]（`****`），其余看全局 [MoneyPrivacy]（`••••`）。
String maskedMoneyValue(
  String formatted, {
  required bool isIncome,
  required BuildContext context,
}) {
  return isIncome
      ? maskedIncomeOr(formatted, context)
      : maskedMoneyOr(formatted, MoneyPrivacy.of(context));
}

/// 让**非 MoneyText** 的收入金额展示也能点按切换（汇总栏、日头、hero 明细行等）。
///
/// 语义上标成按钮，读屏可识别；与 [MoneyText] 收入分支同一套手势。
class IncomeAmountTap extends StatelessWidget {
  const IncomeAmountTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final masked = IncomePrivacy.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: IncomePrivacy.toggleOf(context),
      child: Semantics(
        button: true,
        label: masked ? '显示金额' : '隐藏金额',
        child: child,
      ),
    );
  }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `flutter test test/core/presentation/components/income_privacy_test.dart test/core/presentation/components/money_privacy_test.dart`
Expected: **PASS**（两个文件全部用例；`money_privacy_test` 必须保持全绿 —— 全局遮罩语义未动）

- [ ] **Step 5: Commit**

```bash
git add lib/core/presentation/components/money_text.dart test/core/presentation/components/income_privacy_test.dart
git commit -m "feat: add income masking helpers"
```

---

### Task 4: 流水页（汇总栏收入、日头收入、账户「本月收入」）

**Files:**
- Modify: `lib/features/bookkeeping/presentation/transactions/money_transactions_section.dart`（`_SummaryMetric` 约 1790-1845、账户汇总「本月收入」约 1747、筛选汇总栏约 2458/2514、日头约 2658-2668）

- [ ] **Step 1: `_SummaryMetric` 支持 tone，并给「本月收入」标 income**

`_SummaryMetric` 构造函数 `this.valueColor,` 之后加 `this.tone = MoneyAmountTone.neutral,`；字段区 `final Color? valueColor;` 之后加：

```dart
  final MoneyAmountTone tone;
```

`_SummaryMetric.build` 里的 `MoneyText(...)` 调用加一行 `tone: tone,`（放在 `currencyCode:` 之后）。

账户汇总里 `label: '本月收入'` 的那处 `_SummaryMetric(...)` 调用加：

```dart
                tone: MoneyAmountTone.income,
```

- [ ] **Step 2: 筛选汇总栏的「收入」改收入遮罩 + 可点按**

把：

```dart
    final incomeText = maskedMoneyOr(
      formatMoneyMinorCompact(summary.incomeMinor, currencyCode),
      masked,
    );
```

改为：

```dart
    final incomeText = maskedIncomeOr(
      formatMoneyMinorCompact(summary.incomeMinor, currencyCode),
      context,
    );
```

（`expenseText`、`netText` 不动。）

`_amount` 方法（`money_transactions_section.dart:2528-2554`）整体替换为：

```dart
  Widget _amount(
    ThemeData theme,
    String label,
    String value,
    Color color, {
    bool income = false,
  }) {
    final body = Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
    return Expanded(child: income ? IncomeAmountTap(child: body) : body);
  }
```

调用处：

```dart
              _amount(theme, '支出', expenseText, moneyColors.expense),
              _amount(
                theme,
                '收入',
                incomeText,
                moneyColors.income,
                income: true,
              ),
              _amount(theme, '净', netText, netColor),
```

- [ ] **Step 3: 日头「收入 ¥x」改收入遮罩 + 可点按**

把：

```dart
            if (incomeMinor > 0)
              Text(
                maskedMoneyOr(
                  '收入 ${formatMoneyMinor(incomeMinor, currencyCode!)}',
                  MoneyPrivacy.of(context),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.moneyColors.income,
                  letterSpacing: 0,
                ),
              ),
```

改为：

```dart
            if (incomeMinor > 0)
              IncomeAmountTap(
                child: Text(
                  maskedIncomeOr(
                    '收入 ${formatMoneyMinor(incomeMinor, currencyCode!)}',
                    context,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.moneyColors.income,
                    letterSpacing: 0,
                  ),
                ),
              ),
```

（紧邻的「支出」`Text` 不动。）

- [ ] **Step 4: 跑测试**

Run: `flutter test test/features/bookkeeping/presentation/bookkeeping_page_test.dart`
Expected: 若断言「收入 ¥0.00」失败属预期，转 Task 11 统一改断言；其余用例 **PASS**。

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookkeeping/presentation/transactions/money_transactions_section.dart
git commit -m "feat: mask income figures in transactions section"
```

---

### Task 5: 交易详情页头部金额

**Files:**
- Modify: `lib/features/bookkeeping/presentation/transactions/transaction_detail_content.dart:100-103`、`:435-460`（`_TransactionDetailSummary`）、`:534-543`

- [ ] **Step 1: 头部金额按交易类型选遮罩**

`:100-103` 处替换为：

```dart
          amountText: maskedMoneyValue(
            '$_amountPrefix${formatMoneyMinor(_displayAmountMinor, transaction.currencyCode)}',
            isIncome: transaction.type == MoneyTransactionType.income,
            context: context,
          ),
```

- [ ] **Step 2: 收入记录的头部金额可点按**

`_TransactionDetailSummary` 构造函数加 `this.amountIsIncome = false,`（放在 `required this.amountText,` 之后），字段区加：

```dart
  /// 头部大号金额是不是收入（收入时包一层点按切换）。
  final bool amountIsIncome;
```

`build` 里（约 534 行）由：

```dart
              final amount = Text(
                amountText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              );
```

改为：

```dart
              final amountTextWidget = Text(
                amountText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              );
              final amount = amountIsIncome
                  ? IncomeAmountTap(child: amountTextWidget)
                  : amountTextWidget;
```

调用 `_TransactionDetailSummary(...)` 处（约 105 行之后）加：

```dart
          amountIsIncome: transaction.type == MoneyTransactionType.income,
```

- [ ] **Step 3: 跑测试**

Run: `flutter test test/features/bookkeeping/presentation/`
Expected: **PASS**（除 Task 11 中收入默认明文的既有断言）

- [ ] **Step 4: Commit**

```bash
git add lib/features/bookkeeping/presentation/transactions/transaction_detail_content.dart
git commit -m "feat: mask income amount on transaction detail"
```

---

### Task 6: 首页 hero 卡（明细行「本月收入」与 Pill「本月收入」）

**Files:**
- Modify: `lib/features/home/presentation/home_balance_hero_card.dart:294-304`、`:351-407`、`:536-600`

- [ ] **Step 1: breakdown 行带收入标志**

无预算分支（约 299-304）由：

```dart
      breakdown = [
        ('本月支出', formatMoneyMinor(spending.monthExpenseMinor, currencyCode)),
        ('本月收入', formatMoneyMinor(spending.monthIncomeMinor, currencyCode)),
      ];
```

改为（三元组：标签、金额、是否收入）：

```dart
      breakdown = [
        (
          '本月支出',
          formatMoneyMinor(spending.monthExpenseMinor, currencyCode),
          false,
        ),
        (
          '本月收入',
          formatMoneyMinor(spending.monthIncomeMinor, currencyCode),
          true,
        ),
      ];
```

有预算分支（约 286-290）的三行也补第三位 `false`：

```dart
      breakdown = [
        ('预算', formatMoneyMinor(summary.totalMinor, currencyCode), false),
        ('已用', formatMoneyMinor(summary.usedMinor, currencyCode), false),
        (
          '日均可花',
          formatMoneyMinor(summary.dailyAllowanceMinor, currencyCode),
          false,
        ),
      ];
```

`breakdown` 的类型注释 `final List<(String, String)> breakdown;` 改为 `final List<(String, String, bool)> breakdown;`。

- [ ] **Step 2: `_AmountBreakdown` 按行选遮罩，收入行可点按**

`_AmountBreakdown` 的字段 `final List<(String, String)> rows;` 改为 `final List<(String, String, bool)> rows;`。

在 `_AmountBreakdown` 类内新增私有方法：

```dart
  /// 单行金额：收入行看 [IncomePrivacy]（`****`）并可点按，
  /// 其余行沿用全局 `masked`（`••••`）且不加点击语义。
  Widget _rowValue(
    BuildContext context,
    ThemeData theme,
    (String, String, bool) row,
  ) {
    final text = Text(
      row.$3
          ? (IncomePrivacy.of(context) ? '****' : row.$2)
          : (masked ? '••••' : row.$2),
      maxLines: 1,
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
    return row.$3 ? IncomeAmountTap(child: text) : text;
  }
```

`build` 中 `for (final row in rows)` 循环里原来的 `Expanded(child: Text(masked ? '••••' : row.$2, ...))` 整块替换为：

```dart
                Expanded(child: _rowValue(context, theme, row)),
```

（行的 `Text(row.$1, ...)` 标签部分不动。）

- [ ] **Step 3: `_PillData` 带收入标志，`_Pill` 按标志选遮罩**

先给 `_PillData` 加 `this.isIncome = false,` 与字段 `final bool isIncome;`，然后把 `_Pills.build` 里的 `entries` 整段替换为：

```dart
    final entries = hasBudget
        ? <_PillData>[
            _PillData('今日支出', spending.todayExpenseMinor, currencyCode),
            _PillData(
              '本月收入',
              spending.monthIncomeMinor,
              currencyCode,
              isIncome: true,
            ),
            _PillData(
              '日均支出',
              spending.dailyAverageExpenseMinor,
              currencyCode,
              showSign: false,
            ),
          ]
        : <_PillData>[
            _PillData('本月支出', spending.monthExpenseMinor, currencyCode),
            _PillData(
              '本月收入',
              spending.monthIncomeMinor,
              currencyCode,
              showSign: true,
              isIncome: true,
            ),
            _PillData('今日支出', spending.todayExpenseMinor, currencyCode),
          ];
```

`_Pill.build` 中，`final text = masked ? ...` 起的三行替换为：

```dart
    final theme = Theme.of(context);
    final maskedAmount = data.isIncome ? IncomePrivacy.of(context) : masked;
    final placeholder = data.isIncome ? '****' : '••••';
    final text = maskedAmount
        ? placeholder
        : '${data.showSign && data.amountMinor > 0 ? '+' : ''}'
              '${formatMoneyMinor(data.amountMinor, data.currencyCode)}';
    final amountText = Text(
      text,
      maxLines: 1,
      style: theme.textTheme.titleSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
```

并把底部的 `FittedBox(...)` 整块替换为：

```dart
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: data.isIncome
                ? IncomeAmountTap(child: amountText)
                : amountText,
          ),
```

（`Container` 的装饰、上方的 label `Text` 均不动。）

- [ ] **Step 4: 跑测试**

Run: `flutter test test/features/home/presentation/home_balance_hero_card_test.dart`
Expected: **PASS**（该文件断言的是全局遮罩 `••••` 与明文，支出行为未变）

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/home_balance_hero_card.dart
git commit -m "feat: mask income lines on home hero card"
```

---

### Task 7: 首页分类结构面板 + 支出日历

**Files:**
- Modify: `lib/features/home/presentation/home_category_structure_panel.dart:270-275`、`:364-369`
- Modify: `lib/features/home/presentation/home_spending_calendar.dart:560-580`（`_DayMetric` 调用与定义）、`:713-745`

- [ ] **Step 1: 分类面板两处 `MoneyAmountText` 改走 `MoneyText`**

两处分别替换（`tone: _amountTone(type)` 保留；`MoneyText` 会按 tone 自动分流收入/全局遮罩，并给收入加点按）：

```dart
                      MoneyText(
                        amountMinor: selected.amountMinor,
                        currencyCode: selected.currencyCode,
                        tone: _amountTone(type),
                        textStyle: theme.textTheme.labelSmall,
                      ),
```

```dart
                        child: MoneyText(
                          amountMinor: item.amountMinor,
                          currencyCode: item.currencyCode,
                          tone: _amountTone(type),
                          textStyle: theme.textTheme.labelMedium,
                        ),
```

确认文件顶部 import 的是 `money_text.dart`（它 re-export 了 `MoneyAmountText`/`MoneyAmountTone`）；若当前 import 的是 `money_amount_text.dart`，改为：

```dart
import 'package:miji/core/presentation/components/money_text.dart';
```

- [ ] **Step 2: 日历 `_DayMetric` 加 tone，收入指标标 income**

`_DayMetric` 构造加 `this.tone = MoneyAmountTone.neutral,`，字段加 `final MoneyAmountTone tone;`，其内部 `MoneyText(...)` 加 `tone: tone,`。

日详情三格调用处：

```dart
              _DayMetric(
                label: '支出',
                amountMinor: point?.expenseMinor ?? 0,
                color: moneyColors.expense,
              ),
              _DayMetric(
                label: '收入',
                amountMinor: point?.incomeMinor ?? 0,
                color: moneyColors.income,
                tone: MoneyAmountTone.income,
              ),
              _DayMetric(
                label: '净额',
                amountMinor: netMinor,
                color: netMinor >= 0 ? moneyColors.income : moneyColors.expense,
                showSign: true,
              ),
```

（「净额」是收支混合值，**不加** income tone。）

- [ ] **Step 3: 日详情交易行按类型标 tone**

`_DayTransactionRow.build` 的 `MoneyText(...)`（约 735 行）加：

```dart
            tone: isIncome ? MoneyAmountTone.income : MoneyAmountTone.neutral,
```

- [ ] **Step 4: 跑测试**

Run: `flutter test test/features/home/presentation/`
Expected: 若 `home_category_structure_panel_test.dart` 断言收入态金额明文则转 Task 11；其余 **PASS**。

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/presentation/home_category_structure_panel.dart lib/features/home/presentation/home_spending_calendar.dart
git commit -m "feat: mask income figures on home panels and calendar"
```

---

### Task 8: 统计页（指标卡、报表卡、分类占比、排行、支付方式、趋势 tooltip、结论条）

**Files:**
- Modify: `lib/features/bookkeeping/presentation/statistics/money_statistics_section.dart`（`_MetricPanel` 1556-1660、收入卡 1421-1431、结论条 1866-1890、组件传参 967-1085）
- Modify: `lib/features/bookkeeping/presentation/statistics/money_report_card.dart:195-202`
- Modify: `lib/features/bookkeeping/presentation/statistics/money_category_share_chart.dart:198-201, 233-236, 279-284`
- Modify: `lib/features/bookkeeping/presentation/statistics/money_statistics_rank_list.dart:133-136`
- Modify: `lib/features/bookkeeping/presentation/statistics/money_payment_method_chart.dart:184-186, 217-219, 264-266`
- Modify: `lib/features/bookkeeping/presentation/statistics/money_account_payment_method_list.dart:133-135`
- Modify: `lib/features/bookkeeping/presentation/statistics/money_trend_chart.dart:177-186`
- Modify: `lib/features/bookkeeping/application/money_statistics_verdict.dart:14-42`

- [ ] **Step 1: `_MetricPanel` 增加 `isIncome` 并改遮罩**

构造加 `this.isIncome = false,`，字段加：

```dart
  final bool isIncome;
```

`build` 中数值与「N 笔 · 均」两处替换：

```dart
          Text(
            maskedMoneyValue(
              formatMoneyMinor(currentMinor, currencyCode),
              isIncome: isIncome,
              context: context,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
```

```dart
          Text(
            _countText(context),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
```

`_countText` 整体替换为：

```dart
  String _countText(BuildContext context) {
    if (count == 0) return '0 笔';
    return maskedMoneyValue(
      '$count 笔 · 均 ${formatMoneyMinor(averageMinor, currencyCode)}',
      isIncome: isIncome,
      context: context,
    );
  }
```

收入卡调用处（1421）加 `isIncome: true,`；支出卡不加。

- [ ] **Step 2: 报表卡收入 chip**

`money_report_card.dart:195-202` 的收入 `_MetricChip` 的 `value:` 改为：

```dart
                value: maskedIncomeOr(
                  formatMoneyMinor(snapshot.incomeMinor, snapshot.currencyCode),
                  context,
                ),
```

（支出 chip、净额 chip 不动。）

- [ ] **Step 3: 四个子组件加 `isIncome` 参数**

对 `money_category_share_chart.dart`、`money_statistics_rank_list.dart`、`money_payment_method_chart.dart`、`money_account_payment_method_list.dart` 各做同样三步：

1. 构造函数加 `this.isIncome = false,`；
2. 字段区加 `final bool isIncome;`（放在 `currencyCode` 附近，注释：`/// 数据是不是收入（统计焦点为收入时为 true）。`）；
3. 文件内**每一处** `maskedMoneyOr(<原文第一个参数>, MoneyPrivacy.of(context))` 替换为 `maskedMoneyValue(<原文第一个参数>, isIncome: isIncome, context: context)` —— 第一个参数（`formatMoneyMinor(...)` 那一整段）**原样搬运，一个字符都不改**，只换外壳。

例（`money_category_share_chart.dart:233-236` 的中心「总收入/总支出」）：

```dart
          maskedMoneyValue(
            formatMoneyMinor(total, currencyCode),
            isIncome: isIncome,
            context: context,
          ),
```

（`money_trend_chart.dart` 不加参数，见 Step 5。）

- [ ] **Step 4: 统计 section 把 `isIncomeFocus` 传给四个子组件**

在 `_StatisticsSection`（967-1085 的组件构造区）里，若还没有，在 `showIncomeCategories` 定义附近确认存在：

```dart
    final isIncomeFocus = filter.typeFocus == MoneyStatisticsTypeFocus.income;
```

给以下构造各加 `isIncome: isIncomeFocus,`：`MoneyCategoryShareChart(...)`（967）、三个 `MoneyStatisticsRankList(...)`（991 / 1013 / 1035）、`MoneyPaymentMethodChart(...)`（1053）、`MoneyAccountPaymentMethodList(...)`（1075）。

- [ ] **Step 5: 趋势图 tooltip 按序列判收入**

`money_trend_chart.dart` 的 `getTooltipItems` 内，把 `maskedMoneyOr(...)` 替换为：

```dart
                          // lineBarsData 顺序：收入(0) → 支出(1) → 净(2)，
                          // 只有「非纯支出焦点」时收入线才会被加入。
                          maskedMoneyValue(
                            formatMoneyMinor(spot.y.round(), currencyCode),
                            isIncome:
                                typeFocus !=
                                    MoneyStatisticsTypeFocus.expense &&
                                spot.barIndex == 0,
                            context: context,
                          ),
```

- [ ] **Step 6: 结论条按焦点选遮罩与占位符**

`money_statistics_verdict.dart` 的 `buildStatisticsVerdict` 签名加 `String maskPlaceholder = '••••',`，函数体内两处 `'••••'` 字面量（`final money = masked ? '••••' : ...` 与最大头分类那处）替换为 `maskPlaceholder`。

`money_statistics_section.dart` 的 `_StatisticsVerdictCard.build`（1880-1886）替换为：

```dart
    final isIncomeFocus = typeFocus == MoneyStatisticsTypeFocus.income;
    final masked = isIncomeFocus
        ? IncomePrivacy.of(context)
        : MoneyPrivacy.of(context);
    final verdict = buildStatisticsVerdict(
      summary: summary,
      typeFocus: typeFocus,
      anomalyCount: anomalyCount,
      masked: masked,
      maskPlaceholder: isIncomeFocus ? '****' : '••••',
    );
```

- [ ] **Step 7: 跑测试**

Run: `flutter test test/features/bookkeeping/presentation/statistics/ test/features/bookkeeping/application/money_statistics_verdict_test.dart`
Expected: **PASS**（verdict 测试用默认 `maskPlaceholder`，不受影响）

- [ ] **Step 8: Commit**

```bash
git add lib/features/bookkeeping/presentation/statistics/ lib/features/bookkeeping/application/money_statistics_verdict.dart
git commit -m "feat: mask income figures in statistics"
```

---

### Task 9: 分类页「本月」、预算历史、预算分配对话框

**Files:**
- Modify: `lib/features/bookkeeping/presentation/categories/money_categories_section.dart:915-939`
- Modify: `lib/features/bookkeeping/presentation/budgets/budget_history_sheet.dart:148-181, 422-425, 491-494`
- Modify: `lib/features/bookkeeping/presentation/budgets/budget_allocation_dialog.dart:463-484, 675-677, 707-716`
- 不改：`lib/features/bookkeeping/presentation/budgets/money_budgets_section.dart:493-547`（混合汇总，例外清单）

- [ ] **Step 1: 分类 tile 的「本月 ¥x」按 kind 选遮罩**

`money_categories_section.dart` 中：

```dart
  /// 本次构建时读到的隐私开关（_metaText 是 getter，拿不到 context）。
  bool _masked = false;
```

改为：

```dart
  /// 本次构建时读到的遮罩结果（_metaText 是 getter，拿不到 context）。
  bool _masked = false;

  /// 遮罩占位符：收入 `****`，其余 `••••`。
  String _maskedPlaceholder = '••••';
```

`build` 中 `_masked = MoneyPrivacy.of(context);` 改为：

```dart
    final isIncome = category.kind == MoneyCategoryKind.income;
    _masked = isIncome
        ? IncomePrivacy.of(context)
        : MoneyPrivacy.of(context);
    _maskedPlaceholder = isIncome ? '****' : '••••';
```

`_metaText` 中：

```dart
        maskedMoneyOr(
          '本月 ${formatMoneyMinor(usageMinor, currencyCode)}',
          _masked,
          placeholder: _maskedPlaceholder,
        ),
```

（若该 widget 手上没有 `category` 字段而是 `kind`，用 `kind == MoneyCategoryKind.income`，以现场字段为准。）

- [ ] **Step 2: 预算历史 sheet 按 `isIncomeTarget` 选遮罩**

`budget_history_sheet.dart` 汇总区的三个 `_SummaryItem.value`（约 148-181）依次替换为：

```dart
          _SummaryItem(
            label: '预算',
            value: maskedMoneyValue(
              formatMoneyMinor(budget.amountMinor, budget.currencyCode),
              isIncome: budget.isIncomeTarget,
              context: context,
            ),
            color: colorScheme.onSurface,
          ),
          _SummaryItem(
            label: budget.isIncomeTarget ? '已赚' : '已用',
            value: maskedMoneyValue(
              formatMoneyMinor(budget.usedAmountMinor, budget.currencyCode),
              isIncome: budget.isIncomeTarget,
              context: context,
            ),
            color: budget.isIncomeTarget
                ? colorScheme.primary
                : colorScheme.error,
          ),
          _SummaryItem(
            label: budget.isIncomeTarget
                ? (budget.isCompleted ? '超额' : '剩余')
                : (budget.isOverspent ? '超支' : '剩余'),
            value: maskedMoneyValue(
              formatMoneyMinor(
                budget.remainingAmountMinor.abs(),
                budget.currencyCode,
              ),
              isIncome: budget.isIncomeTarget,
              context: context,
            ),
            color: budget.isExpenseLimit && budget.isOverspent
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
          ),
```

`_SnapshotAmountRow`：构造加 `this.isIncome = false,`、字段加 `final bool isIncome;`，其 `build` 内替换为：

```dart
            maskedMoneyValue(
              formatMoneyMinor(amountMinor, currencyCode),
              isIncome: isIncome,
              context: context,
            ),
```

该类的**每一处调用点**（同文件内搜索 `_SnapshotAmountRow(`）加 `isIncome: budget.isIncomeTarget,`；若某个调用点所处作用域拿不到 `budget`，沿调用链把 `bool isIncome` 形参传进来（以现场作用域为准，不要用 label 文本猜）。

分配行的 `已用 x / y`（约 422-425）同样换成 `maskedMoneyValue(..., isIncome: <该预算的 isIncomeTarget>, context: context)`；其 widget 若未持有预算，按上一条把 `isIncome` 传进来。

- [ ] **Step 3: 预算分配对话框补遮罩（含收入判定）**

该文件当前**完全没遮罩**，四组金额逐处加 `maskedMoneyValue`（收入目标预算 → 收入遮罩；支出预算 → 顺带补上既有全局遮罩，对齐 BR-3.6.1）。判定统一用 `widget.budget.isIncomeTarget`（组件内部已有 `budget` 局部变量时用 `budget.isIncomeTarget`）。

1) 顶部提示（约 179-181）：

```dart
                    availableAmountMinor < 0
                        ? '当前已超分配 ${maskedMoneyValue(
                            formatMoneyMinor(
                              availableAmountMinor.abs(),
                              widget.budget.currencyCode,
                            ),
                            isIncome: widget.budget.isIncomeTarget,
                            context: context,
                          )}'
                        : '本次最多可分配 ${maskedMoneyValue(
                            formatMoneyMinor(
                              availableAmountMinor,
                              widget.budget.currencyCode,
                            ),
                            isIncome: widget.budget.isIncomeTarget,
                            context: context,
                          )}',
```

2) `_SummaryMetric` 三个 `value:`（约 463-484）：

```dart
              _SummaryMetric(
                label: '预算总额',
                value: maskedMoneyValue(
                  formatMoneyMinor(budget.amountMinor, budget.currencyCode),
                  isIncome: budget.isIncomeTarget,
                  context: context,
                ),
              ),
              _SummaryMetric(
                label: '已分配',
                value: maskedMoneyValue(
                  formatMoneyMinor(
                    summary.allocatedAmountMinor,
                    budget.currencyCode,
                  ),
                  isIncome: budget.isIncomeTarget,
                  context: context,
                ),
              ),
              _SummaryMetric(
                label: summary.isOverAllocated ? '超出' : '未分配',
                value: maskedMoneyValue(
                  formatMoneyMinor(
                    summary.unallocatedAmountMinor.abs(),
                    budget.currencyCode,
                  ),
                  isIncome: budget.isIncomeTarget,
                  context: context,
                ),
                color: summary.isOverAllocated ? colorScheme.error : null,
              ),
```

3) `usageText`（约 675-677）：

```dart
    final usageText =
        '已用 ${maskedMoneyValue(
          formatMoneyMinor(allocation.usedAmountMinor, budget.currencyCode),
          isIncome: budget.isIncomeTarget,
          context: context,
        )}'
        ' · 剩余 ${maskedMoneyValue(
          formatMoneyMinor(allocation.remainingAmountMinor, budget.currencyCode),
          isIncome: budget.isIncomeTarget,
          context: context,
        )}';
```

4) 分配项金额 `Text`（约 707-716）：

```dart
                Text(
                  maskedMoneyValue(
                    formatMoneyMinor(
                      allocation.allocatedAmountMinor,
                      budget.currencyCode,
                    ),
                    isIncome: budget.isIncomeTarget,
                    context: context,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
```

- [ ] **Step 4: 跑测试**

Run: `flutter test test/features/bookkeeping/presentation/`
Expected: 若 `money_categories_section_test.dart:67` 的「本月 ¥300.00」属于**支出**分类应保持 PASS；收入相关断言失败转 Task 11。

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookkeeping/presentation/categories/ lib/features/bookkeeping/presentation/budgets/
git commit -m "feat: mask income amounts in categories and budgets"
```

---

### Task 10: 提醒中心与首页告警条（收入目标预算的「已赚」）

**Files:**
- Modify: `lib/features/bookkeeping/domain/money_reminder_center_entity.dart`（文件末尾加扩展）
- Modify: `lib/features/bookkeeping/presentation/reminders/money_reminder_center_section.dart:714-730, 769-778`
- Modify: `lib/features/home/presentation/home_alerts_strip.dart:110-180`

- [ ] **Step 1: 加收入判定扩展**

`lib/features/bookkeeping/domain/money_reminder_center_entity.dart` 末尾追加（文件顶部若未 import 预算实体，补 `import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';`）：

```dart
/// 提醒金额里哪些属于收入。
///
/// 只有「收入目标预算」的提醒展示的是已赚金额（`budget.usedAmountMinor`），
/// 属收入；账单/分期/信用卡等一律不是。
extension MoneyReminderCenterIncomeX on MoneyReminderCenterItem {
  bool isIncomeAmount(List<MoneyBudgetEntity> budgets) {
    return sourceType == MoneyReminderCenterSourceType.budget &&
        budgets.any((b) => b.id == sourceId && b.isIncomeTarget);
  }
}
```

- [ ] **Step 2: 提醒中心按判定传 tone**

`money_reminder_center_section.dart`：

1. `class _ReminderCardContent extends StatelessWidget` → `extends ConsumerStatelessWidget`；
2. `build(BuildContext context)` → `build(BuildContext context, WidgetRef ref)`；
3. 方法体开头（`final priority = ...` 之前）加：

```dart
    final budgets =
        ref.watch(currentUserBudgetsProvider).valueOrNull ??
        const <MoneyBudgetEntity>[];
    final isIncome = item.isIncomeAmount(budgets);
```

4. 行尾 `MoneyText(...)` 加：

```dart
          tone: isIncome ? MoneyAmountTone.income : MoneyAmountTone.neutral,
```

确认文件已 import `flutter_riverpod`、`bookkeeping_providers.dart`、`money_budget_entity.dart`（该文件已在别处用 `ref.watch(currentUserBillRemindersProvider)`，通常已具备）。

- [ ] **Step 3: 首页告警条改用 `MoneyText`（补上遮罩 + 收入判定）**

`home_alerts_strip.dart`：

1. widget 类改 `ConsumerStatelessWidget`（`build(BuildContext context, WidgetRef ref)`）；
2. 方法体开头加（同 Step 2 的两句）；
3. 把裸的

```dart
        Text(
          formatMoneyMinor(item.amountMinor, item.currencyCode),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
```

替换为：

```dart
        MoneyText(
          amountMinor: item.amountMinor,
          currencyCode: item.currencyCode,
          tone: isIncome ? MoneyAmountTone.income : MoneyAmountTone.neutral,
          color: color,
          textStyle: theme.textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
```

> 注：`MoneyAmountText` 会把字重统一成 `w800`（原为 `w900`），视觉差异可忽略；这是该组件既有行为，不要为它开例外。

- [ ] **Step 4: 跑测试**

Run: `flutter test test/features/bookkeeping/presentation/reminders/ test/features/home/`
Expected: **PASS**（若有断言告警金额明文的用例，转 Task 11）

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookkeeping/domain/money_reminder_center_entity.dart lib/features/bookkeeping/presentation/reminders/money_reminder_center_section.dart lib/features/home/presentation/home_alerts_strip.dart
git commit -m "feat: mask income amounts in reminders and alerts"
```

---

### Task 11: 更新既有测试断言（收入默认 `****`）

**Files:**
- Modify: `test/features/bookkeeping/presentation/bookkeeping_page_test.dart:151`
- Modify: `test/features/home/presentation/home_category_structure_panel_test.dart:113`（若该处是收入态）
- Modify: `test/features/bookkeeping/presentation/categories/money_categories_section_test.dart:67`（若断言收入分类）
- 其他：以 `flutter test` 失败清单为准

- [ ] **Step 1: 跑全量测试拿到失败清单**

Run: `flutter test`
Expected: 记录**全部**失败用例（此步只收集，不改代码）。

- [ ] **Step 2: 按规则修断言**

判定规则（只改「收入」相关断言，其余一律不动）：

| 原断言 | 改为 |
|---|---|
| `find.bySemanticsLabel('收入 ¥0.00')` | `find.bySemanticsLabel('收入 ****')` |
| 收入金额 `find.text('¥x,xxx.xx')` 默认可见 | 改为 `find.text('****')`，并可加「点按后出现明文」的断言 |
| 支出/净额/结余金额断言 | **不改**（行为未变） |
| 全局遮罩 `••••` 断言 | **不改** |

已知候选（按现场代码判断，括号里是预判）：

- `bookkeeping_page_test.dart:151`（**会变**）—— `find.bySemanticsLabel('收入 ¥0.00')` 改为 `find.bySemanticsLabel('收入 ****')`；同测试 173 行的 `['支出','收入','净']` 循环断言的是**可见文案不存在**，不受影响，不要改。
- `home_category_structure_panel_test.dart:113`（**预判不变**：`_host` 固定 `type: HomeCategoryStructureType.expense`，走全局遮罩路径）
- `money_categories_section_test.dart:67`（**预判不变**：fixture 是 `expense_food` 支出分类）
- `home_spending_calendar_test.dart:89/160`（**预判不变**：`:89` 是净额格子，`:160` 是标签）
- `money_privacy_test.dart`（**必须保持全绿**：全局遮罩语义未动）

- [ ] **Step 3: 给新行为补断言（若既有测试没覆盖）**

在 `test/features/bookkeeping/presentation/bookkeeping_page_test.dart` 已有的流水列表用例里补一条：切换到「收入」筛选后，收入行金额为 `****`，点按后出现 `+` 前缀的真实金额。

- [ ] **Step 4: 再跑全量测试**

Run: `flutter test`
Expected: **全部 PASS**

- [ ] **Step 5: Commit**

```bash
git add test/
git commit -m "test: expect masked income amounts by default"
```

---

### Task 12: 验证与收尾

**Files:** 无新改动（除非验证发现问题）

- [ ] **Step 1: 静态分析**

Run: `flutter analyze`
Expected: 无 error；无**新增** warning/info（仓库既有告警数不增加）。

- [ ] **Step 2: 全量测试**

Run: `flutter test`
Expected: 全部 PASS。

- [ ] **Step 3: 对照 spec 逐条手验**

Run（人工，模拟器/真机）：

1. 未开全局隐藏金额：流水页收入行、汇总栏「收入」、日头「收入」、首页「本月收入」、统计收入卡均为 `****`；支出全部明文。
2. 点汇总栏「收入」→ 所有收入同步变明文；再点 → 全部回 `****`。
3. 流水卡片：点**金额**只切换显隐，点卡片其他区域仍进详情。
4. 设置里打开「隐藏金额」→ 支出/转账变 `••••`，收入仍按点击态（默认 `****`）；此时点开收入 → 收入明文、支出仍 `••••`（D7 最后一行）。
5. 收入点开后杀进程重开 → 收入回到 `****`。
6. 收入目标预算（预算卡「已赚」、提醒中心、首页告警条）金额默认 `****`。
7. 统计页切到「收入」焦点：收入卡、分类占比、排行、支付方式、趋势 tooltip、结论条均为 `****`；切回「支出」恢复既有行为。

- [ ] **Step 4: 收尾 commit（如有修正）**

```bash
git add -A
git commit -m "fix: address review findings for income privacy"
```

（若 Step 1-3 无需修改，则跳过本步。）

---

## Self-Review 结果

- **Spec 覆盖**：5 条 Requirement → Task 1-3（默认遮罩/点按切换/正交/会话态/失败安全）+ Task 4-10（收入金额全量覆盖）+ Task 11-12（验证）。
- **占位符扫描**：无 TBD/TODO；所有代码步骤给出完整代码或明确的原样保留指令。
- **类型一致性**：`IncomePrivacy.of/toggleOf`、`incomeMaskedProvider`、`maskedIncomeOr(formatted, context)`、`maskedMoneyValue(formatted, isIncome:, context:)`、`maskedMoneyOr(formatted, masked, {placeholder})`、`IncomeAmountTap(child:)` 在各任务中签名一致。
