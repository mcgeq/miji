# 桌面小组件实施方案（Android 优先）

> 面向上游事实：`home_widget 0.10.0`（2026-09）、`home_widget_generator/cli 0.1.0`、`androidx.glance 1.2.0`（stable，minSdk 23）、本项目 Android `namespace = com.mcgeq.miji`、AGP 9.0.1 / Kotlin 2.3.20、iOS target 13.0。

## 实现状态（P0 · Android 已完成）

满宽「今日支出」已落地（默认 **5 格宽 × 2 格高，横贯屏幕一整行**；4 列桌面会被启动器夹回 4 格，同样满宽）：

| 层 | 文件 |
| --- | --- |
| Dart 快照 + 推送 | `lib/features/bookkeeping/application/money_home_widget.dart` |
| 点击 → 路由 | `lib/main.dart`（`_handleHomeWidgetUri` / 冷启动 `initiallyLaunchedFromHomeWidget`） |
| Android provider | `android/app/src/main/kotlin/com/mcgeq/miji/widget/MoneyWidgetProvider.kt` |
| 布局 / 配置 / 颜色 | `res/layout/money_widget.xml`、`res/xml/money_widget_info.xml`、`res/values{,-night}/colors.xml` |
| 测试 | `test/features/bookkeeping/application/money_home_widget_test.dart` |

**版面（四段，纵向按 weight 撑满）**：① 口径「今日支出」+ 右侧「N 笔 · 收入 ¥x」；
② 34sp 金额 + **124×48dp 的实心胶囊「＋ 记一笔」**；③ 一条发丝分割线（`ImageView`，
不能用裸 `View`）；④ 底部三等分**本周 / 本月 / 日均支出**（`formatMoneyMinorCompact`，
即 `¥2.3k` 这种）。`includeFontPadding="false"` 是为了让大字号不被行距撑爆。

**为什么金额区和统计区都要 `layout_weight`**：`minHeight=110dp` 只是启动器算格子的
下限公式，真实 2 格在 MIUI 5x6 / 各家 4x6 上普遍有 200dp 上下。全用 `wrap_content`
的话，多出来的高度会整块堆在底部 —— 表现就是「卡片很大，但下面一片空白」。
给金额区 `weight=2`、统计区 `weight=1`，多出来的高度被两者均摊进各自内部的居中留白，
上下左右都是对称的，视觉上是一张撑满的卡而不是一张上半截有内容的卡。

**两个点击目标，两个 PendingIntent**：按钮 → `miji:///app/bookkeeping?action=expense`
（记一笔），卡片其它区域 → `miji:///app/home`（首页）。`requestCode` 必须不同，
否则 `FLAG_UPDATE_CURRENT` 会让后绑定的覆盖先绑定的，表现为「按钮也打开首页」。
「看流水」和「记一笔」是两种意图，卡片有明确按钮之后就没必要让整块都跳表单了。

按钮用 `TextView` + `shape` 背景，不用 `Button`：`Button` 自带 minWidth / inset，
在 48dp 高里会被撑变形。

**与下面最初建议的三处偏离**：

1. **没上 Glance，改用 RemoteViews(XML)**。Glance 会给整个 app 模块引入 Compose 编译器（AGP 9.0.1 + Kotlin 2.3.20 的额外组合风险，以及每次全量构建变慢），而这张卡只有三段文本、零动画，XML 完全够用。等要做「预算环形进度 + 多尺寸」再评估。
2. **没用 `home_widget_generator`**。0.1.0 的原语表达不了想要的字号 / 间距，且生成物会覆盖手改内容；手写一个 provider 只有几十行。
3. **颜色暂时没跟用户选的九套配色**。RemoteViews 读不到 Flutter 的 `ThemeData`，P0 用一对中性的浅 / 深资源（`values-night`）；P1 可以把 `colorScheme.primary` 以十六进制塞进快照。

**尚未做**：iOS WidgetKit、预算 4x2、待办 4x2、申请精确跨天刷新（`scheduleWidgetUpdates`）、「一键添加到桌面」（`requestPinWidget`）。

## 0. 一句话结论

**小组件不是 Flutter 页面，Dart 代码不在里面跑。** 它是原生桌面视图（Android `RemoteViews` / iOS `SwiftUI`），只有"取数 → 画 → 点开 app"三件事。所以真正的工作量不在 UI，而在**数据怎么从 Dart 侧安全、及时地送到原生**。

## 1. 能力边界（先对齐预期，避免做到一半发现方向错）

| 能做 | 不能做 |
| --- | --- |
| 展示几个数字 / 一段进度 | 输入框、下拉、富交互（小组件没有可编辑控件） |
| 点击整块 → 深链进 app 某个页面 | 高帧率动画、实时图表 |
| 有限按钮（打勾、翻页），走 PendingIntent | 秒级刷新（系统最短 30 分钟） |
| 按尺寸给不同布局（2x2 / 4x2 / 4x4） | 在小组件里跑 Riverpod / 读 Drift |

结论：**"记一笔"不可能在小组件里完成**，只能"点一下直达记一笔页面"。想少一步，用长按图标的 App Shortcuts，而不是小组件。

## 2. 数据从哪来（一个必须现在就定死的决策）

| 方案 | 做法 | 判断 |
| --- | --- | --- |
| A. 原生直读 SQLite | Kotlin 打开 drift 的 db 文件自己查 | **否决**。双写者、schema v34 起每次迁移都要在两端同步、加密 key 也要搬；一次迁移就是线上崩溃 |
| B. 投影快照（推荐） | Dart 把"这张卡要的几个数"写进 `SharedPreferences`，原生只读这份 | 简单、可控、隐私口径能在 Dart 侧统一；代价是快照会旧，要靠刷新策略兜 |
| C. 后台 Dart isolate | `registerInteractivityCallback` 在点击时唤醒 Flutter engine | 冷启动 300ms~2s、内存翻倍。**只用于可容忍延迟的动作**（打卡勾选、待办完成），不要用于记账 |

选 **B**，快照里带 `snapshotDate`，让原生有能力判断"这份数据是不是今天的"。

## 3. 技术选型（Android）

| 组合 | 优点 | 代价 |
| --- | --- | --- |
| **`home_widget` + Jetpack Glance**（推荐） | 一套 Dart API 同时管 Android/iOS 的数据与刷新；Glance 是 Compose 风格 DSL，能写响应式尺寸 | app 模块要开 Compose（`buildFeatures.compose` + `kotlin.plugin.compose`），构建慢一点 |
| `home_widget` + RemoteViews(XML) | 不引 Compose，改布局只改 XML | 控件白名单很窄：没有 ConstraintLayout、没有自定义 View；圆角要走 shape drawable |
| `home_widget_generator`（0.1.0） | Dart 里写 schema，生成 Kotlin/Swift，**自动注册 Receiver、加 iOS extension、写 entitlements、抬 deployment target** | 原语有限（`HWColumn/HWText/...`），设计要求高时会被卡住；生成的代码重新生成会覆盖 |

建议路线：**P0 用 generator 跑通整条链路**（验证深链 + 刷新 + 隐私），**P1 再把要精修的那张卡手写成 Glance**。

## 4. Android 落地清单（手写 Glance 版）

### 4.1 依赖

```yaml
# pubspec.yaml
dependencies:
  home_widget: ^0.10.0
```

```kotlin
// android/app/build.gradle.kts
plugins {
    id("org.jetbrains.kotlin.plugin.compose")   // 版本随 Kotlin 2.3.20
}

android {
    buildFeatures { compose = true }
}

dependencies {
    implementation("androidx.glance:glance-appwidget:1.2.0") // minSdk 23
}
```

`minSdk` 目前取 `flutter.minSdkVersion`；若低于 23 就显式写 `minSdk = 23`。

### 4.2 配置文件 `android/app/src/main/res/xml/money_widget_info.xml`

```xml
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="320dp" android:minHeight="110dp"     <!-- 5 格宽 × 2 格高 -->
    android:targetCellWidth="5" android:targetCellHeight="2"
    android:resizeMode="horizontal|vertical"
    android:minResizeWidth="250dp" android:minResizeHeight="110dp"
    android:widgetCategory="home_screen"
    android:description="@string/money_widget_description"
    android:initialLayout="@layout/glance_default_loading_layout"
    android:updatePeriodMillis="1800000" />                <!-- 30 分钟，系统下限 -->
```

**要求是「宽度跟屏幕一样宽」，但两个尺寸属性各管一半启动器**，必须一起配：

- `targetCellWidth=5`：只有 **Android 12+ 且启动器实现了该属性**才生效（Pixel、新版 MIUI）。
  填 5 的用意是「超过网格列数时被夹回可用列数」，于是 4 列屏 → 4 列、5 列屏 → 5 列，都满宽。
- `minWidth=320dp`：**Android 11 及以下只看这个**，启动器按 `格数 = ⌈(minWidth + 30) / 70⌉`
  换算。MIUI 12.5（Android 11，小米 9 SE）就是这一类 —— 写 250dp 被算成 4 格，在 5 列桌面上
  只占 4/5，右边固定空一条。写 320dp 则 5 列满宽；退到 4 列桌面时公式算出 5 格 > 4 列，
  启动器夹回 4 格，同样满宽。

`minResizeWidth` 故意低于 `minWidth`（250dp）：默认满宽，但允许用户自己拖窄一档，
250dp 时 30sp 的金额仍然放得下。布局侧一律 `match_parent`，拖宽拖窄都铺满。

启动器仍会在卡片四周留自己的一点边距（MIUI 约 4~8dp），这层**不在 app 控制范围**，
不要试图用负 margin 去顶。

### 4.3 布局 + Receiver

```kotlin
class MoneyWidget : GlanceAppWidget() {
    override val stateDefinition: GlanceStateDefinition<*>?
        get() = HomeWidgetGlanceStateDefinition()   // home_widget 靠它把 prefs 送进来

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            val prefs = currentState<HomeWidgetGlanceState>().preferences
            val masked = prefs.getInt("mw_masked", 0) == 1
            val today = prefs.getString("mw_date", null)
            val isStale = today != LocalDate.now().toString()
            MoneyWidgetContent(prefs, masked, isStale)
        }
    }
}

class MoneyWidgetReceiver : HomeWidgetGlanceWidgetReceiver<MoneyWidget>() {
    override val glanceAppWidget = MoneyWidget()
}
```

清单注册（`exported="true"` 是必须的，否则桌面加不了）：

```xml
<receiver android:name=".widget.MoneyWidgetReceiver" android:exported="true">
    <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/money_widget_info" />
</receiver>
```

### 4.4 点击 → 深链（复用现有路由，不新造入口）

```kotlin
val intent = Intent(context, MainActivity::class.java).apply {
    action = Intent.ACTION_VIEW
    // 三斜线：host 为空，path 原样保留。写 miji://app/... 会被解析成 host=app、path=/bookkeeping
    data = Uri.parse("miji:///app/bookkeeping?action=expense")
    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
}
val pi = PendingIntent.getActivity(
    context, 0, intent,
    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
)
```

`MainActivity` 已经是 `singleTop`，热启动走 `onNewIntent`；Dart 侧：

```dart
final initial = await HomeWidget.initiallyLaunchedFromHomeWidget(); // 冷启动
HomeWidget.widgetClicked.listen((uri) => _go(uri));                 // 热启动
// uri.path == '/app/bookkeeping'，可直接 router.go('${uri.path}?${uri.query}')
```

好消息：`/app/bookkeeping?action=expense` **已经支持**（`bookkeeping_page.dart` 里的 `initialAction`，通知也在用），小组件不需要新增任何路由。

### 4.5 Dart 侧：快照写入

新建 `lib/core/home_widget/money_widget_sync.dart`：

```dart
Future<void> pushMoneyWidget(WidgetRef ref) async {
  final masked = ref.read(moneyAmountsMaskedProvider);
  final ledger = ref.read(currentUserCurrentLedgerValueProvider);

  // 查询口径跟流水页的 _summaryQuery 完全一致：当天 0 点到次日 0 点，不含转账。
  final now = DateTime.now();
  final summary = await ref.read(
    currentUserTransactionSummaryProvider(
      MoneyTransactionQuery(
        dateStart: DateTime(now.year, now.month, now.day),
        dateEnd: DateTime(now.year, now.month, now.day + 1),
      ),
    ).future,
  );

  await HomeWidget.saveWidgetData<int>('mw_masked', masked ? 1 : 0);
  await HomeWidget.saveWidgetData<String>('mw_date', _todayKey());
  await HomeWidget.saveWidgetData<String>('mw_ledger', ledger?.name ?? '');
  // 遮罩时**不写数值**，而不是写了再让原生遮
  await HomeWidget.saveWidgetData<int>('mw_expense_minor', masked ? 0 : summary.expenseMinor);
  await HomeWidget.saveWidgetData<int>('mw_income_minor', masked ? 0 : summary.incomeMinor);
  await HomeWidget.updateWidget(
    qualifiedAndroidName: 'com.mcgeq.miji.widget.MoneyWidgetProvider',
    iOSName: 'MoneyWidget',
  );
}
```

> **踩坑（真机上表现为「记完账卡面不刷新」）**：`updateWidget` 找 Receiver 走的是
> `Class.forName()`，**不做任何补全**。写成 `androidName: 'MoneyWidgetProvider'` 时，
> 插件会拼成 `<applicationId>.MoneyWidgetProvider`（即 `com.mcgeq.miji.MoneyWidgetProvider`），
> 而真实类在 `.widget` 子包里 → `ClassNotFoundException` → 插件返回
> `PlatformException(-3, No Widget found...)`。这种异常又会被 push 的 try/catch 吞掉，
> 于是「数据写进 SharedPreferences 了、卡面一动不动」，只有系统 30 分钟一次的周期刷新
> 才偶尔变一次。**Receiver 只要不在 applicationId 所在包下，就必须用
> `qualifiedAndroidName` 给全限定名。**

注意两个已经踩过的口径：`MoneyTransactionSummary` 只统计 `expense/income`、已扣退款、**不含转账**；预算那边"已用 + 已预留 == 预算"**不算超支**（严格大于才算）。小组件必须复用同一套判断，不能自己再算一遍。

## 5. 刷新策略（最容易被低估的一节）

| 时机 | 做法 | 备注 |
| --- | --- | --- |
| app 启动 / 回前台 | `AppLifecycleState.resumed` 时推一次 | 覆盖 90% 场景 |
| 数据变更 | 监听流水 / 预算 provider，**debounce 500ms** 再写 | 不要每次 insert 都写盘 |
| 系统定时 | `updatePeriodMillis = 1800000` | 系统会合并、doze 下不保证 |
| 跨天 | provider 渲染时比对 `mw_date` 与今天 | **不要承诺 0 点准时换数** |

跨天这条必须做进 UI：`isStale` 时显示「数据截至昨天 · 点开更新」，而不是把昨天的数字当成今天。国产 ROM 会杀后台，WorkManager / AlarmManager 都不值得押注。

## 6. 隐私与口径（本项目特有，做错就是事故）

1. **全局「隐藏金额」必须生效**：`moneyAmountsMaskedProvider` 为真时，快照里**根本不写真实数值**，只写 `mw_masked=1`。因为 `SharedPreferences` 是明文，写了真值再让原生遮，等于绕过了遮罩。
2. **单账户显隐不进小组件**：小组件只展示"我的当前账本"的聚合数字，不展示某个账户的余额——卡面那套三态显隐在几平方厘米里无法表达。
3. **收入隐私是独立开关**（`IncomePrivacyScope`，与金额遮罩正交）：小组件若要显示收入，必须同时受它约束。
4. **账户余额默认不上小组件**：桌面甚至锁屏可见，余额是全 app 最敏感的一个数。要做也做成默认关闭的开关。
5. 邀请/共享账本（`isShared`）：小组件只算自己可见的，不要拿共享账户撑场面。

## 7. 三个候选小组件（按性价比排序）

| # | 形态 | 内容 | 刷新触发 | 成本 |
| --- | --- | --- | --- | --- |
| 1 | 4x2 今日收支（满宽） | 今日支出（大）+ 收入（小）+ 记一笔按钮 | 记账后 / 回前台 / 跨天 | 低 |
| 2 | 4x2 预算 | 剩余额度 + 进度条 + 已用/预算（沿用"等于不算超支"的口径） | 记账后 / 改预算 / 跨月 | 中 |
| 3 | 4x2 今日待办 / 打卡 | 3 条 + 勾选 | 需后台 Dart 或直写库 | **高，放最后** |

先做 1，验证链路；2 是记账用户的刚需；3 涉及"小组件里写库"，只有接受 1~2 秒延迟才做。

## 8. iOS 与 Android 的差异（一页看完）

| 维度 | Android | iOS |
| --- | --- | --- |
| 技术 | Glance / RemoteViews + Kotlin | WidgetKit + SwiftUI，**独立 extension target** |
| 共享存储 | `SharedPreferences("HomeWidgetPreferences")` | App Group 的 `UserDefaults(suiteName:)`，需要 entitlement |
| 最低版本 | minSdk 23（Glance 1.2） | iOS 14+；**项目现在是 13.0，需要抬到 14** |
| 刷新 | 30 分钟下限 + 主动 update | 每天约 40~70 次，靠 `Timeline` 的 `.after` 排 |
| 尺寸 | 可任意 resize，需自适配 | 固定 small/medium/large，要做 3 套布局 |
| 交互 | PendingIntent 任意点击区域 | `widgetURL` + iOS 17 `AppIntents` 按钮 |
| 额外收益 | 无 | 锁屏小组件（`accessoryCircular` 等）免费多一种形态 |

`home_widget_generator` 会自动加 iOS target / entitlements / 抬 deployment target——这是它最值钱的地方；手写就要自己在 Xcode 里点一遍。

## 9. 验收清单

- [ ] 冷启动：桌面点「记一笔」按钮 → 直达记账表单；点卡片其它区域 → 首页；返回键回桌面而不是退出 app
- [ ] 热启动：app 已在前台，点按钮 / 点卡片不重启，分别切到记账表单 / 首页
- [ ] 数字变化后卡片不出现底部空白：把卡片改成 3 格高，内容仍均匀撑满（weight 生效）
- [ ] 记一笔 → 1 秒内小组件数字变化（`debounce` 后仍应 < 2s）
- [ ] 打开「隐藏金额」→ 小组件变 `••••`；关闭 → 恢复真实值
- [ ] 跨过 0 点不动数据：显示"数据截至昨天"，而不是昨天的数字冒充今天
- [ ] 深色模式 / 字体放大 1.3x / 满宽（4 列）与拖到最窄（`minResizeWidth`）都不溢出、不截断
- [ ] 4 列屏、5 列屏各加一次桌面，确认卡片都是**整行满宽**（`targetCellWidth=5` 被夹回）
- [ ] 空态（新账本、无流水）不显示 `¥0.00` 的假数据，而是引导记一笔
- [ ] 国产 ROM（MIUI / ColorOS / EMUI）加一次桌面，确认不会因为后台被杀而白屏
- [ ] debug & release（R8 开启）各验一次

调试命令：

```bash
adb shell dumpsys appwidget | grep -i miji     # 看有没有注册上、更新了几次
adb shell am broadcast -a android.appwidget.action.APPWIDGET_UPDATE \
  -n com.mcgeq.miji/.widget.MoneyWidgetReceiver
```

## 10. 工作量与风险

- Android P0（2x2 + 深链 + 刷新 + 遮罩）：**0.5~1 天**，含真机验证
- iOS 同款：**1~2 天**（大头是 Xcode target / App Group / 三套尺寸）
- 主要风险：① 把"实时"当预期（系统就是 30 分钟粒度）；② 快照与主界面口径分叉（遮罩、账本、预算"等于不算超支"必须同源）；③ 原生侧重复实现业务判断——**任何业务判断都应该在 Dart 侧算完再写快照**，原生只负责画。
