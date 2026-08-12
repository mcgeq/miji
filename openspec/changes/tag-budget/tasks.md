## 1. 领域层：作用域枚举

- [ ] 1.1 `MoneyBudgetScopeType` 增加 `tag('tag')` 枚举值（money_budget_entity.dart:46-62），并补充中文 label/描述（预算表单作用域选择将使用）
- [ ] 1.2 确认 `fromStorageValue` fallback 行为对未知值仍归 `all`（老数据兼容，无需改）

## 2. 数据层：scope 读写与匹配

- [ ] 2.1 `_budgetScopeJson`（drift_money_repository.dart:1920-1929）与 `_readBudgetScope`（1931-1958）：scope 结构体增加 `tag` 字段，tag 作用域时从 `tagsJson` 读写（取首元素）
- [ ] 2.2 `_BudgetTransactionImpact` 增加 `tags` 字段，`_budgetMatchesTransactionImpact`（1499-1536）增加 tag 分支：预算 tag 非空时要求 `impact.tags.contains(budgetTag)`，否则不计入
- [ ] 2.3 `_budgetUsedAmountMinor`（2473-2544）：tag 作用域预算在取行后按交易标签过滤（复用既有全量取行，在 `_effectiveTransactionAmountMinor` 折叠处一并判断）
- [ ] 2.4 确认交易影响采集点（创建/更新/删除/自动记账/分期）均已携带 tags，保证快照刷新（1436-1485）对标签预算生效

## 3. 交易标签候选查询

- [ ] 3.1 数据层新增标签候选查询：`money_transaction_tags` 去重 + `money_budgets.tagsJson` 去重合并（repository 接口 + drift 实现）
- [ ] 3.2 provider 层暴露标签候选（bookkeeping_providers.dart 增加 watch/load provider）

## 4. 预算 UI：按标签作用域

- [ ] 4.1 预算表单（budget_form_dialog.dart:41-127）「匹配范围」新增「按标签」选项，选中后展开标签选择器（单选 + 候选 + 新建）
- [ ] 4.2 预算卡片/列表展示 tag 预算的标签徽标（budget_card.dart / money_budgets_section.dart），scope 过滤列表（money_budgets_section.dart:222-226）包含 tag 类型
- [ ] 4.3 预算标签选择器：已存在候选精确 chip 单选；自由输入新文本允许但提示近似候选；预算标签在候选存在时若拼写不匹配提示「该标签暂无匹配交易，请检查拼写」

## 5. 交易 UI：单标签录入

- [ ] 5.1 新建/编辑交易表单（transaction_form_dialog.dart）增加「标签」字段：单选选择器（候选 = 3.x，历史标签 + 预算标签），保存为单条 tag
- [ ] 5.2 保存路径确认：`createTransaction`/`updateTransaction` 的 tags 入参只传单选结果，`_replaceTransactionTags` 正常写入单条（cores 既有逻辑，无需改）；修改标签走 updateTransaction 触发快照刷新（transactions.dart:399-417 已有）

## 7. 一次性周期

- [ ] 7.1 `MoneyBudgetPeriodType` 增加 `oneTime('one_time')` 枚举与 label「一次性」；`MoneyBudgetDraft`/`MoneyBudgetUpdate` 增加 `startDate`/`endDate`（money_budget_entity.dart:17-44）
- [ ] 7.2 周期计算：`_budgetPeriodForAccount`（创建/更新）支持一次性区间（日期非空且结束不早于开始，exclusive 次日存储）；`_budgetPeriodForBudget`（快照/已用额/展示）从 `start_date`/`end_date` 读固定区间；`_currentBudgetPeriod` 对 `oneTime` 防御性报错（drift_money_repository.dart:2053-2112）
- [ ] 7.3 `_validateBudgetScope` 校验一次性日期（缺日期/结束早于开始 → `unsupportedBudgetPeriod`）
- [ ] 7.4 预算表单（budget_form_dialog.dart）周期下拉新增「一次性」，选中显示起止日期选择（复用 `DateTimePicker`），默认当前自然月，隐藏「自动结转剩余额度」；提交/编辑回填日期
- [ ] 7.5 预算 tab 周期筛选下拉（money_budgets_section.dart:445-478）新增「一次性」
- [ ] 7.6 测试：一次性创建/范围计入/缺日期与倒置日期拒绝/标签一次性组合/编辑区间/切回每月/快照刷新（`flutter test`）

## 8. 验证

- [ ] 8.1 运行 `flutter analyze`，无新增告警
- [ ] 8.2 运行测试：标签预算匹配（相等计入/不等不计入/无标签不计入/转账不计入）、单标签替换、标签变更跨预算移动、候选列表来源、一次性周期全链路（涉及 `flutter test` 与既有预算/交易测试）
- [ ] 8.3 手工验证清单：创建「南京旅游」预算 → 记餐饮/交通带标签交易 → 预算已用额累加；改标签 → 两预算联动；月度总预算同时计数（相加语义）；创建一次性标签预算（2026-04-01~04-05）→ 区间内交易计入、区间外不计入
- [ ] 8.4 `dart run build_runner build`（如涉及代码生成变更）并确认无遗留生成文件差异