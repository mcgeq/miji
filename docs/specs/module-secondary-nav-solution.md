# 模块内导航（二级路由）：统一记账 / 打卡 / 健康

> 配套可视稿：`docs/specs/bookkeeping-nav-mockup.html`（切现状 / 方案 A / 方案 B，手机与宽屏、深浅主题、标注开关）。
> 本文是三个模块统一后的定稿：判断依据、最终形态、落地清单、测试点。

## 0. 一句话结论

**「二级路由」不是新造路由层级，而是把面板做成模块根地址上的一枚 `?section=`，并让三个模块共用同一套唤出入口。**

- 三个模块的**顶部 tab 行全部删除**，统一成「工具行面板 chip + 底栏两态唤出」；
- 记账：内容区里的浮层入口**删除**（它遮挡且点不到，还白占 77px）；
- 打卡 / 健康：原先各有一枚横贯顶部的分段控件（5 段 / 4 段），现在同样收成一枚 chip；
- 三者的「面板选择器」是同一个组件，唤出方式也统一（见 §3）。

## 1. 问题定位（记账，P0）

上一版把横贯顶部的 8 项 tab 行（61px + 16px 间距 = 77px）收成右上角一颗浮层胶囊：

```dart
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

横向几乎完全重合（胶囊右边缘与「筛选」开关右边缘对齐），纵向压住首行上半 24px。更关键的是 `Stack` 的子节点顺序决定命中测试顺序：胶囊排在内容之后 → 该区域点击先命中胶囊，**不是「看不全」，是「点不到」**。8 个面板中 7 个中招（只有「分类」因整排收起而幸免）。

打卡有同类但更轻的毛病：它的页内分段控件与页级动作同排，5 段 × 52px 最小宽 = 260px 挤在 360 屏的可用宽里，加上「习惯」面板的 2 个动作按钮会顶到 260px 的横向滚动兜底 —— 末位「统计」在视口外。

健康也一样：4 段 × 68px = 272px 独占了工具行，而这一行本来没有任何别的内容（它存在的唯一理由就是那排 tab）。

## 2. 对「改成二级路由」的判断

**方向对，但「二级路由」不是要新造的东西。**

`/app/bookkeeping?section=xxx` 已经是可寻址的二级视图，且有 6 个深链调用方（首页 3 处、通知、分期、提醒）——保留 query，这些一处都不用改。

真把面板拆成同级 path 路由（`/app/bookkeeping/accounts` …）要额外付两笔代价：

1. **面板保活失效。** 现在靠 `_LazyBookkeepingPanelStack` + `Offstage` + `_loadedPanels` 让 8 个面板常驻，切走再切回不重建、不丢滚动位置与筛选条件。换成同级路由后每个面板各自 `pageKey`，`_BookkeepingPageState` 连同 `_loadedPanels` 一起重建，只剩当前面板。
   > go_router 的 `pageKey` 由命中路由的 **path** 拼出、不含 query（`match.dart` 里 `ValueKey(newMatchedPath)`），所以 `?section=` 变化时同一个 `pageKey`，页面 State 原样存活；这也是这次能「只换入口不动路由」的前提。
2. **`?action=expense`、`?accountId=` 这类「进模块顺带执行动作」的参数**没有自然落点，`initialAction` 的两段式消费逻辑要跟着改。

另一条硬约束：**面板之间目前只有单向通路**（账户/预算/统计的 `onViewTransactions` 回流水，彼此不通）。所以新入口必须**一次给出全部面板**，否则删掉旧 tab 后会留下死胡同。

## 3. 统一后的形态

### 3.1 一张表

| 模块 | 面板 | 地址 | 窄屏入口 | 宽屏入口 | 页内还有 tab 行吗 |
|---|---|---|---|---|---|
| 记账 | 8 | `/app/bookkeeping?section=` | 底栏「记账」两态 | 工具行左端面板 chip（chip + 账本选择器同排） | 没有（浮层也删了） |
| 打卡 | 5 | `/app/gtd?section=` | 底栏「打卡」两态 | 工具行左端面板 chip（chip + 本面板动作同排） | 没有（原 5 段控件已删） |
| 健康 | 4 | `/app/health?section=` | 底栏「健康」两态 | 工具行左端面板 chip | 没有（原 4 段控件已删） |

**为什么最后是 chip 而不是「放得下就留着」**：一开始按「放得下就留着」保留了打卡 / 健康的分段控件，但那个判据只在**单看一个页面**时成立。放进整个应用看，模块之间的形态不一致本身就是负担——同一个「面板切换」，记账是 chip、打卡是 5 段、健康是 4 段，用户每换一个模块都要重建一次心智模型。何况分段控件在窄屏确实会挤：打卡 5 段 260px 已经在横滚兜底边缘，健康 4 段 272px 更是独占了整条工具行。

chip 只占一个按钮宽（图标 + 面板名 + ▾），却把分段控件最要紧的两件事原样留下：**当前面板名常驻**（三个模块的面板自身都没有标题栏，chip 是唯一的「我在哪」标识）和**一拍点开选择器**。窄屏再多一条底栏两态唤出，两条通路指向同一张选择器。

### 3.2 两态规则（三个模块一致）

| 当前所在 | 点底栏 / 侧栏的该模块 | 结果 |
|---|---|---|
| 不在这个模块里 | 底栏「记账」 | **直接进**，落到上次停留的面板（首次为默认面板） |
| 已在该模块**根**上 | 底栏「记账」（高亮项） | **弹出面板选择器**，地址不动 |
| 在该模块的**子页面**里（如 `/app/gtd/plans/create`） | 底栏「打卡」 | 退回模块根（带记忆的面板） |

两态是刻意的：「点记账 = 进记账」是最高频的动作（从首页/打卡切回来），若每次都弹层，切模块就从 1 拍变成「1 拍 + 一次打断 + 1 拍」。只在「已经在这个模块里再点它」时弹层，正是 iOS「点当前 tab」的惯例。

同一套两态在**宽屏侧栏**上同样成立（宽屏没有底栏，侧栏就是它的底栏）。

### 3.3 面板选择器（三模块共用）

`showAppModuleSectionPicker`：窄屏从底部升出、宽屏居中弹窗，复用同一个 `showAppResponsiveDialog`，只有一份内容布局。

- 4 列网格，8 个面板两行收完；每格＝图标 + 名称，当前项 `primaryContainer` + 加粗；
- 可挂角标（目前只有记账的「提醒」用：待处理提醒数，挂在图标上而不是名称上，否则「自动记账」会被挤成省略号）；
- 面板清单来自 `appModuleNavSpecs`（唯一真相），外壳、页面、选择器都从这里取数。

### 3.4 「上次停在哪个面板」怎么记

**URL 就是真身**：模块内每次换面板都写回 `?section=`，所以外壳只需要在**离开模块之前**从当前地址拍一张快照（`AppModuleLastSection.rememberUri`）。不需要让页面反过来通知外壳，也不需要额外的状态同步。

顺带修掉一个既有退化：以前从首页点「记账」走的是不带 section 的地址，面板会被重置回流水；现在会回到上次的面板。

### 3.5 为什么统一是「工具行 chip」

`prefersRailNavigation = isExpanded || 桌面平台` —— 桌面窄窗也是 rail，**没有底栏**。所以三个模块在宽屏都必须有页内入口，落点就是**本来就有**的工具行：

- 记账：chip + 账本选择器（这一行原本就存在）；
- 打卡：chip + 本面板的页级动作（这一行原本就存在，动作数量跟着面板走）；
- 健康：只有 chip（原来这条行整条都是分段控件的，删掉后行高降到一枚 chip 高度）。

chip 不覆盖任何内容、也不新开一行——这正是它取代那颗浮层胶囊、以及取代那两排行内 tab 的原因。窄屏同样保留这枚 chip：打卡 / 健康的工具行本来就要渲染页级动作（打卡）或本来就有这行（健康），chip 放进去不额外占高度，还顺手补上了「我在哪」的标识。

## 4. 落地清单（已实现）

| 文件 | 改动 |
|---|---|
| `lib/core/router/app_module_nav.dart`（新增） | `AppModuleSection` / `AppModuleNavSpec` / 三个模块的清单；`resolveSectionId`（含 `more` 旧 id 兼容）、`uriFor`、`owns` / `isRootOf`；`resolveModuleEntry`（两态落点判定，纯函数便于单测）；`appModuleLastSectionProvider`（会话态记忆） |
| `lib/core/presentation/components/app_module_section_picker.dart`（新增） | `showAppModuleSectionPicker` / `openAppModuleSection` / `AppModuleSectionChip` |
| `lib/features/shell/presentation/app_shell_page.dart` | 底栏与侧栏都改走 `_openModule`：先 `rememberUri` 拍快照，再按 `resolveModuleEntry` 决定「进」还是「弹选择器」；选择器角标由外壳按模块补（记账的提醒数来自记账 provider，core 不认识业务） |
| `lib/features/bookkeeping/presentation/bookkeeping_page.dart` | 删掉 `_BookkeepingNavBubble` / `_BubbleHandle` / `_BubblePanel` / `_NavPanelItem`、`_navOpen`、阻尼层、`hidePrimaryNav`（约 180 行）；页面退回纯 `AppPageFrame(Column)`；宽屏工具行＝面板 chip + 账本选择器；面板元数据改用共享 spec |
| `lib/features/gtd/presentation/gtd_page.dart` | 删掉 5 段分段控件，换成工具行 chip；加 `initialSection`、`didUpdateWidget`、`_syncSectionToUrl`；顺手修掉宽屏点分段会崩的问题（`_buildSelectedTab()` 分支没有 PageView，控制器没挂上时 `jumpToPage` 会断言失败，现在判 `hasClients`） |
| `lib/features/health/presentation/health_page.dart` | 删掉 4 段分段控件（那一条工具行整条消失，只留 chip）；加 `initialSection` / `didUpdateWidget` / `_syncSectionToUrl` |
| `lib/core/router/app_router.dart` | 给 `GtdPage` / `HealthPage` 传 `state.uri.queryParameters['section']` |

不动的东西：`?section=` 的 6 个深链调用方、`?action=expense` / `?accountId=`、分类面板自己的返回顶栏、面板懒加载与保活。

## 5. 测试

| 文件 | 覆盖 |
|---|---|
| `test/core/router/app_module_nav_test.dart`（新增） | 清单完整性、旧 id 兼容、非法 section 退默认、`owns` / `isRootOf`、两态落点判定、记忆的写入与去重 |
| `test/core/presentation/components/app_module_section_picker_test.dart`（新增） | 窄屏底部 / 宽屏弹窗两种形态、当前项高亮、返回值、关闭返回 null、角标、三模块都能渲染 |
| `test/features/shell/app_shell_navigation_test.dart`（新增） | 真 GoRouter + 真外壳：进模块 1 拍、在模块根上再点弹层且地址不动、选面板写回 URL、切走再切回回到原面板、宽屏侧栏同一套 |
| `test/features/bookkeeping/presentation/bookkeeping_page_test.dart` | 删掉浮层用例；新增**回归**「页面不再有任何浮在内容上的导航」+「筛选开关真的能点开」；新增宽屏 chip 打开选择器、选完写回 URL、分类页返回回到原面板 |
| `test/features/gtd/presentation/gtd_page_test.dart` | 改用真 GoRouter；**回归**「顶部不再有 tab 栏」（断言页面里没有 `AppSlidingSegmentedControl`）+ chip 常驻面板名 + 选择器一次列全 5 个面板；深链落位、换面板写回 `?section=`、非法 section 退默认、每个面板的页级动作在手机宽度下不溢出 |
| `test/features/health/presentation/health_page_section_test.dart`（新增） | 同样先断言「顶部不再有 tab 栏」；深链落位、换面板写回 `?section=`、非法 section 退默认 |

注：健康测试只走「今日 ↔ 趋势」。日历面板会开一批长生命周期的 drift 流，测试结束时 `database.close()` 等它们取消会一直不返回（与本次改动无关的既有现象）；健康「设置」面板的数据源在空库下取 `watchSingle()`，测试环境里会一直停在 loading，也无法断言内容。

## 6. 备选（未采用）

**方案 B**：不引入弹层，内容区顶部放一条 32px 可横滚 chip 行（8 项文字 chip，当前项 `primaryContainer`）。好处是常驻可见、一拍切换，代价是只省回一半高度、与面板页头自带的分段控件视觉重复、390 宽下要横滚才看得全 8 项。选 A 的理由是弹层只在「要换面板」时才出现，日常动线（切模块）保持 1 拍。

**保留浮层只换位置**（挪右下 / 挪正中 / 随滚动淡出）都不成立：`Stack` 覆盖 + 命中优先的本质没变，只是把「遮挡谁」换个对象。
