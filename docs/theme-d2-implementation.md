# 主题重做实施记录 · D2 暖纸 · 靛蓝

设计来源：`docs/theme-studio.html`（从零设计，不复用旧的暖珊瑚体系）。
本文件记录**落地了什么**、**为什么**、以及**还剩什么没做**。

## 一、新的配色体系

四层构造，每层独立求解（求解器见 `docs/theme_verify.py`、`docs/theme_studio_presets.py`）：

| 层 | 亮色 | 暗色 | 构造规则 |
|---|---|---|---|
| 中性层 | `#ECE7E1` / `#F2EDE6` / `#FBF6F0` / `#F6F1EB` | `#090604` / `#0E0A07` / `#17130F` / `#221D18` | 暖纸色相 72°、彩度 0.010，只靠明度分四级。**暖感来自中性层，不来自品牌色** |
| 强调层 | `#4269D3`（文字版）/ `#5E88F6`（填充版） | `#759DFF` / `#CADBFF` | 文字版过 AA 供文字与图标；填充版鲜亮，配深色前景 `#03001F` |
| 语义层 | 支出 `#A7463C`、收入 `#006E30`、转账 `#004557`、信用 `#7B428C`、警示 `#473D00` | `#FFB5AA` / `#9DF7B0` / `#3FCDF6` / `#F7DDFF` / `#C8B648` | 色相固定，明度按「色觉缺陷可辨梯度」求解 |
| 数据层 | 8 色 | 8 色 | 等感知明度、相邻切片色相相距 135°、每个色 ≥3:1 |

## 二、为什么这样设计（一句话版）

1. **暖感交给中性层**：旧体系把「暖」同时押在品牌色、中性色、语义色上，三暖叠加导致层次发糊（品牌红与支出红只差 11.5°）。新体系里中性层暖、品牌色冷，对比反而更清晰。
2. **语义色用明度做冗余编码**：把五种语义色调到「等明度」后，绿色盲下「支出↔收入」的 OKLab ΔE 只有 **0.015**（几乎同色）。现在用明度梯度，红/绿/蓝三种色盲下最差 ΔE 仍有 **0.060 / 0.060 / 0.106**。
3. **强调色分两个角色**：M3 的 `primary` 是填充色、`onPrimary` 是它上面的前景。旧实现把「鲜亮填充」当文字用（几乎都不过 AA），又在前景硬编码白字（深色下 **2.05:1**）。现在填充与前景**联合求解**，且文字/图标改用压暗版。

## 三、代码改动清单

| 文件 | 改动 |
|---|---|
| `lib/core/theme/app_theme_tokens.dart` | 全量换成 D2；新增 `primaryFill/onPrimaryFill`、`primaryContainer/onPrimaryContainer`、`SurfaceSunken/Raised`、`Outline/OutlineVariant`、`Text/TextSecondary`、`HeroAmber` |
| `lib/core/theme/app_design_tokens.dart` | `AppMoneyColors` 换新；`AppHeroGradients` 新增 `amber`（替掉散落三处的硬编码 `#FFD9A0`）；**新增 `AppChartPalette` 主题扩展** |
| `lib/core/theme/app_theme.dart` | 深色 token、四级表面阶梯、两档描边、`onSurface/onSurfaceVariant` 显式指定、注册图表色板 |
| `app_icon_action_button.dart` | 实心按钮前景从硬编码 `Colors.white` 改为 container 配对（深色 **2.05:1 → 7.0:1**） |
| `app_sliding_segmented_control.dart` | 选中态改用 container 配对（原来同色叠同色 **3.03:1 → 7.0:1**） |
| 4 个统计图表 | 各自内联的 Material 原色调色板 → 统一 `theme.chartPalette`（原来四张图顺序都不一样、且不随主题变） |
| `money_accounts_section.dart`、`home_balance_hero_card.dart` | 琥珀 `#FFD9A0` → `theme.heroGradients.amber`（原来在净资产渐变右端只有 3.44:1） |
| `test/core/theme/*` | 更新为 D2 常量，并新增 6 类不变量：填充按钮、强调色当文字、选中态配对、控件描边 3:1、图表色板 3:1、Hero 琥珀字 4.5:1 |

## 四、验证

```
flutter analyze  → No issues found
flutter test     → 548 passed / 12 failed
                   12 个失败与改动前完全同一批（health 11 + legacy import 1），无新增
test/core/theme  → 37 passed（含上面 6 类新不变量）
```

外部校验（`docs/theme_verify.py`，与页面里的 JS 引擎逐项对拍过）：WCAG 对比度、APCA(Lc)、
OKLab ΔE、Viénot/Brettel 色觉缺陷模拟。关键数字：

| 项 | 实测 | 要求 |
|---|---|---|
| 正文 / 卡片 | 16.47:1（APCA Lc 98） | ≥4.5 |
| 次要文字 | 6.08:1（Lc 74） | ≥4.5 |
| 强调色当文字 | 4.66:1（Lc 67） | ≥4.5 |
| 填充按钮 + 前景 | 6.18:1 | ≥4.5 |
| 选中态 container 配对 | 7.01:1 | ≥4.5 |
| 控件描边 | 3.02:1（暗色 3.09:1） | ≥3.0 |
| 语义色最差（卡片/凹陷面） | 5.45 / 4.77 | ≥4.5 |
| Hero 白字 / 琥珀字最差 | 4.64 / 4.63 | ≥4.5 |
| 图表色板最差 | 3.74 | ≥3.0 |

设计过程中被测试拦下的两个真问题（都改颜色而不是改测试）：

1. **暗色控件描边差 0.08**：`#695E52` 对暗色卡片只有 2.92:1 → 提到 `#6B6257`（3.09:1）。
2. **警示色与暖纸背景色相只差 6.7°**：暖纸底本身就在 35°，原定的警示色落在 33° → 把警示色相让到 OKLCH 100（sRGB 51.5°，相差 16.5°），并重新解了一遍明度梯度保证色盲可辨性不掉。

## 五、三项后续决定（已执行）

### 1. 分类自定义色板 —— **保留，不修改**（用户决定）

`app_color_picker.dart` 的 15 色维持原样。已知技术债（保留但不修）：
浅色主题下 6 色不到 3:1（`#F97316` 2.80 / `#F59E0B` 2.15 / `#EAB308` 1.92 /
`#0EA5E9` 2.77 / `#06B6D4` 2.43 / `#10B981` 2.54），深色主题下 2 色不到
（`#475569` 2.21 / `#334155` 1.62）。分类图标/文字用这些色时，浅色下会偏虚。
若以后要修：改成「用户只选色相，明度由主题求解」，成本是一次颜色映射迁移。

### 2. `themeSeedColor` 死配置 —— **已删除**

它原来有表列、注册时写默认值 `0xFFE45F4F`、还有读写方法，但 `app_theme.dart`
从未读取（主题一直用写死的 `AppThemeTokens`）。删除内容：

| 位置 | 改动 |
|---|---|
| `tables/user_preferences_table.dart` | 删列定义 |
| `app_database.dart` | `schemaVersion` 22 → 23，新增 `if (from < 23)` 删列迁移 |
| `preferences/domain/user_preferences_entity.dart` | 删字段 |
| `preferences/domain/preferences_repository.dart` | 删 `updateThemeSeedColor` |
| `preferences/data/drift_preferences_repository.dart` | 删实现 + 映射 |
| `auth/data/drift_auth_repository.dart` | 删注册时的默认值写入 + 常量 |
| 3 个测试 fixture + 迁移测试 | 去掉该参数 |

迁移写成**防御式**（先 `PRAGMA table_info` 查列是否存在再删），原因是迁移测试
用「当前 schema 减列」来模拟旧版本，那种库上并没有这一列；对应地，测试里新增
`_restoreThemeSeedColorColumn()`，在模拟 v23 之前的版本时把这一列加回来（6 处）。

### 3. 工作台里另外三套方向（D1 墨黑电光青 / D3 曜石赤金 / D4 雪白莓红）—— **不需要**

保留在 `docs/theme-studio.html` 里作为素材，不落地。

## 六、品牌卡渐变改暖赭金（用户反馈「太突兀」）

**现象**：D2 上线后首页「本月预算」卡（品牌渐变）在暖纸底上显得突兀。

**量化原因**：

| | 与纸底色相差 | 彩度 |
|---|---|---|
| 原 D2 冷渐变（靛蓝系） | **124° / 164° / 165°**（近互补） | 0.12 ~ **0.17** |
| 旧主题的珊瑚渐变 | 29° / 41° / 49°（邻近色） | 0.14 |

设计语义层时很在意「品牌别占红色」，却漏了：**Hero 卡是大面积填充，大面积下色相距离比色相身份重要得多**。

**选暖色的过程里发现两个约束**（都有实测数字）：

1. **暖玫不可用**：`#A5458A→#B54877→#C24D5F` 与「超支」告警渐变 `#B2397C→#BF3D6D→#CB4453`
   的 OKLab ΔE 只有 **0.023~0.035** → 「正常」与「已超支」两张卡几乎同色，功能性倒退。
   （顺带查出：**旧配色的品牌卡 vs 超支卡 ΔE 也只有 0.08~0.14**，同样分不清，只是没人注意。）
2. **暖赭金可用**：`#A15500→#9C6400→#936E00` —— 在暖色区（与纸底色相 23~51°，不突兀）、
   与告警卡 ΔE **0.166~0.170**（分得清）、与语义「警示」文字色 ΔE 0.19~0.21（不会被误读成警示态）、
   白字对比 5.50 / 4.96 / 4.70 / 全部 ≥4.5。

**决定**：品牌卡用暖赭金。净资产渐变（账户页「紫→青」，用户原本认可的那版）与告警渐变不动。

## 七、工作台三个 bug（已修）

这轮反馈同时暴露了 `docs/theme-studio.html` 的三个问题 —— 用户点「暖渐变」却导出 `cool`，原因如下：

1. **属性名大小写不一致**：按钮写 `data-herostyle`（DOM 转成 `dataset.herostyle`），
   而状态键与读取用的是 `state.heroStyle` → **按钮完全没生效**，预览与导出一直是冷渐变。
   已改为 `data-hero-style`（DOM 转 `dataset.heroStyle`），与状态键一致。
2. **`solveL` 偏好方向反了**：浅色下「控件描边」被解成最暗的颜色
   （导出里 `borderStrong #352C21`，对比度 13:1，应该是一道描边却成了黑线）、
   「强调色文字」也被解成 `#081881`（比设计值暗得多）。已按「浅色取刚好达标的最亮色」修正。
3. **深色底默认值偏暗**：工作台默认 0.144，比 Python 端预设（0.175）暗一档，
   导出的深色接近纯黑。已对齐到 0.175。

另新增：`暖赭金` / `暖玫（与告警撞色）` 两个风格选项，以及一条实时校验
**「品牌卡 ↔ 超支卡 差异(ΔE)」**（门槛 0.10）—— 把这个坑直接摆在面板上。

## 八、附：一次构建事故（已修复）

上一轮写的 `tool/theme_gen.dart` 为了少加依赖，用**绝对 `file://` 路径** import
pub cache 里的 `material_color_utilities`。这个写法让 `build_runner` 直接崩：
`Unsupported operation: Cannot resolve file:///...; only "package" and "asset" schemes supported`，
而 `lib/core/database/app_database.g.dart`（被 gitignore 的本地生成物）因此被删掉、
项目无法编译。

修复：把 `material_color_utilities` 加为 `dev_dependencies`（它本来就是传递依赖，
不新增下载），`tool/theme_gen.dart` 改用 `package:` import，再 `build_runner clean`
后重建（生成物 3.2MB 已恢复）。

教训：**工具脚本也不要 import 绝对路径**——`tool/` 是 build_runner 的默认输入目录，
它会影响整个代码生成流程。
