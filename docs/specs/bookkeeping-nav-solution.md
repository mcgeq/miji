# 记账模块导航改版：从「右上浮层」到「底栏唤出面板选择器」

> 配套可视稿：`docs/specs/bookkeeping-nav-mockup.html`（切现状 / 方案 A / 方案 B，手机与宽屏、深浅主题、标注开关）。
> 本文只写取舍与落地清单，尺寸与配色在稿里可视化。

## 1. 问题定位（P0，已按代码核实）

上一版把横贯顶部的 8 项 tab 行（61px + 16px 间距 = 77px）收成右上角一颗浮层胶囊：

```dart
// bookkeeping_page.dart
return Stack(children: [
  AppPageFrame(...),                       // 面板内容
  if (_navOpen) Positioned.fill(...),      // 阻尼层
  if (!hidePrimaryNav) Positioned(         // ← 浮在内容之上，不占页面流
    top: inset, right: inset,
    child: _BookkeepingNavBubble(...),
  ),
]);
```

`inset` = compact 12 / medium 20 / 宽屏 24。**它是 `Stack` 的兄弟节点，必然绘制在内容之上**，落点又是内容区右上角 —— 正好是每个面板页头最右侧放动作的地方。

390×844 手机（`pageCompact = 12`）的几何量级：

| | 位置 |
|---|---|
| 内容可用区 | x ∈ [12, 378] |
| 胶囊（`top:12 right:12`，标签「流水」约 70×30）| x ∈ [308, 378]，y ∈ [12, 42] |
| 流水首行（`AppPageFrame` padding 12 + `SizedBox(6)` + 44px 搜索行）| y ∈ [18, 62] |
| 流水「筛选」开关（贴工具行右端）| x ∈ [≈306, 378] |

横向几乎完全重合（胶囊右边缘与「筛选」开关右边缘对齐），纵向压住首行上半 24px。更关键的是 `Stack` 的子节点顺序决定命中测试顺序：胶囊在内容之后 → 该区域点击先命中胶囊，**不是「看不全」，是「点不到」**。

8 个面板中 7 个中招（只有「分类」因为整排收起 `hidePrimaryNav` 幸免）：

| 面板 | 首行最右被覆盖的控件 |
|---|---|
| 流水 | 搜索框尾部 + 「筛选」开关 |
| 账户 | 排序菜单 / 筛选 / **新建账户** |
| 预算 | 搜索框 + 筛选 / 新增 |
| 统计 | 报表设置等动作组 |
| 分期 | 搜索框 + 新增分期 |
| 自动记账 | 搜索框 + 新增 |
| 提醒 | 收支分段（居中）+ 右侧动作组 |

结论：「把导航收起来」这个方向对（77px ≈ 9% 屏高还给内容），**错的是把入口放进了内容区**。

## 2. 对「改成二级路由」的判断

**方向对，但「二级路由」不是这次要解决的问题。**

现状已经是可寻址的二级视图：

- `_syncPanelToUrl()` 把当前面板写回 `/app/bookkeeping?section=xxx`；
- 深链已有：首页提醒卡 / 洞察卡（`?section=reminders|categories|budgets`）、通知（`main.dart` 的 `_handleNotificationPayload` → `?section=…&action=expense`）、分期页「去分类」；
- 系统返回键走 GoRouter 的 location，不依赖面板栈。

`?section=` 现有 6 个调用方，全部**不用改**（这正是保留 query 的收益）：

| 调用方 | 目标 |
|---|---|
| `home_page.dart:648` | 提醒中心 |
| `home_page.dart:777` / `801` | 流水 / categories·budgets·accounts |
| `main.dart:101` | 通知 payload → budgets \| transactions（带 `action=expense`）\| reminders |
| `money_installments_section.dart:195` | 分类 |
| `money_reminder_center_section.dart:288` | 按行跳转 |

另一条硬约束：**面板之间目前只有单向通路**（账户/预算/统计的 `onViewTransactions` 回流水，彼此不通）。
所以无论选哪个方案，**新入口必须一次给出全部 8 个面板**，否则删掉旧 tab 后会留下死胡同 —— 那条 77px 的 tab 行、现在的浮层、本稿的选择器都是在扛这件事。

真把面板拆成同级 path 路由（`/app/bookkeeping/accounts` …）要额外付两笔代价：

1. **面板保活失效。** 现在靠 `_LazyBookkeepingPanelStack` + `Offstage` + `_loadedPanels` 让 8 个面板常驻，切走再切回不重建、不丢滚动位置与筛选条件。换成同级路由后每个面板各自 `pageKey`，`_BookkeepingPageState` 连同 `_loadedPanels` 一起重建，只剩当前面板；想保住就得把面板状态（搜索词 / 筛选 / 排序 / 滚动）整体上提到 provider。
2. **`?action=expense`、`?accountId=` 这类「进模块顺带执行一个动作」的参数**没有自然落点，`initialAction` 的两段式消费逻辑要跟着改。

所以建议：**保持 `/app/bookkeeping?section=` 不动，只把入口从内容区搬走。**

## 3. 方案

### 3.1 方案 A（推荐）：入口搬到「底部导航 + 工具行」，内容区零导航

| 设备档 | 入口 | 说明 |
|---|---|---|
| 窄屏 / 手机（有底栏） | 底部导航「记账」 | **两态**：不在模块内 → 直接进（上次访问的面板，首次流水）；已在模块内 → 底部升出「面板选择器」 |
| 宽屏 ≥1024 / 桌面（`prefersRailNavigation` 恒 true，**没有底栏**）| 页面工具行左端「切换面板 ▾」chip | 挂 `AppPageToolbar.primary`，与账本选择器同排；不新增行高、不遮挡任何内容 |

- 内容区：删掉 `_BookkeepingNavBubble` / `_BubbleHandle` / `_BubblePanel` / `_NavPanelItem`、`_navOpen`、阻尼层、`hidePrimaryNav` 特例（约 180 行）→ 首行右侧控件全部恢复可点，77px 全数归还内容。
- 选择器：窄屏用 `showModalBottomSheet`（4×2 网格，图标 + 名称 + 当前项高亮 + 提醒角标），宽屏用 `showAppResponsiveDialog`（居中）。
- 「我在哪」：底栏高亮 + 面板自身内容（流水有搜索与分段、账户有净资产卡、统计有标题）；宽屏由工具行 chip 恒定显示面板名。

**为什么底栏点击必须是两态**：「点记账 = 进记账」是最高频动作（从首页/打卡切回来）。若每次都弹层，切模块从 1 拍变成「1 拍 + 一次打断 + 1 拍」。两态规则让切模块保持 1 拍，只在「已在本模块再点它」时弹层 —— 也就是 iOS「点当前 tab」的系统惯例。

**顺带修掉一个已知退化**：现在从首页点「记账」走 `go(AppRoutes.bookkeeping)`（不带 section），面板被重置回流水。加一个会话态 `bookkeepingLastSectionProvider`（在 `_selectPanel` 与深链时写入），切模块回来能回到上次面板。

### 3.2 方案 B（保守备选）：只做「去浮层」，导航压成一行

不引入弹层：内容区顶部放一条 32px 高的横向 chip 行（可滚动，8 项文字 chip，当前项 `primaryContainer`），紧贴页头之上，总占位 ≈ 42px。

- 好处：完全不遮挡、**一拍切换**、恒可见；相比收起来的 77px 仍省 35px。
- 代价：内容高度只省回一半；面板页头里本来就有分段控件，顶部再多一条常驻切换器，视觉上略重复；8 项在 390 宽下要横向滚动才看得全。

### 3.3 不建议：保留浮层只换位置

挪右下（撞迷你 FAB）、挪正中（压内容）、随滚动淡出（用户找不到）——都只是把「遮挡谁」换个对象，`Stack` 覆盖 + 命中优先的本质没变。

## 4. 落地清单（方案 A）

1. `lib/features/bookkeeping/presentation/bookkeeping_page.dart`
   - 页面退回纯 `AppPageFrame(Column(...))`，删浮层相关代码与 `_navOpen` / `hidePrimaryNav`。
   - 面板元数据（label / icon）、`_panelFromSection`、`enum _BookkeepingPanel` 提到共享处。
   - 宽屏（`!responsive.isCompact`）分支：`AppPageToolbar(primary: 面板 chip, secondary: CurrentLedgerSelector)`。
2. 新增 `presentation/components/bookkeeping_panel_picker.dart`
   - `Future<void> showBookkeepingPanelPicker(BuildContext, {required section})`：窄屏 bottom sheet / 宽屏居中 dialog；选中后 `go('/app/bookkeeping?section=xxx')`。
3. `lib/core/router/app_routes.dart` + `app_shell_page.dart`
   - 底栏「记账」加两态分支：`path` 已在 `/app/bookkeeping` → 打开选择器；否则 `go(带上次 section 的地址)`。
   - 新增会话态 `bookkeepingLastSectionProvider`。
4. 特例
   - **分类面板**：保留自己的返回顶栏（整屏列表 + 吸底记账条，`onExit` → 上一面板）；选择器里它仍可直达。
   - **medium（700~1024）**：有底栏走窄屏规则；工具行同时存在，两条入口并存，不冲突。
   - **深链**：`?section=` / `?accountId=` / `?action=expense` 全部不动。

## 5. 测试

- 改 `test/features/bookkeeping/presentation/bookkeeping_page_test.dart`：
  - 删掉三条浮层用例（`openNav` / 「导航默认不占页面流」/ 「点空白收起」/ 「浮层进分类页后连入口一起收起」里的浮层断言）。
  - 新增**回归断言**：页面里不再存在 `ValueKey('bookkeeping-nav-handle')`；流水首行「筛选」开关与「更多操作」的 `getRect` 不再与任何浮层重叠（可用 `hitTestOnBinding(center)` 直接验证命中）。
- 新增 `bookkeeping_panel_picker_test.dart`：8 项齐全、当前项高亮、选中写回 URL、提醒角标。
- 新增外壳侧两态用例（真 GoRouter，照搬 `/app/...` 层级，见 `plan_form_refresh_test.dart` 的写法）：
  - 在 `/app/home` 点底栏「记账」→ 直接落在上次 `?section=`；
  - 在 `/app/bookkeeping?section=accounts` 点底栏「记账」→ 出现选择器且 URL 不变。

## 6. 需要拍板

1. 底栏「记账」两态规则是否接受（建议必须两态）。
2. 宽屏入口用工具行 chip，还是宽屏继续保留浮层（宽屏右上角多为空白，伤害小得多）。
3. 选 A（弹层，省满 77px）还是 B（常驻 42px chip 行，一拍切换）。
