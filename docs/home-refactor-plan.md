# 首页重构 · 实施计划

对应预览：`docs/home-redesign-preview.html`

## 目标

把「堆满指标的仪表盘」重构为「一眼看懂、两步记完」的首页：

1. 一个主角数字（本月还可花），今日支出一级信息紧随其后
2. 隐藏手势改为显式控件（周切换 / 收支切换 / 月份切换）
3. 桌面 8/4 双栏、移动端单列分区；条件区块不再导致布局跳动
4. 补齐三项功能缺口：账本切换器、金额隐私、净资产；新增洞察条、分类预算、健康窄条、首次使用引导

## 变更清单

### A. 数据层（新增列，需迁移）

| 表 | 新增列 | 默认 | 用途 |
| --- | --- | --- | --- |
| `user_preferences` | `mask_money_amounts` | false | 首页金额隐私开关（模糊显示） |
| `user_preferences` | `show_home_health_strip` | false | 首页健康窄条开关 |

`schemaVersion` 20 → 21，`onUpgrade` 补两列。`user_preferences` 不参与 delta sync，改动安全。

### B. 记账快捷动作下沉（深模块）

现状：`MoneyQuickActionFab` 的 `_runAction / _openXxxDialog` 全部私有，首页无法复用。

新增 `lib/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart`：

- `enum MoneyQuickAction { expense, income, transfer, task, account, installment, budget, plan }`
- `extension` 提供 `label` / `icon`
- `class MoneyQuickActionLauncher`：持有 `BuildContext` / `WidgetRef` / `FToast`，暴露 `Future<void> run(MoneyQuickAction)`

`MoneyQuickActionFab` 降级为纯展示 + 调用 launcher，首页快捷动作行复用同一个 launcher。

### C. 首页数据层

| Provider | 来源 | 说明 |
| --- | --- | --- |
| `homeNetAssetSummaryProvider` | `currentUserBookkeepingOverviewProvider` | 取基准币种汇总，暴露资产 / 负债 / 净资产 |
| `homeCategoryBudgetProgressProvider` | `currentUserBudgetsProvider` | 本月生效、`scopeType == category`、`isExpenseLimit`，按金额降序取前 2 |
| `homeInsightProvider` | today summary + budget summary + category structure | 纯前端规则，生成一句话结论 |
| `homeStreakProvider` | 最近 60 天交易日期去重 | 连续记账天数 |
| `homeHealthHintProvider` | `currentUserHealthTodaySnapshotProvider` | 经期追踪开启时给出「距下次经期 N 天」 |

新增模型（`home_money_dashboard_models.dart`）：`HomeNetAssetSummary`、`HomeCategoryBudgetProgress`、`HomeInsight`、`HomeStreak`、`HomeHealthHint`。

### D. 展示层

| 新文件 | 替代 |
| --- | --- |
| `home_greeting_header.dart` | `home_dashboard_greeting.dart`（删除） |
| `home_balance_hero_card.dart` | `home_today_spending_card.dart` + `home_month_budget_card.dart`（删除） |
| `home_weekly_trend_card.dart` | 从旧 today card 抽出的周柱图 |
| `home_quick_actions_row.dart` | 新增 |
| `home_insight_strip.dart` | 新增 |
| `home_alerts_strip.dart` | `home_urgent_reminders_panel.dart`（删除） |
| `home_stat_tiles.dart` | 新增（今日行动 + 净资产 bento） |
| `home_health_strip.dart` | 新增 |
| `home_onboarding_view.dart` | 新增 |
| `home_category_structure_panel.dart` | 改造（去掉中心冗余文字，图例补占比条） |
| `home_recent_transactions_panel.dart` | 改造（日期分组 + 异常标记） |
| `home_page.dart` | 重写（Hero/双栏/骨架屏/首次使用） |

### E. 外壳与设置

- `app_shell_page.dart`：首页顶栏补账本切换器 + 隐私按钮；月份胶囊与「回到本月」保留
- `settings_page.dart`：新增「首页」分组（隐藏金额、健康窄条、今日行动卡片）

### F. 测试

- 重写 `home_month_budget_card_test.dart` → `home_balance_hero_card_test.dart`
- 重写 `home_today_spending_card_test.dart` → `home_weekly_trend_card_test.dart`
- 更新 `home_category_structure_panel_test.dart`
- 扩充 `home_money_dashboard_providers_test.dart`（洞察 / 分类预算 / 净资产 / streak）

## 顺序

1. A 数据层 → `build_runner` → 验证
2. B 快捷动作下沉 → `flutter analyze`
3. C 首页数据层 + 单测
4. D 展示层重写
5. E 外壳与设置
6. F 测试全绿 + `flutter analyze`

## 实施结果

| 阶段 | 状态 |
| --- | --- |
| A 数据层（schema 21 + 2 列 + 仓储 + 迁移测试） | ✅ |
| B `MoneyQuickActionLauncher` 下沉，FAB 与首页共用 | ✅ |
| C 新增 5 个首页 Provider + 5 个模型 | ✅ |
| D 展示层 10 个新组件，删除 4 个旧组件 | ✅ |
| E 设置页新增「隐藏金额 / 健康提示」开关 | ✅ |
| F `flutter analyze` 干净，首页 33 个测试全绿 | ✅ |

### 与原设计稿的三处偏差（均为有意）

1. **隐私开关放在问候行，而不是顶栏**
   桌面端首页没有顶栏（用的是左侧 rail），放顶栏只能覆盖移动端。放问候行两种布局都能用。
   同时它被明确命名为「首页金额隐藏」——目前只有首页接入，没有做成全局隐私开关，避免给出
   超出实际范围的预期。

2. **无提醒时「紧急提醒条」整体不渲染**
   设计稿要求「无数据时显示暂无提醒以占位」。但每次进首页都挂一张「暂无待办提醒」是纯噪声，
   收益低于成本；这里选择不渲染，代价是首屏高度会变化。

3. **周切换用「第 N 周」胶囊，而不是「本周 / 上周 / 更早」**
   底层数据模型就是「选中月的第 N 周」（`homeWeekOffsetProvider` 0..totalWeeks-1），
   用「第 N 周」可以 1:1 映射，且不受「所选月份不是本月」时语义不清的困扰。

### 新增的可测纯函数

- `buildHomeInsight({today, budget, categories})` —— 洞察文案规则
- `buildHomeHealthHint({prediction, hasDailyLogToday, referenceDate})` —— 健康窄条文案
- `isHomeUnusualExpense({...})` —— 异常支出判断（同分类当月至少 3 笔、金额达到均值 3 倍）
- `selectHomeMonthlyExpenseBudget` —— 原有

### 已知遗留

- `test/features/health/data/drift_health_repository_test.dart`（11 个）与
  `legacy_money_import_service_test.dart`（1 个）在改动前就是失败的（已用 `git stash` 对比确认），
  与本次重构无关。前者是 `health_period_settings` 未被 seed，后者依赖一个不在仓库里的本地快照文件。
