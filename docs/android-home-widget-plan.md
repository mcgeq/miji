# 安卓桌面小组件落地方案

> 状态：方案待拍板，未动代码。前置事实均在本仓库核实过，版本号来自 pub.dev。

## 一、结论速览

- **Flutter 画不了小组件**。AppWidget 渲染在桌面（Launcher）进程里，那里没有 Flutter 引擎。原生负责「长什么样」，Flutter 负责「显示什么」。
- 桥接用 **`home_widget`（0.9.3，Dart ≥3.5，本机 Dart 3.12.2 满足）**，不要自建 MethodChannel。自建的那部分它已经写好了，而且 iOS 侧以后能复用同一套 Dart 代码。
- **数据不直读 drift**。原生进程打不开我们那份加密/迁移过的数据库，正确做法是 Flutter 侧把「要显示的字符串」算好，写进 SharedPreferences，原生读出来直接塞进 RemoteViews。
- 工作量的大头在**原生**（1 个 Kotlin 类 + 2 个 XML），Dart 侧很薄（一个模型 + 一个同步器）。
- 三个必须提前想清楚的点，都在本项目的既有约束上：**多用户 / 锁屏**、**金额遮蔽开关**、**R8 裁剪**（第三点刚在 ML Kit 上踩过）。

## 二、为什么小组件不能用 Flutter 实现

这是最容易走弯路的地方，先说死：

| 事实 | 后果 |
|---|---|
| AppWidget 的视图树由 Launcher 进程渲染 | 我们的 Flutter 引擎根本不在那个进程里，`runApp` 不参与 |
| 视图只能用 `RemoteViews` | 只支持 `LinearLayout`/`RelativeLayout`/`FrameLayout`/`GridLayout` + `TextView`/`ImageView`/`Button`/`ProgressBar` 等**系统控件**，不能塞自定义 View |
| 所以「用 Flutter 写小组件 UI」这条路不存在 | 市面上所谓「Flutter 小组件」全是「原生写 UI + 桥接传数据」 |

`home_widget` 的 README 第一句就写了这句：*does not allow writing Widgets with Flutter itself*。

## 三、技术选型

| 方案 | 评价 |
|---|---|
| **`home_widget` 0.9.3** | **推荐**。社区标准（2.16K likes）。统一了「存数据 / 触发刷新 / 点击回调 / 交互式 widget 回调 Dart」四件事，Android 与 iOS 接口一致。Android 侧仍要自己写 Provider，但它提供了 `HomeWidgetProvider` 基类，把「读 SharedPreferences + 遍历 appWidgetIds」这段模板代码省了 |
| 自建 MethodChannel + `AppWidgetProvider` | 不建议。能省一个依赖，但要自己维护消息格式、共享存储键名约定、点击回传协议，且 iOS 侧要再写一遍 |
| `flutter_widgetkit` | 仅 iOS，与需求不符 |
| `live_activities` | 面向 iOS 灵动岛，Android 侧支持有限，不是常规桌面小组件 |

引入方式：`flutter pub add home_widget`（会带进 `path_provider`，项目已有）。

## 四、架构：一次数据流

```
   触发点（四类，见 §7.4）
        │
        ▼
   Dart 侧算出 HomeWidgetSnapshot
   · 已格式化的金额字符串（用现有的 formatMoneyMinor / formatMoneyMinorCompact）
   · 已算好的遮蔽结果（mask = true 时这里就是 "••••"）
        │
        ▼
   HomeWidget.saveWidgetData<String>('snapshot', json)
   HomeWidget.updateWidget(name: 'MijiHomeWidgetProvider')
        │  写入 SharedPreferences（跨进程可读）
        ▼
   MijiHomeWidgetProvider（Kotlin，桌面进程）
   · 读 'snapshot' → 反序列化
   · 拼 RemoteViews → appWidgetManager.updateAppWidget(...)
```

**一条硬原则：金额格式化只在 Dart 侧做一次。**
项目里已有 `formatMoneyMinor` / `formatMoneyMinorCompact`（货币符号、本地化、千分位、紧凑写法）。如果让 Kotlin 再格式化一遍，就等于把这份规则抄成两份，第一次改货币符号就会两边不一致。Dart 侧输出的是**给人看的字符串**，原生只负责摆位置。

### 快照模型（草案）

```dart
class HomeWidgetSnapshot {
  final bool available;      // false = 未登录 / 未解锁 / 没有账本，原生显示占位文案
  final String title;        // 「本月支出」
  final String primaryText;  // 「¥1,234.56」
  final String? secondaryText; // 「收入 ¥500 · 结余 +¥734」——可为空，小组件高度不同时降级
  final String updatedLabel; // 「12:30 更新」
  final DateTime generatedAt;
}
```

序列化成一个 JSON 字符串塞进同一个键，**不要拆成多个键**：多个键在跨进程写入时可能读到「新的一半 + 旧的一半」，拼出来的数字是错的。

## 五、要新增 / 改动的文件

### Android 侧

| 文件 | 作用 |
|---|---|
| `android/app/src/main/kotlin/com/mcgeq/miji/miji/MijiHomeWidgetProvider.kt` | 继承 `HomeWidgetProvider`，override `onUpdate(context, manager, ids, widgetData)` |
| `android/app/src/main/res/layout/miji_home_widget.xml` | RemoteViews 布局。**只能用系统控件**，不能用 ConstraintLayout |
| `android/app/src/main/res/xml/miji_home_widget_info.xml` | `minWidth` / `minHeight` / `targetCellWidth` / `updatePeriodMillis` / `initialLayout` / `resizeMode` |
| `android/app/src/main/res/drawable/widget_background.xml` | 圆角背景（shape + corners） |
| `android/app/src/main/AndroidManifest.xml` | 注册 `<receiver>` + `<meta-data android:name="android.appwidget.provider">` |
| `android/app/proguard-rules.pro` | 加 keep 规则（见 §7.3） |

小组件尺寸建议从 **4×2**（宽 250dp × 高 110dp）起步：够放标题 + 大数字 + 一行副文本 + 一个按钮，又不会占满半屏。

### Flutter 侧

```
lib/core/homescreen_widget/
  widget_snapshot.dart   # 模型 + toJson/fromJson（纯 Dart，可单测）
  widget_sync.dart       # 组装快照 → 存 → 触发刷新
  widget_providers.dart  # Provider 装配 + 监听触发条件
  widget_click.dart      # 冷启动/热启动的点击路由处理
```

新增依赖只有 `home_widget` 一个。

## 六、展示什么（三个候选，可组合）

| 方案 | 形态 | 内容 | 评价 |
|---|---|---|---|
| **A · 行动型** | 4×1 / 2×1 | 一个大按钮「记一笔」+ 一行本月支出 | 最实用。小组件的核心价值是**降低记账的启动成本**，不是看报表 |
| **B · 概览型** | 4×2 / 2×2 | 本月支出（大数字）+ 收入 + 结余 | 数据源现成：`currentUserTransactionSummaryProvider` + `MoneyTransactionQuery(dateStart: 月初, dateEnd: 今天)` |
| **C · 预算型** | 2×2 | 预算使用进度条 + 剩余金额 | 依赖预算模块，进度条在 RemoteViews 里用 `ProgressBar` 能做 |

**建议：先做 B 的外壳 + A 的按钮**（4×2 里上面放数字、下面放「记一笔」），也就是一个「看一眼 + 一步记账」的组合。C 留到有明确需求再做。

点击行为：

- 点小组件空白处 → 打开 App 到首页（`/app/home`）；
- 点「记一笔」按钮 → 直接进记账（`/app/bookkeeping`）。
- 实现：`MainActivity` 是 `singleTop`，用 intent extra 带一个路由串；Flutter 侧在启动与恢复时读 `HomeWidget.initiallyLaunchedFromHomeWidget()` / `HomeWidget.widgetClicked`，再交给 `go_router`。

## 七、必须提前想清楚的五个坑

### 7.1 多用户与锁屏

这个 App 有登录态（`authSessionControllerProvider` 的 `isUnlocked` / `userId`），而小组件在**进程之外**渲染，拿不到任何 Riverpod 状态。

- 快照里必须有 `available` 字段。**未登录 / 未解锁 / 没有账本时必须写 `available: false`**，原生显示「打开 App 查看」而不是上次的残留数字——否则锁屏后桌面上还挂着上一位用户的金额。
- 登出、锁定、切换用户这三个动作**都要主动推一次快照**（推空），不能只在记账后推。

### 7.2 金额遮蔽（`maskMoneyAmounts`）

项目已有 `userPreferences.maskMoneyAmounts` 这个开关，记账页面会据此打码。

**遮蔽必须在 Dart 侧完成**：开关为真时，写进 SharedPreferences 的就是 `"••••"`，真实金额**根本不落盘**。不要在原生侧拿到真值再打码——那样金额已经明文躺在共享存储里，遮蔽就只是表演。

### 7.3 R8 会裁掉小组件的类（本项目刚踩过同类坑）

release 包开了 `isMinifyEnabled`，R8 看不见「系统通过反射/清单实例化 receiver」这条路径，会把 Provider 类或它的静态字段裁掉，**表现为 debug 正常、release 上桌面上根本找不到小组件**。

`proguard-rules.pro` 要加：

```proguard
-keep class com.mcgeq.miji.miji.MijiHomeWidgetProvider { *; }
-keep class * extends android.appwidget.AppWidgetProvider { *; }
```

另外 `home_widget` 内部用一个静态 `JobIntentService` 回调 Dart，也要保：

```proguard
-keep class es.antonborri.home_widget.HomeWidgetBackgroundIntentService { *; }
```

> 排查手法同 ML Kit 那次：`build/app/outputs/mapping/release/usage.txt` 看谁被删了。

### 7.4 刷新时机（`updatePeriodMillis` 不可靠）

`updatePeriodMillis` 最小 30 分钟，且系统会合并、延迟、在低电量时干脆跳过。**不能指望它**。要靠这四个主动触发点：

1. **记账保存成功后** —— 最关键，用户刚记完就想看到数字变了；
2. **App 冷启动 / 从后台恢复**；
3. **登录、登出、解锁、切换用户**；
4. **WebDAV 同步完成**（另一台设备改过的数据过来了）。

如果以后确实要「App 没打开也能刷新」，再引 `workmanager` 定时唤醒。那是第二阶段的事，第一版不要。

### 7.5 其它细节

- **深色模式**：RemoteViews 可以按 `uiMode` 取不同资源，但更省事的做法是快照里带一个 `isDark` 字段，直接给两套颜色。
- **圆角**：Android 12+ 会按 `system_app_widget_background_radius` 自动裁切，自定义背景要用 `@android:dimen/system_app_widget_background_radius`，别写死成 8dp。
- **字体**：RemoteViews 里不能改字体族，只能用系统默认。数字想醒目只能靠 `setTextViewTextSize`。
- **多语言 / 货币**：都由 Dart 侧格式化好了，原生不管。

## 八、落地批次

| 批次 | 内容 | 产出 |
|---|---|---|
| **W1 · 骨架** | 引 `home_widget`；写 Kotlin Provider + 两个 XML + manifest 注册；Dart 侧写死一个假快照推过去 | 桌面上能看到小组件，点击能打开 App |
| **W2 · 真数据** | `HomeWidgetSnapshot` + `widget_sync.dart`；接上 `currentUserTransactionSummaryProvider`；记账保存后触发刷新 | 数字是真的，记完账立刻变 |
| **W3 · 隐私与多用户** | `available` / 遮蔽 / 登出与锁定时推空快照；R8 规则 | 换用户、锁屏、开发选项都不露金额 |
| **W4 · 打磨（可选）** | 深色模式、尺寸自适应、第二套形态（预算）、`workmanager` 后台刷新 | — |

W1 到 W3 是「能上线」的最小集。W1 的绝大部分时间花在原生，Dart 侧那部分很短。

## 九、待拍板

| # | 问题 | 建议 |
|---|---|---|
| 1 | 小组件形态选 A / B / C 还是组合 | **B 的外壳 + A 的按钮**（4×2） |
| 2 | 是否现在就引 `workmanager` 做后台定时刷新 | **不引**。第一版靠四个主动触发点足够，App 不打开时数据本来也没变 |
| 3 | 是否为 iOS 小组件预留结构 | **预留 Dart 侧结构即可**（快照模型与同步器不区分平台），iOS 原生部分不做——那边现在连 Podfile 都没有，构建都不通 |
| 4 | 点击「记一笔」是否要求先解锁 | **要求**。`/app/bookkeeping` 在 `AppRoutes.sensitiveRoutes` 里，深链不能绕过锁屏 |

## 十、成本与风险

- **成本**：W1–W3 一次性投入，主要花在原生的 XML 布局调试与 R8 上（后者有前车之鉴，规则先写好就不容易再踩）。
- **风险**：低。小组件是纯增量功能，失败最坏情况是「桌面上的小组件不更新」，不会影响 App 本身。
- **唯一的长期负担**：多了一处「必须记得在数据变化时推快照」的接线点。建议把它收在 `widget_sync.dart` 一个入口里，而不是散在各个写流水的地方。
