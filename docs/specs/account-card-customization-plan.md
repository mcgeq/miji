# 记账账户卡片个性化改造方案（分析稿，未实施）

> 目标：账户卡片支持自定义背景颜色、背景图片、账户图标等个性化能力。
> 本文只做分析与方案设计，不包含代码改动。

## 一、现状分析

### 1.1 数据层

- 表 `money_accounts`（`lib/core/database/tables/money/money_account_tables.dart`，当前 schemaVersion 33）已有两个外观字段：
  - `color TEXT NULL` —— 存 hex 字符串（如 `'#0EA5E9'`）
  - `icon TEXT NULL` —— 存 Material 图标名（如 `'payments'`）
- `MoneyAccountEntity` / `MoneyAccountDraft` / `MoneyAccountUpdate` 均已携带 `color` / `icon`。
- Repository 侧 `createAccount` / `updateAccount` 已透传两字段；同步日志 `_accountDraftSyncFields` / `_accountUpdateSyncFields` 也已包含 `color` / `icon`。

**发现的问题：**

1. **icon 字段"存而不用"**：`_AccountIcon`（money_accounts_section.dart:2335）渲染时直接调 `accountIconDataForType(account.type)`，完全忽略 `account.icon`。表单提交时 `icon: defaultAccountIconForType(_type)` 写的也是类型默认值。即用户没有任何途径真正自定义图标。
2. **color 与"背景色"语义混用**：当前 `color` 是"标识色"（图标底色、图表分布色），不是卡片背景。若直接拿它当背景，会改变所有现有页面的观感（统计图、账户选择器都依赖它做品牌色）。两者应分开。
3. **无背景图能力**：表内无图片路径字段；表单只有 `AppColorPickerField`（15 个预设色），无图片入口。

### 1.2 展示层

- 账户卡 `_AccountTileContent`（money_accounts_section.dart:1824）：`AppListItemPanel`（纯主题色底）→ 图标行 → 余额行 → 信用额度条 → 逾期提示。三行紧凑结构，信息密度已调优过（注释明确说明是从 8 层堆叠压缩而来）。
- 净资产卡 `_NetWorthHero`（:823）已有**渐变卡先例**：`AppHeroGradient`（ThemeExtension，含 linear 渐变、onColor 前景色、shadow），文字用 `onColor` 保证对比度 —— 这就是自定义背景卡可以复用的成熟范式。
- 图标渲染 `AppListItemIcon`（app_list_item.dart:53）：`color.withValues(alpha: 0.12)` 底 + 同色边框 + 同色 icon，42px。
- 账户列表为单列 `ListView.separated`。
- 其他展示位：`account_selector.dart`（记账时选账户）、统计分布图、交易流水行，均按 type 图标 + accentColor 渲染，改动图标渲染时要保持一致。

### 1.3 可复用的基础设施

- **`image_picker` 已在依赖中**（pubspec.yaml:61），头像（settings_page.dart:510）、GTD 打卡、OCR 均在用，且有"选图 → 拷进私有目录 → 更新引用 → 删旧文件"的完整先例。
- **`AttachmentStore`（lib/core/attachments/）** 已提供：
  - `importFile()` 收编外部文件，返回**相对路径**（规避 iOS 沙盒容器路径变更问题）
  - `resolveStoredPath()` / `existingFile()`（文件丢失返回 null 而非抛异常，适合兜底）
  - `deleteStored()` 原子删除
- **⚠️ 关键约束**：`attachment_store.dart` 注释明确"附件文件本身不参与同步"。即背景图只在写入设备本地存在；多端同步时另一台设备能拿到路径但拿不到文件。方案必须以 `existingFile()` 失败 → 回退背景色/默认样式来兜底。
- **迁移模式成熟**：`app_database.dart` 的 `onUpgrade` 已有 30+ 次 `if (from < N) migrator.addColumn(...)` 先例。

## 二、设计方案

### 2.1 数据模型（schemaVersion 33 → 34）

`money_accounts` 新增三列（分开建列而非 JSON 字段，是为了贴合现有 sync `changedFields` 的逐字段 diff 机制 `_putIfChanged`）：

| 列 | 类型 | 语义 |
|---|---|---|
| `background_style` | TEXT NULL | `default` / `color` / `image`，区分"未设置"与"已清空" |
| `background_color` | TEXT NULL | 卡片背景色 hex（与既有 `color` 标识色语义分离） |
| `background_image` | TEXT NULL | 背景图相对路径（AttachmentStore 存储） |

- `MoneyAccountEntity` / `MoneyAccountDraft` / `MoneyAccountUpdate` 增加对应三字段。
- `_mapAccount`、`createAccount`、`updateAccount`、`_accountUpdateSyncFields` 同步透传；sync 字段名用 `background_style` / `background_color` / `background_image`。
- 迁移：`if (from < 34) { migrator.addColumn(moneyAccounts, moneyAccounts.backgroundStyle); ... }`，随后 `dart run build_runner build`。

### 2.2 图标：预置图标目录，让 icon 字段真正生效

- 新建 `AccountIconCatalog`（建议放 `lib/features/bookkeeping/presentation/accounts/account_icon_catalog.dart`）：
  - 预置 30~40 个精选 Material Symbols（钱包/银行卡/公交/房产/医疗/教育/游戏…按消费场景分组）；
  - `IconData? forName(String?)`，查不到回退 `accountIconDataForType(type)` —— 存量数据（icon 列全是类型默认值）天然兼容。
- `_AccountIcon` 改为优先读 `account.icon`。
- `AccountFormDialog` 新增图标选择入口：横向网格 bottom sheet（按分组展示），当前类型默认图标置顶标注"推荐"。
- **不建议支持上传图片当图标**：小尺寸圆角方块里用户照片辨识度差、还要再做一套缩略图管线，收益低。预置图标集是记账类 App（钱迹/随手记等）的通行做法。
- 一致性：`account_selector.dart`、统计分布图等位置同步改用"icon 字段优先"的同一个解析函数，避免卡片和选择器图标不一致。

### 2.3 卡片背景渲染：新组件 `AccountCardContainer`

替换 `_AccountTileContent` 最外层的 `AppListItemPanel`，按 `background_style` 分三种渲染：

1. **default**：维持现有 `AppListItemPanel` 样式，零回归。
2. **color**：仿 `_NetWorthHero` 范式 —— 以 `background_color` 生成柔和渐变（`color` → `color.withValues(alpha/明度收窄)` 两端）+ 同色系阴影；文字/金额用 `appOnColor(color)` 或新增 onColor 求值函数保证 ≥4.5:1 对比度。信用额度条、逾期提示、`MoneyAmountTone` 的配色在此模式下切换为 onColor 系。
3. **image**：`DecorationImage(Image.file, fit: cover)` + **主题感知 scrim**（亮色主题白色渐变遮罩、暗色主题黑色渐变遮罩，遮罩 alpha 约 0.55~0.72 自下而上），保证任何图片上文字可读；金额隐藏态、额度条颜色同 image 模式的 scrim 上取色策略。

**兜底链**（所有展示位共用）：`image 文件存在？→ 用图` : `background_color ?→ 用色` : `default`。文件丢失静默降级，不报错（对齐 `existingFile()` 的设计意图）。

隐私与多端：背景图不同步，另一端自动降级为背景色 —— 在表单里用 helper 文案说明"背景图仅保存在本设备"。

### 2.4 表单改造 `AccountFormDialog`

- 顶部新增**实时预览卡**：用当前表单状态（名称/类型/图标/背景）渲染一张真实 `_AccountTileContent`，所见即所得。
- 新增「外观」分组：
  - 图标：`AccountIconPickerField`（打开图标网格 sheet）；
  - 卡片背景：三选 segmented（默认 / 纯色 / 图片）；
    - 纯色 → 复用 `AppColorPickerField`（可考虑为背景场景扩充一组浅色/低饱和 section，避免深色底压不住文字）；
    - 图片 → `ImagePicker().pickImage(source: gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 80)` → `AttachmentStore.importFile(userId, sourcePath)` 存相对路径；支持"移除图片"。
  - 更换背景图成功后删除旧文件（参照 settings 头像的 `_deleteAppOwnedAvatarIfNeeded` 模式）；取消表单不落库，故 import 应延迟到 `_submit` 之后或采用"先暂存拾取路径、提交时才收编"的策略，避免每次打开表单都产生孤儿文件。
- `MoneyAccountDraft` / `MoneyAccountUpdate` 增加三字段，`_submit` 透传。

### 2.5 图片生命周期

| 场景 | 处理 |
|---|---|
| 更换背景图 | 新图 import 成功后 `deleteStored(旧相对路径)` |
| 清除背景图 | `deleteStored` + 置 `background_image = null`（style 按用户选择回 color 或 default） |
| 删除账户 | 软删除，背景图文件**保留**（对齐"软删可恢复"语义；文件清理可留给未来的维护任务） |
| 读取失败 | `existingFile()` null → 渲染降级链（2.3） |

### 2.6 性能

- 列表可能同时渲染多张图卡：选图即压到 1024px/quality 80，单图体积可控；`Image.file` 走默认 ImageCache。
- 二期可再压缩到卡片实际显示尺寸的缩略图（卡片高约 120px，2x 屏 512px 足够），当前先不做。
- 图片用 `gaplessPlayback: true` 避免流式刷新闪烁。

### 2.7 测试要点

- 单测：`_mapAccount` 三新字段往返、`updateAccount` 只改背景字段时 sync `changedFields` 正确、迁移测试（33→34 加列）。
- Widget：卡片三态渲染（default/color/image）、image 文件缺失降级、scrim 上金额隐藏态可读性。
- 表单：图标选择回填、背景图拾取-取消-提交路径无孤儿文件。

## 三、实施分期

- **P1（核心）**：迁移 + Entity/Repository/同步字段 + 图标目录与解析函数 + `AccountCardContainer` 三态渲染 + 表单（图标选择、背景色、背景图）。
- **P2（一致性）**：账户选择器 / 统计分布图 / 流水行的图标统一走 icon 字段；浅色系预设色扩充。
- **P3（打磨）**：渐变预设（一次选一组两端色）、图片缩略图管线、暗色主题 scrim 调优。

## 五、追加扩展：自定义图片 / SVG 图标（P2.5，已实施）

在预置图标集之外，`icon` 字段再支持用户自己的图片或 SVG：

- **存储格式**：无新列、无迁移 —— `icon` 存 `file:<附件相对路径>`，前缀区分两种来源（无前缀 = Material 图标名，历史数据天然兼容）。`knownAttachmentExtensions` 补了 `svg` / `image/svg+xml`。
- **选图**：走 `file_selector`（新增依赖）而非 image_picker —— 相册选择器通常不给 SVG，而矢量恰是自定义图标的理想素材；接受的扩展名 png/jpg/jpeg/webp/gif/svg。文件经 `AttachmentStore.importFile` 收编，表单会话清理规则与背景图一致（确认保留、取消即删）。
- **渲染**：新组件 `AccountIconView`（icon 目录文件内）统一所有展示位 —— `file:` 值按扩展名分流 `SvgPicture.file` / `Image.file`，文件读不到（跨端未同步附件）回退类型默认字形；预置名直接出 `Icon` 字形并着色，自定义图片不上色（用户素材）。账户卡、账户选择器、账本成员、流水汇总、快速记账 chip、表单预览/字段全部改画此组件；快速记账 chip 的 icon 参数从 `IconData` 放宽为 `Widget`（`IconTheme.merge` 传色）。
- **同步**：`file:` 值随 `icon` 字段照常进同步日志；对端文件缺失由渲染层静默降级，无额外同步逻辑。

### 5.1 自定义 logo 不套「浅色圆角底壳」（已实施）

用户上传的通常是银行 / 支付平台的品牌 logo（招商银行、支付宝……），特征很一致：**本身就是一块完整图形 + 透明底**。原先所有图标走同一套「42 圆角块 + 品牌色 12% 底 + 描边，图标只有 21」的处理，套到 logo 上就变成"小图 + 大壳"——图形被压到 21、外面还糊一层淡蓝底，辨识度很低，和系统里其他 App 图标的观感也对不上。

规则改为按图标来源分流：

| 图标来源 | 容器 | 图形尺寸 |
| --- | --- | --- |
| 预置 Material 字形 | 圆角底壳（默认背景 = 品牌色 12%；自定义背景 = 磨砂反色） | 21（字形靠底衬才有"图标感"） |
| 自定义图片 / SVG | **不画底、不画描边** | 卡片 / 流水汇总 34（槽位 42 四周各留 4）、账本成员 30、表单字段 28、chip 18~20 |

- `AccountIconView` 新增可选 `imageSize`（默认等于 `size`）：字形仍按 `size` 画，自定义图片按 `imageSize` 画；文件丢失回退字形时也回到 `size`，不会突然变大。
- 新增 `AccountIconView.usesCustomImage(account)` 供展示位判断是否要套壳，避免每个调用点自己拼 `file:` 前缀判断。
- 账本成员列表原本把图标塞进 `CircleAvatar`（圆形底 + 20 小图）：方形 logo 会被裁掉四角，自定义图标改走无底容器。
- 流水汇总面板原本只取 `IconData`（自定义图标会退回类型字形），改为自定义时画 `AccountIconView`，同一账户各处图标一致。
- 尺寸集中到常量 `accountCardLogoSize = 34`：先铺满 42 后反馈"偏大"（logo 盖住整个槽位、比旁边 21 的字形重一大截），收到 34 让槽位四周各留 4。后续再微调只改这一处。

## 六、风险与取舍

1. **背景图不同步**（AttachmentStore 既有约束）→ 降级链兜底 + 文案告知，不做 WebDAV 附件同步（成本高）。
2. **color 语义分离**会多一个字段，但避免了"改背景毁掉全 App 标识色"的连锁问题，值得。
3. **icon 存 Material 名称**依赖 `uses-material-design: true` 的字体可用性，无网络依赖；新版本 Flutter 移除个别图标名时靠 `forName` 回退兜底。
4. 卡片自定义后与 `selected` 高亮、左滑手势（AppSwipeActionTile 的 ClipRRect）叠加时的圆角/边框需在实现时验证。
5. **自定义图标文件不同步**：与背景图同因，对端回退类型默认字形；不做附件同步。
