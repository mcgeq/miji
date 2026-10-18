# 跨模块时间线 · 实施计划

> 设计见 `cross-module-timeline-plan.md`，界面稿见
> `cross-module-timeline-mockup.html`。这里只写「先做什么、动哪些文件、怎么验」。

## 拆分原则

1. **先纯函数，后界面**：事件的组装是纯函数（输入是各模块已有的领域对象），
   先把「哪条事件属于哪天、属于哪一类」钉住，再画界面。
2. **不新增数据表**：事件是派生视图。
3. **每步都能独立验收**：任何一步停下来，仓库仍然是可运行、可提交的。

---

## 进度：第 1–4 步已落地

| 步 | 内容 | 状态 |
|---|---|---|
| 1 | 领域模型 + 组装（纯函数） | ✅ 9 条单测 |
| 2 | 取数 provider（四路 + 失败隔离） | ✅ 3 条 provider 测试 |
| 3 | 日程页（分组 / 折叠 / 遮蔽 / 空态） | ✅ 5 条 widget 测试 |
| 4 | 路由 + 敏感门禁 + 首页接入 | ✅ 3 条路由测试 + 布局升级测试 |
| 5 | 回顾视图 | ✅ 5 条单测 + 2 条页面测试 |
| 6 | 事件链跳转 | ✅ 部分（见下） |
| 7 | 时薪接入（第 5 路） | ✅ |

## 第 1 步 · 领域模型与组装（纯函数）

**新增**

```
lib/features/timeline/domain/timeline_event.dart
lib/features/timeline/domain/timeline_assembler.dart
test/features/timeline/timeline_assembler_test.dart
```

**内容**

- `TimelineEvent`：`id / occurredOn / at? / precision / nature / module / kind /
  title / subtitle / amountMinor? / emphasis / ruleId? / target / sensitive`
- `TimelineWindow`：`start..end`（按本地日切，`occurredOn` 用 UTC date-key）
- 四个纯映射函数：
  - `moneyEvents(transactions, commitments)` —— 流水=事实，义务=承诺
  - `todoEvents(tasks)` —— `scheduledDate/dueAt`=承诺，`completedAt`=事实
  - `habitEvents(plans, records)` —— 记录=事实；**一天聚合成一条**（十几次打卡
    全列出来会淹没其它事件）
  - `healthEvents(markers)` —— `actualPeriod` / `medication` / `dailyLog`=事实，
    `predictedPeriod` / `pms` / `fertileWindow`=推断
- `assemble(events)`：按日分桶 → 桶内按 nature 分区（待发生 / 已发生）→
  时刻升序、无时刻的排前面 → 超过上限截断并给出剩余条数。

**验收**：单测覆盖「流水归到正确的一天」「预测标成 prediction」「打卡聚合」
「一天超过上限时给剩余数」「跨月边界」。

---

## 第 2 步 · 取数与聚合 provider

**新增**

```
lib/features/timeline/application/timeline_providers.dart
```

- `timelineWindowProvider`：选中日 / 周（Notifier）。
- `timelineEventsProvider`：并发取四路数据 → 调第 1 步的纯函数。
  **单路失败必须隔离**：某一路抛错时记一条 `TimelineSourceFailure`，其余照常
  渲染；不整页报错。
- 复用既有 provider：`currentMonthMoneySummaryProvider` 不合适（只要区间），
  这里直接调仓库：
  - 记账流水：`moneyRepositoryProvider.listTransactions(range)`
  - 未来义务：`moneyRepositoryProvider.upcomingExpenseCommitments(range)`
  - 待办：`todoRepositoryProvider.getTasks(filter)` 后按窗口过滤
  - 打卡：每天 `getRecordsByDate`（窗口最多 31 天，按月查）
  - 健康：`currentUserHealthCalendarMarkersProvider(range)`（已有）

**验收**：`provider` 级测试——用内存库塞一条流水 + 一条待办 + 一条打卡，
断言聚合结果；再让健康那路抛错，断言其它三路仍在。

---

## 第 3 步 · 日程页

**新增**

```
lib/features/timeline/presentation/timeline_page.dart
lib/features/timeline/presentation/timeline_event_tile.dart
```

- AppBar + `日程 / 回顾` 分段（回顾这一步先留空态占位，第 5 步再填）
- 日期条（7 天，点的大小按条数分三档）
- 容器带（预算周期、经期预测）——预算周期先只做「有预算时的当前周期」
- 按日分组 + 两区 + 已发生折叠 + 「还有 N 条」
- 行：竖条模块色 / 时间列 / 图标 / 标题 / 副行 / 右侧
- 未解锁：健康类事件整行遮蔽；金额走 `MoneyPrivacy`

**验收**：widget 测试——390 宽下 12 条不溢出；未解锁时看不到经期标题与金额；
分组顺序正确。

---

## 第 4 步 · 路由与门禁、首页接入

- `AppRoutes` 增加 `timeline = '/app/timeline'`，并**加入 `sensitiveRoutes`**
  （经期与金额都在这一页）。
- 路由表加一条；首页新增 `HomeBlockId.timeline`，概览页 `board` 之后插入
  紧凑块（最多 4 条 + 「查看全部」）。
- 移除概览页 `upNextCard`；`alerts` 在时间线可见时收敛成一行。
- 老用户 `homeBlockOrder` 补齐的解析要有一条测试。

**验收**：升级模拟——老布局 JSON 里没有 timeline，仍能显示且落在 `board` 之后；
进入时间线需要二次验证。

---

## 第 5 步 · 回顾视图 ✅

**做法**：`buildHistory(timeline)` 从**同一份**已组装的时间线里折出回顾（不另查
一遍数据，也就不可能与日程页对不上）。只取事实、按天汇总三项：支出（负数合计）、
打卡次数（聚合行的 `count` 之和）、完成任务数，外加「当天有经期」这一事实。

为了让「打卡 4 次」可汇总，`TimelineEvent` 加了 `count` 字段 —— 从 title 里解析
「4」是给未来的自己挖坑。

界面上 `日程 / 回顾` 分段；回顾模式窗口固定为**整月**（一天的回顾只有一行摘要），
月份可前后翻。点某一天回到那一天的日程。

## 第 5 步（原始说明）· 回顾视图

- 按月分页，每天一行摘要（支出 / 打卡次数 / 任务完成数）。
- **只含事实**，预测与未发生的承诺不出现。
- 月统计与各模块统计页同源（不另算一套）。

---

## 第 6 步 · 事件链跳转（P1）✅ 部分

**已做**：行有 `target` 就能点，跳到来源 ——
义务按来源分到四个面板（分期 / 自动记账 / 提醒 / 流水）、流水进流水面板、
待办进待办详情、打卡与健康进各自模块。

**两处按「不做假功能」砍掉的**：

1. **「改这一次 / 改整条规则」已落地**（2026-10 补）：任务详情页补了
   「重复（点击改整条规则）」一行 + `TodoRecurrenceEditor`（每天/每周/每月、
   间隔、周几或几号、结束日期）。时间线上来自重复规则的事件会先问一句，
   「改整条规则」直接打开编辑器（`?focus=recurrence`）。
2. **给「本来不重复」的任务加规则**（2026-10 补）：任务详情的重复一栏现在
   永远显示（没有规则时写「不重复 · 点这里设为重复」）。保存走
   `attachRecurrenceRule(task, rule)`：这条任务自己变成模板（标题/备注/分类/
   标签全部保留），规则挂在它身上，再补出未来 30 天实例。设完直接退回列表
   并提示「这条变成模板，实例会按规则生成」—— 因为模板不再进列表。
   `TodoRecurrenceEditor` 因此改成交出 `RecurrenceRuleSpec`（只是参数）：
   id / 模板 / userId 由仓库填，编辑器不该知道这些。
2. **分期期次不可能跳到「那一笔流水」**（2026-10 更正）：`upcomingExpenseCommitments`
   只返回**待还**期次（`status == pending`），而那笔流水还没产生。所以这里没有
   「精确跳转」可做，跳到分期面板就是正确终点。已入账的期次会作为**事实**
   出现在流水里，走的是另一条（下面那条：单笔流水没有路由）。

**单笔流水已经有路由了**（2026-10 补）：`/app/bookkeeping/transactions/:id`
→ `TransactionDetailPage`，按 id 取一次再复用 `TransactionDetailContent`。
时间线上的流水事件现在直达那一笔，不再只是「进流水面板」。

## 第 6 步（原始说明）· 事件链跳转（P1）

- 行点击 → 对应模块详情，带 `from=timeline`。
- 承诺类且来自重复规则 → 先问「只改这一次 / 改整个规则」。
- 分期期次 → 能跳到那笔流水（若已入账）。

---

## 第 7 步 · 时薪接入 ✅

第五路 source：**薪水段起点**（事实，落在「哪个月的 1 日」）与**想买冷却结束**
（承诺，带时刻）。段与清单量级都很小，一次取回按窗口过滤。

**年终奖故意不进时间线**：表里只有「纳税年度」，没有发放日期（`taxYear = 0`
甚至表示还没填）。把它画在 1 月 1 日是在编一个日期 —— 时间线上每个点都要有
出处，宁可少一条。这条有专门的测试当护栏。

## 明确不做（本计划范围外）

- `events` 表、无限滚动、跨模块因果洞察、时间线上任何写操作。
- 首页 `HomeStatusChips` 与三宫格的既有重叠（单独记债）。
