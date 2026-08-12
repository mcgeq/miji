## Why

现有预算只能按「全部 / 分类 / 账户 / 分类+账户」四种作用域匹配（`MoneyBudgetScopeType`），无法表达**跨分类的场景预算**——例如「南京旅游」期间衣食住行都计入旅游预算。用户需要一个按交易标签匹配的预算类型：创建预算时选定一个标签（如「南京旅游」），凡打了该标签的支出交易全部计入，不论其分类。

## What Changes

- 新增预算作用域类型 `tag`：`MoneyBudgetScopeType` 增加枚举值 `tag('tag')`
- 预算的标签存于已有 `tagsJson` 列（单标签，严格相等匹配 `transaction.tag == budget.tag`）；表结构不变，WebDAV 同步零改动
- **每笔交易只属于一个标签**：支出记账表单的标签录入改为单选（数据层仍为 `List<String>`，但只写入一条）；候选 = 历史交易标签 + 已有预算标签，防手输拼写错误导致静默漏算
- 预算表单「匹配范围」新增「按标签」选项，标签同样从候选列表单选
- **相加语义**（不互斥）：命中标签预算的交易，同时照常计入全量/分类/账户预算；标签预算只增加，不做排除
- 修改交易标签必须仍走交易更新流程，触发预算快照刷新（已有链路 parts/transactions.dart:399-417，确保新逻辑不绕过）
- **新增一次性周期**：`MoneyBudgetPeriodType` 增加 `oneTime('one_time')`，预算可选择固定起止日期（含首尾当天）不再循环；复用既有 `start_date`/`end_date` 列，表结构与同步零改动；对所有作用域（含标签）正交生效，表单隐藏「自动结转」开关

## Capabilities

### New Capabilities
- `budget-tag-scope`: 预算的标签作用域——创建/编辑、匹配逻辑、已用额计算、UI 表单支持
- `transaction-tag-single`: 支出交易标签单标签约束与候选选择（记账表单、候选来源）

### Modified Capabilities
<!-- 无既有 spec，本变更为仓库首个 change，无修改项 -->

## Impact

- `lib/features/bookkeeping/domain/money_budget_entity.dart` — `MoneyBudgetScopeType` 枚举扩展（唯一数据定义变更点）
- `lib/core/database/tables/money/money_budget_tables.dart` — 无改动（`tagsJson` 列已存在）
- `lib/features/bookkeeping/data/drift_money_repository.dart` — `_readBudgetScope`/`_budgetScopeJson`（行 1920-1958）、`_budgetMatchesTransactionImpact`（行 1499-1536）、`_budgetUsedAmountMinor`（行 2473-2544）增加 tag 分支
- `lib/features/bookkeeping/presentation/budgets/budget_form_dialog.dart` — 作用域选择（行 41-127）增加「按标签」项与标签选择器
- 交易录入/编辑表单 — 标签录入改单选 + 候选列表
- 数据迁移：无（所有变更基于既有列与枚举扩展）