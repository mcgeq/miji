# Design: Tag-Scoped Budgets（标签场景预算）

## Context

当前预算按 4 种作用域匹配交易：`all / category / account / category_account`（`MoneyBudgetScopeType`，money_budget_entity.dart:46-62）。分类作用域只能绑定**单一** categoryId，无法表达「旅游期间衣食住行全部计入」的跨分类场景。

已有的有利基础：

- 交易标签已落地：`MoneyTransactionEntity.tags`（`List<String>`）、`money_transaction_tags` junction 表（money_transaction_tables.dart:106-119）、详情展示、统计切片（`_buildTagSlices`，statistics.dart:1229-1265）
- 预算表**已有预留 `tagsJson` 列**（money_budget_tables.dart:76），且已参与 WebDAV 同步（delta_sync_service.dart:418）——但 UI 与匹配逻辑均未使用
- 交易表单（transaction_form_dialog.dart）**当前没有标签录入控件**——tag 写入目前只来自同步/自动记账等旁路
- 本地写交易后统一经 `_refreshBudgetSnapshotsForTransactionImpacts`（drift_money_repository.dart:1436）刷新预算快照；交易标签修改（transactions.dart:399-417）已走该链路

## Goals / Non-Goals

**Goals:**
- 新增标签作用域预算：建预算时定一个标签（如「南京旅游」），凡该标签的支出交易全部计入，不论分类/账户
- 每笔交易最多一个标签（UI 单选），严格相等匹配
- 相加语义：标签预算与全量/分类/账户预算同时计数，互不干扰
- 零表结构变更、零数据迁移、同步零改动

**Non-Goals:**
- 标签主数据表（去重、重命名联动）——标签仍是字符串，改名断链风险靠 UI 候选缓解
- 互斥语义（打标签的交易从其他预算中排除）——已确认不做
- 历史多标签数据迁移

## Decisions

### D1: 作用域以新枚举值表达，不隐式推断
`MoneyBudgetScopeType` 增加 `tag('tag')`。排除项：复用 `budgetType` 列（已是 legacy 标记 `'standard'/'legacy_snapshot'`，drift_money_repository.dart:560-561，语义占用）；靠「tagsJson 非空」隐式判断（空数组/未选标签的中间态歧义，诊断困难）。

### D2: 存储与读取——`tagsJson` 存单元素数组
预算标签写入 `tagsJson` = `["南京旅游"]`；读取时取首元素。匹配语义 = **交易 tags 包含预算标签**（集合 contains，字符串严格相等）。历史多标签交易天然兼容（无需迁移），UI 写入时只写一条。

### D3: 匹配接入点（三处，均与 category 分支对称）
1. `_readBudgetScope` / `_budgetScopeJson`（drift_money_repository.dart:1920-1958）——扩展返回 tag（scope 结构体加 `tag` 字段，预算表既有 tagsJson 列直接读写）
2. `_budgetMatchesTransactionImpact`（行 1499-1536）——tag 非空时：`impact.tags.contains(budgetTag)` 否则 false（交易影响结构体需带 tags）
3. `_budgetUsedAmountMinor`（行 2473-2544）——SQL 谓词加标签条件（按 tag 查 junction 表，或取交易行后内存过滤；建议内存过滤，因已全量取行求和，`_effectiveTransactionAmountMinor` 折叠处一并判断）

### D4: 相加语义 0 成本
不改其他预算的任何匹配路径——标签预算只是在自已的匹配函数里多一个条件。全量预算本就无条件匹配一切支出，自动天然满足「同时计入」。

### D5: 标签候选 + 单选器
- 候选来源（两处选择器共用）：`money_transaction_tags` 去重 + `money_budgets.tagsJson` 去重
- 交互：已有候选以精确 chip 单选；自由输入新文本允许（创建新标签），但若输入接近已有候选，提示「是否选择精确候选」
- 记账表单新增标签字段（现状无录入控件）；预算表单「匹配范围」新增「按标签」项（budget_form_dialog.dart:41-127）展开同一选择器

### D6: 快照刷新链路不新造
本地写路径（新增/修改标签/删除交易）沿用 `_refreshBudgetSnapshotsForTransactionImpacts`，无需改动；远程同步侧快照以远端下行值为准，不本地重算。标签预算与普通预算无差别。

### D7: 老客户端兼容
`fromStorageValue` 对未知枚举值 fallback 到 `all`（既有实现行为）——老版本客户端会把 tag 预算显示为全量预算。本变更不做协议层防护，接受该窗口（本地优先 App 双端同步部署节奏内可接受）。

### D8: 一次性周期——固定起止日期，`one_time` 枚举 + 既有 start/end 列
旅游行程类场景需要「只针对一段日期」的预算，与循环周期语义不同。实现：
- `MoneyBudgetPeriodType` 增加 `oneTime('one_time')`；`MoneyBudgetDraft`/`MoneyBudgetUpdate` 增加 `startDate`/`endDate`（含首尾当天）
- **存储零迁移**：复用既有 `start_date`/`end_date` 列（money_budget_tables.dart:34-36）；`end_date` 沿用 exclusive 次日语义（与 `_dateKey(period.end)` 一致），`repeat_period_type='one_time'`
- 周期计算：`_budgetPeriodForAccount`（创建/更新）从 draft/update 的日期构造区间；`_budgetPeriodForBudget`（快照/已用额/展示）从 `budget.startDate`/`budget.endDate` 读固定区间；`_currentBudgetPeriod` 对 `oneTime` 防御性抛 `unsupportedBudgetPeriod`（调用方必先拦截）
- 表单：周期下拉新增「一次性」，选中后显示起止日期（复用 `DateTimePicker`，起/止两个字段），默认填充当前自然月；隐藏「自动结转剩余额度」（`supportsAutoRollover == false`）；提交校验日期非空且结束不早于开始
- 首页月度预算卡片不选中一次性预算（`selectHomeMonthlyExpenseBudget` 仅 monthly/billingCycle，既有逻辑不变）
- 作用域正交：一次性周期对所有作用域（含 tag）生效

### D9: 一次性预算不自动结转
`autoRollover` 仅对循环周期有意义，一次性预算表单不展示该开关；存量数据即使有值也不影响计算（结转逻辑只处理循环周期）。

## Risks / Trade-offs

- [静默漏算：拼写不一致导致预算统计不到且无报错] → 候选列表 + 拼写近似提示 + 预算缺匹配时 UI 提示「该标签暂无匹配交易」
- [标签改名断链：交易/预算标签均为字符串，无主数据] → 本期不解决，UI 候选缓解；标签主数据表列为二期候选
- [交易表单从未有标签控件：需新增 UI 与候选查询] → 候选查询复用 drift 去重查询，代价小；控件为单选选择器
- [老客户端将 tag 预算按 all 计算] → 接受（D7），同步部署窗口内完成升级
- [性能：已用额求和全量取行] → 既有实现即如此（2473-2544），标签过滤在内存折叠完成，无额外 SQL

## Migration Plan

无表结构变更、无数据迁移、无同步格式变更。实施顺序：枚举 → 存储层读写/匹配 → 预算 UI → 交易表单标签选择器 → 测试（`flutter test`）。回滚 = 撤销枚举值与匹配分支，`fromStorageValue` 天然兼容。

## Open Questions

- 二期候选：标签主数据表（去重、重命名联动）
- 预算快照/同步时序下，tag 预算快照随远程下行覆盖是否满足双端一致（默认满足，与现有一致）
- 一次性预算过期后是否自动隐藏或归档（本期保持列表可见，由用户手动停用/删除）