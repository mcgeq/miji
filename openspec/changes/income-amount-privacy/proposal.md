## Why

金额隐私目前只有**一个全局开关**（「隐藏金额」，落库 `user_preferences.mask_money_amounts`），开=所有金额 `••••`、关=全部明文，粒度只有「全遮/全露」两档。

实际场景里**收入比支出更敏感**（工资、奖金、理财收益等），用户希望收入默认就遮住、需要时点一下才看，而支出等其他金额维持现状。全局开关做不到「只遮收入」：开则支出也看不见，关则收入全暴露。

## What Changes

- 新增**收入专属显隐**：收入金额默认显示 `****`，点击任意一处收入金额即全部切换（共享状态），再点切回
- 收入**完全独立于全局开关**：全局「隐藏金额」只管支出/转账/中性金额；收入只看自己的点击态
- 状态为**会话内存态**（Riverpod `Notifier<bool>`，默认 `true`），不落库、不同步、重启复原
- 基础设施与现有 `MoneyPrivacy` 同构：新增 `IncomePrivacy` / `IncomePrivacyScope` InheritedWidget，挂在 `lib/main.dart` 的 `ProviderScope` 内（覆盖对话框等根导航器路由；全局 `MoneyPrivacy` 挂载点不动）
- `MoneyText` 在 `tone == MoneyAmountTone.income` 时改读 `IncomePrivacy` 并自带点击手势；`MoneyAmountText` 新增 `maskedPlaceholder` 参数（收入 `****`，其余仍 `••••`）
- 字符串拼接处新增 `maskedIncomeOr(formatted, context)` 与 `maskedMoneyValue(formatted, isIncome:, context:)`（收入/支出二选一处用）；`maskedMoneyOr` 增加 `placeholder` 参数；需独立点击入口处用 `IncomeAmountTap` 包一层
- 覆盖范围为**所有**收入相关金额：流水行、流水页汇总、日头收入、首页 hero「本月收入」、首页分类/日历面板、统计与报表、收入分类、收入目标预算、交易详情

## Capabilities

### New Capabilities
- `income-amount-privacy`: 收入金额的独立点按显隐——默认遮罩、共享状态、与全局遮罩正交、会话内存态

### Modified Capabilities
<!-- 既有全局「隐藏金额」（BR-3.6.1）语义不变，本次仅新增正交机制 -->

## Impact

- `lib/core/presentation/providers/income_privacy_providers.dart` — 新增（会话态 provider）
- `lib/core/presentation/components/money_text.dart` — 新增 `IncomePrivacy` / `IncomePrivacyScope` / `IncomeAmountTap` / `maskedIncomeOr` / `maskedMoneyValue`，`maskedMoneyOr` 增加 `placeholder` 参数；`MoneyText` 收入分支分流
- `lib/core/presentation/components/money_amount_text.dart` — 新增 `maskedPlaceholder` 参数
- `lib/main.dart` — `ProviderScope` 内挂 `IncomePrivacyScope`
- 各收入展示点（见 design.md「调用点盘点」）— 换 `maskedIncomeOr` / `MoneyText(tone: income)`
- 数据迁移：**无**（不加表列、不加 SharedPreferences、不参与同步）
- 测试：新增 `income_privacy_test.dart`；更新既有「收入默认明文」断言
