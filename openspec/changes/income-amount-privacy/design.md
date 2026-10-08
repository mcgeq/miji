# Design: 收入金额独立显隐（Income Amount Privacy）

## Context

记账模块已有**全局「隐藏金额」**开关：`moneyAmountsMaskedProvider`（`lib/core/preferences/providers/preferences_providers.dart:84`）→ `MoneyPrivacyScope` InheritedWidget（`lib/features/shell/presentation/app_shell_page.dart:39`）→ `MoneyText` 读 `MoneyPrivacy.of(context)`（`lib/core/presentation/components/money_text.dart:54-87`）→ `MoneyAmountText.hidden` 渲染 `••••`（`lib/core/presentation/components/money_amount_text.dart:34-36`）；字符串拼接处用 `maskedMoneyOr(formatted, masked)`（`money_text.dart:92-94`，约 60 处调用）。

本次需求是**收入专属**的第二套显隐机制，与全局开关正交：

1. 收入金额默认显示 `****`（遮罩态）
2. 点击任意一处收入金额 → 全部收入金额一起切换显隐（共享状态）
3. 收入只看这套机制，全局开关只管支出/转账等其他金额
4. 「已显示」状态仅存会话内存，重启/杀进程后回到 `****`
5. 覆盖**所有**收入相关金额：流水行 + 汇总/统计/报表/首页/日历/分类/预算里的收入数字

## Goals / Non-Goals

**Goals:**

- 收入金额独立于全局遮罩的点按显隐，默认遮罩、共享状态、会话内存态
- 收入展示点全覆盖（范围见「调用点盘点」），不留「明细遮住、汇总露馅」的矛盾
- 复用现有 `MoneyPrivacy` 的作用域模式，调用方心智不变

**Non-Goals:**

- 不改全局「隐藏金额」的语义、兜底方向与持久化方式（`MoneyPrivacy.of` 兜底仍为 `false`，`maskMoneyAmounts` 仍落库同步）
- 不持久化收入显隐状态（不加表列、不加 SharedPreferences、不参与 WebDAV 同步）
- 图表几何（柱/饼/趋势线）不遮罩，只遮文本数字 —— 与现状一致
- 表单金额输入框、系统通知栏、导出/分享/截图场景不在本次范围
- 支出/转账/中性金额不响应收入点击

## Decisions

### D1: 会话态 provider，非持久化，默认 `true`

```dart
// lib/core/presentation/providers/income_privacy_providers.dart（新文件）
final incomeMaskedProvider = NotifierProvider<IncomeMaskedController, bool>(
  IncomeMaskedController.new,
);

class IncomeMaskedController extends Notifier<bool> {
  @override
  bool build() => true;          // 默认遮罩
  void toggle() => state = !state;
}
```

非 `autoDispose`（切页面不能复原）、不落库（App 退出即复原）。`NotifierProvider` 是仓库既有惯例（`home_money_dashboard_providers.dart:12`、`database_providers.dart:12` 等）。

### D2: `IncomePrivacy` InheritedWidget 与 `MoneyPrivacy` 同文件同层

放进 `lib/core/presentation/components/money_text.dart`（调用方仍只需 import 一个文件），结构对齐现有 `MoneyPrivacy`：

```dart
class IncomePrivacy extends InheritedWidget {
  final bool masked;
  final VoidCallback toggle;

  /// 兜底 true：拿不到作用域的上下文（如根导航器上的对话框）显示 ****，失败安全。
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IncomePrivacy>()?.masked ?? true;

  /// 供后代在不接 Riverpod 的情况下切换。
  static VoidCallback? toggleOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<IncomePrivacy>()?.toggle;
  ...
}

class IncomePrivacyScope extends ConsumerWidget {
  // build: IncomePrivacy(masked: ref.watch(incomeMaskedProvider),
  //                      toggle: () => ref.read(incomeMaskedProvider.notifier).toggle(),
  //                      child: child)
}
```

**兜底方向与 `MoneyPrivacy` 相反是有意的**：收入的默认态是遮罩，取 `?? true` 让「上下文缺失」表现为遮住而不是泄露。`MoneyPrivacy` 的 `?? false` 不改。

**挂载点：`lib/main.dart` 的 `ProviderScope` 内、`MijiApp` 外**（`runApp(const ProviderScope(child: IncomePrivacyScope(child: MijiApp())))`），而不是与 `MoneyPrivacyScope` 并列挂在 `app_shell_page.dart`。原因：`MoneyPrivacyScope` 在 `ShellRoute` builder 内，根导航器上的对话框（预算分配、记账表单等）拿不到它；收入遮罩要覆盖这些对话框，且收入状态必须在对话框里**也能点按切换**，所以挂到 ProviderScope 正下方。全局 `MoneyPrivacy` 的挂载点与行为一律不动。

### D3: `MoneyText` 按 `tone` 分流，收入分支忽略全局遮罩

```dart
@override
Widget build(BuildContext context) {
  if (tone == MoneyAmountTone.income) {
    final masked = IncomePrivacy.of(context);          // 不读 MoneyPrivacy
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: IncomePrivacy.toggleOf(context),
      child: Semantics(
        button: true,
        label: masked ? '显示金额' : '隐藏金额',
        child: MoneyAmountText(
          amountMinor: amountMinor, currencyCode: currencyCode, tone: tone,
          hidden: masked, maskedPlaceholder: '****',
          textStyle: textStyle, color: color, showSign: showSign, textAlign: textAlign,
        ),
      ),
    );
  }
  return MoneyAmountText(..., hidden: MoneyPrivacy.of(context));  // 支出/转账：现状
}
```

- **识别依据是 `MoneyAmountTone.income`**，不靠金额正负号或颜色推断（转账可能为正、收入可为 0）。
- **手势嵌套**：内层 `GestureDetector` 在手势竞技场胜出 → 流水卡片里**点金额=切换显隐，点卡片其余区域=进详情**，`InkWell` 的跳转不受影响。
- **`MoneyAmountText` 直接调用方**（如 `home_category_structure_panel.dart:270,364`）一律改走 `MoneyText`，避免绕过遮罩判定。

### D4: 遮罩占位符参数化

`MoneyAmountText` 增加 `final String maskedPlaceholder`，默认 `'••••'`；`MoneyText` 收入分支传 `'****'`。非收入路径渲染结果零变化，既有测试不受占位符影响。

### D5: 字符串拼接处的三个 helper 与统一判定规则

```dart
/// 需要自己拼收入文案时（「收入 ¥800」「本月收入 ¥1.2w」）。
String maskedIncomeOr(String formatted, BuildContext context) =>
    IncomePrivacy.of(context) ? '****' : formatted;

/// 全局遮罩（既有），新增占位符参数以支持条件场景。
String maskedMoneyOr(String formatted, bool masked, {String placeholder = '••••'}) =>
    masked ? placeholder : formatted;

/// 同一处可能展示收入也可能展示支出时的二选一
/// （统计焦点、分类 kind、预算是否收入目标、交易类型）。
String maskedMoneyValue(String formatted, {required bool isIncome, required BuildContext context}) =>
    isIncome
        ? maskedIncomeOr(formatted, context)
        : maskedMoneyOr(formatted, MoneyPrivacy.of(context));
```

**统一判定规则（调用方按此选择，不逐处发明）：**

1. 能用 `MoneyText(tone: MoneyAmountTone.income)` 的独立金额 → 用它（自带点击手势与 `****`）；**必须先确认 tone 真的是 income**，只有颜色是 income 的（如 `_SummaryMetric`、日历 `_DayMetric`、日详情行）要补 `tone`。
2. 拼接字符串 → `maskedIncomeOr`（收入恒定处）或 `maskedMoneyValue`（收入/支出二选一处）。
3. 需要独立点击入口、但又不是 `MoneyText` 的 → 外面包 `IncomeAmountTap(child: ...)`。
4. 已在 `InkWell`/`AppSwipeActionTile` 行内的**字符串**金额 → 只做遮罩判定、不再包点击（避免抢走行的点按语义）；`MoneyText(tone: income)` 自带的内层手势**保留**（点金额=切换，点其余=行行为，见 D3）。

`maskedIncomeOr` 本身不可点，但状态共享（Q2 决策 A）：点任意一处 `MoneyText(tone: income)` 后，所有拼接文案同步刷新。

### D6: 混合文案必须拆段

同一段文案里既有支出又有收入的（例如 `'支出 ¥x 收入 ¥y'` 拼在一个 `Text`）必须拆成两个 widget/span，收入段单独走 `maskedIncomeOr`。否则收入无法独立遮罩。盘点时逐处处理；现有代码中这类点以 `money_transactions_section.dart:2648/2660`（已是两段）为准保持。

### D7: 与全局开关的叠加语义（已确认）

| 全局「隐藏金额」 | 收入点击态 | 支出/转账 | 收入 |
|---|---|---|---|
| 关 | 遮（默认） | 明文 | `****` |
| 关 | 显 | 明文 | 明文 |
| 开 | 遮（默认） | `••••` | `****` |
| 开 | 显 | `••••` | **明文**（预期行为，收入独立） |

最后一行是 Q3 决策 A 的直接后果，实现与测试都要覆盖。

## 调用点盘点

实现时逐一核对，分组处理：

| 分组 | 位置 | 处理 |
|---|---|---|
| 流水行 | `transactions/transaction_card.dart:90`、`home/home_recent_transactions_panel.dart:230` | 已是 `MoneyText(tone: income)`，自动生效，只需回归确认 |
| 流水页汇总 | `money_transactions_section.dart:2458`（收入）、`:2660`（日头收入）、`:419`（本月收入） | 换 `maskedIncomeOr`；汇总栏收入包 `IncomeAmountTap` |
| 首页 hero | `home_balance_hero_card.dart:391, 411-449`（本月收入 `_HeroAmount`/`_AmountBreakdown`） | 自定义渲染注入收入遮罩 + 点按 |
| 首页面板 | `home_category_structure_panel.dart:270, 364`（未传 `hidden` 的 `MoneyAmountText`）、`home_spending_calendar.dart:682, 736` | 改走 `MoneyText(tone: income)` |
| 统计/报表 | `money_statistics_section.dart:1421`（`_MetricPanel` 收入卡，含 1607/1620 的数值与「N 笔 · 均」）、`money_report_card.dart:196-202`（收入 chip）、`money_category_share_chart.dart:198/233/271`、`money_statistics_rank_list.dart:133`、`money_payment_method_chart.dart:184/217/264`、`money_account_payment_method_list.dart:133`、`money_trend_chart.dart:181`（tooltip 收入序列）、`money_statistics_section.dart:1881`（结论条） | 这些子组件**收不到焦点信息**，需新增 `isIncome` 参数（默认 `false`）从 `_StatisticsSection` 传入；`MoneyTrendChart` 已有 `typeFocus`；结论条给 `buildStatisticsVerdict` 增加 `maskPlaceholder` 参数。统一走 `maskedMoneyValue`。`money_source_breakdown_card.dart`（分期/自动记账/退款）是**支出侧**，不在收入范围 |
| 分类/预算 | `money_categories_section.dart:915-931`（`_metaText`，按 `category.kind`）、`budget_history_sheet.dart:148-181`（按 `budget.isIncomeTarget`）、`money_budgets_section.dart:493-547` | `maskedMoneyValue`；预算汇总条见「例外」 |
| 预算分配对话框 | `budget_allocation_dialog.dart:463-484, 675-677, 707-716`（**当前完全没遮罩**） | 按 `widget.budget.isIncomeTarget` 走 `maskedMoneyValue`（顺带补上支出侧的全局遮罩） |
| 提醒/首页告警 | `money_reminder_center_section.dart:769`、`home_alerts_strip.dart:172`（收入目标预算的「已赚」金额） | 需由 `sourceType == budget && sourceId 对应预算.isIncomeTarget` 判定收入：改为 `MoneyText` 并按判定传 `tone` |
| 详情页 | `transaction_detail_content.dart:100-103`（头部金额，按 `transaction.type`）、`:214/225/236`（退款相关，属支出） | 头部 `maskedMoneyValue(isIncome: type == income)`；退款行保持全局 |
| 顺带补漏 | `home_insight_strip` / `home_money_dashboard_providers.dart:1141-1218` | 盘点确认：**当前没有收入金额句**，无需改（仅回归确认） |

**例外清单（有意不按收入遮罩，记录在案）**

- **净额/结余**（`money_transactions_section` 汇总「净」、日历净额与格子、hero 结余、报表净额 chip、统计净余额）：是收支混合值，不是收入 → 仍看全局遮罩。
- **`money_budgets_section.dart:493-547` 预算汇总条**：把收入目标与支出预算加总成单一数字，无法拆出收入部分 → 保持全局遮罩（D6 拆分规则在此不可行）。
- **百分比/进度**（`_ComparisonChip` 只显示 `↑12%`、分类占比）：不含金额 → 不遮。
- **通知栏**（`money_budget_alert_notification_service.dart`）：系统通知在 UI 之外 → 非目标。
- **表单输入框**：编辑中的金额是输入而非展示 → 非目标。

## Error Handling / 边界

- 上下文缺 `IncomePrivacy` → 显示 `****`（D2 兜底），不抛错、不泄露。
- 收入金额为 0 → 仍按 `****`/`¥0.00` 规则走 `MoneyText`，无特殊分支。
- `showSign` 收入的 `+` 前缀在遮罩态不显示（整段被 `****` 替换）。
- 语义无障碍：`Semantics(button: true, label: 显示金额/隐藏金额)`，屏幕阅读器可识别为可点控件。
- 收入点击态为全局共享，无「单条记录状态」—— 不存在按 id 记忆的失败路径。

## Testing

新增 `test/core/presentation/components/income_privacy_test.dart`：

1. 收入 `MoneyText` 默认渲染 `****`（无全局遮罩也一样）
2. 点击一次 → 显示真实金额；再点 → 回 `****`
3. 点任意一处 → 同树内另一处收入金额同步切换（共享状态）
4. 全局开关开/关，收入显示均只随收入状态变（D7 表格逐格断言）
5. 支出 `MoneyText` 不受收入点击影响，仍只随全局开关在 `••••`/明文间切换
6. 树外（不包 `IncomePrivacyScope`）的收入金额显示 `****`
7. `maskedIncomeOr`：遮罩态返回 `****`，非遮罩态返回原文
8. 收入金额被点击时，同卡片外层 `onTap`（进详情）**不**触发

回归与收尾：

- 更新现有「收入默认明文」的断言（`bookkeeping_page_test.dart`、`home_balance_hero_card_test.dart`、`money_statistics_*_test.dart` 等，实现时以 `flutter test` 失败清单为准）
- 既有全局遮罩测试（`money_privacy_test.dart`）应保持全绿 —— 支出路径未改
- `flutter analyze` + `flutter test`
