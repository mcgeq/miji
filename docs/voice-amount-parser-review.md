# 语音金额解析器接入前评审

对象：`docs/cn_amount_parser.dart`（`CnAmountParser` + `AmountSanityChecker`）
评审基准：本项目既有代码与约定（`lib/features/bookkeeping`、`lib/core/ocr`）
结论：**方向对，但不能按现状接入。** 存在 5 类静默错误（返回值精度等级为 high、`needsReview=false`），以及 4 处与项目既有契约的结构性冲突。先修契约与解析 bug，再接 ASR。

---

## 0. 一句话结论

这个模块把「口语省略补全」当成主要难点，实际上**真正的危险全在「带明确单位」的那条路径上**——那条路被标成 `high`、不提示复核，却会因为解析 bug 静默错 10 倍（`十万块 → 110000`、`一点五元 → 5.0`、`1,200块 → 200`）。

`needsReview` 的判据（`elided || confidence != high`）恰好覆盖不到这些错误：它们既不省略、又有单位。所以「UI 拿布尔值决定高亮」这个设计，建立在一张有漏洞的网上。

---

## 1. 先纠正一个前提

你说「沙盒里没有 Dart 环境装不上 SDK，这份代码没经过编译」。**这台机器上有 Dart**：

```
/d/tools/flutter/bin/dart      # Flutter 自带，且项目 .dart_tool/package_config.json 完好
```

实测：

```
cd docs && dart run cn_amount_parser.dart
→ 30/30 passed，编译无告警
```

30 条全过是真的（`买菜一百一` 被判成 `low` 而非 `medium`，因为它不带「块」——这点和你描述略有出入）。但这 30 条**全部只测「结果对不对」，没测「不该出金额时会不会硬出」**，也没测万/亿组合与千分位。补充对抗用例后问题立刻暴露。

=> 这份代码的验证强度，比 30/30 这个数字给人的印象低得多。

---

## 2. 最要紧的冲突：它和项目既有铁律是反的

`lib/features/bookkeeping/application/money_receipt_parser.dart` 文件头写着：

> **绝不用「猜」的方式补字段：猜错的金额比空着的金额更有害。**

并且 `MoneyReceiptDraft.amountMinor` 在猜不出时是 `null`，直接留给表单空着。

而 `cn_amount_parser` 的做法相反：

| 场景 | 既有 OCR 链路的裁决 | `cn_amount_parser` 的裁决 |
|---|---|---|
| 数字有歧义 | 返回 `null`，交用户填 | 按规则推断（`一百一 → 110`），输出 `amount` + `needsReview` |
| 句中无金额单位 | — | **取最后一个数字串当金额**（`confidence.low`） |
| 金额为 0 | `minor > 0` 才返回，否则视为没认出来 | 返回 `0.0`，`high`，`review=false` |

第三条尤其说明问题：既有链路是「不成立就当作不存在」，新模块是「先给一个值，再打个标记让 UI 去挡」。

**这不是代码质量问题，是输出契约问题。** `AmountMatch.amount` 是 `double` 而非 `null`，意味着调用方天然会把它塞进金额框。防线只剩一个布尔值，而实测证明这个布尔值漏。

---

## 3. 实测缺陷清单（按危害排序）

全部为实际运行结果，非阅读推断。

### P0 · 有单位 + `high` + `review=false` + 静默错值

| 输入 | 实际输出 | 应有 | 根因 |
|---|---|---|---|
| `十万块` | **110000** | 100000 | `_parseCnInt` 处理「万」时 `if (cur == 0) cur = 1` |
| `十万元` | **110000** | 100000 | 同上 |
| `二十万` | **210000** | 200000 | 同上 |
| `一百万` | **1010000** | 1000000 | 同上 |
| `十亿` | **1100000000** | 1000000000 | 同上 |
| `一点五元` | **5.0** | 1.5 | 「点」不是数字字符，回扫只抓到「五」 |
| `三点八块` | **8.0** | 3.8 | 同上 |
| `零点五元` | **5.0** | 0.5 | 同上 |
| `1,200块` | **200** | 1200 | 回扫遇 `,` 截断，只取到 `200` |
| `3,500.50元` | **500.5** | 3500.5 | 同上 |
| `12,000` | **0.0** | 12000 | 兜底逐段扫，`000` 被当成一个数，取末位 |

**「万」的 bug 是系统性的一位错位**，影响所有「十/百 + 万/亿」组合。修法只有一行：

```dart
} else if (_big.containsKey(ch)) {
  final u = _big[ch]!;
  if (cur == 0 && section == 0) cur = 1;  // 只有「万」「亿」单用才补 1
  total += (section + cur) * u;           // 原为 if (cur == 0) cur = 1;
```

验证：`十万`→100000、`二十万`→200000、`一百万`→1000000、`一万`→10000、`十万零五百`→100500、`一亿二千万`→120000000，均正确。

千分位则应当直接复用项目已有的 `parseMoneyAmountToMinor`（它已经 `replaceAll(',', '')`），不要自己再写一遍数字扫描。

### P0 · 全是 `high` 的假阳性（中文常用词撞单位字）

| 输入 | 输出 | 问题 |
|---|---|---|
| `今天十分好吃` | **0.0 `high`** | 「分」被当角分单位 |
| `考试得了九十分` | **0.0 `high`** | 同上，分数被当钱 |
| `咱们一块去吃饭` | **1.0 `high`** | 「一块」是量词 |
| `零元` | **0.0 `high`** | 0 不该产出金额 |
| `千万别忘了` | 10010000 `low` | 「千万」 |
| `万一迟到呢` | 11000 `low` | 「万一」 |
| `他是个二百五` | 250 `low` | 俗语 |

`分` 单字作为单位在语音文本里极不安全（十分/百分/分数/分钟）。建议：`分` 只在「毛/角 之后」或「后面跟『钱』」或「同片断内已出现 块/元」时才认。

### P1 · 兜底会凭空造金额

```
买了三本书     → 3.0    low
吃了两个包子   → 2.0    low
走了三步       → 3.0    low
密码是123456   → 123456 low
2026年记账     → 2026   low
```

这些确实 `review=true`，但**只要 UI 预填了金额框，用户看到「¥3」很容易当成「3 块」直接保存**。既有链路在同样场景返回 `null`。

`AmountSanityChecker` 也拦不住：它按类目比中位数，而「3 元」对「餐饮」完全正常。

### P2 · `start/end` 无法用于高亮（你说的 UI 落点直接失效）

```dart
final t = text.replaceAll(' ', '');   // 索引从此与原文不再对应
```

实测：

```
原文: "午饭 三十五 块"
raw="三十五块"  start=2  end=6
原文.substring(2, 6) == " 三十五"   ≠ raw
```

UI 若用 `start/end` 做 RichText 高亮，**高亮框会整体左移一个字符**。ASR 输出带标点/空格时必然踩到。

修法二选一：不要预处理（在扫描时跳过空白但仍按原文推进指针），或返回 `List<int> indexMap` 把规范化索引映射回原文。

### P3 · 语义缺口

- **方向全丢**：`收到工资三千五`、`退款三十五块`、`-35块` 都返回正数，无 `income/expense` 信息。项目有 `MoneyTransactionType`，而 `MoneyReceiptDraft` 是带 `type` 的。
- **时间全丢**：`昨天晚上…`、`前天…` 不解析。OCR 链路有 `_parseOccurredAt`，语音说时间比截图更自然。
- **多金额规则自相矛盾**：主单位取**第一个**（`花了二十块，打车十五块 → 20`），兜底取**最后一个**。语音里「早饭十块，午饭二十块」很常见，这个不一致会被用户感知成「时好时坏」。

### P4 · 类型与项目不匹配

项目金额一律是 `int amountMinor`（分）。`AmountMatch.amount` 是 `double`（元），调用方还得自己 `(v*100).round()`，而 `_round2` 的浮点中间态在边界上会抖。既有 `parseMoneyAmountToMinor` 已经解决了这件事。

### P5 · `AmountSanityChecker` 不适合落在这一层

- 是**内存 Map**，跨进程/跨会话即失效——「历史分布」在下次冷启动就没了。
- 与项目已有 `MoneyCategoryUsage`（分类累计金额 + 次数 + 最近使用）、`money_entry_suggestions`（历史商户）职责重叠。
- ×3 / ÷3 的中位数规则对「餐饮」这类方差极大的类目误报率高。

结论：这一层应当退化成**纯函数** `isSuspicious(categoryHistory, candidate)`，历史由 provider 从 Drift 取进来。不要在这个模块里持有状态。

---

## 4. `needsReview` 这个 API 的形状不够

一维布尔承载不了三种截然不同的错误处置方式。建议改成**三态 + 候选集合**：

```dart
enum VoiceAmountStatus {
  /// 有明确单位、无省略、通过范围校验 —— 可直接预填
  confirmed,

  /// 推断得出 / 无单位 / 多候选 —— 预填但必须确认
  ambiguous,

  /// 拿不到可信金额 —— 不给值，用户自己填
  missing,
}

class VoiceAmountReading {
  /// 只在 confirmed 时非 null。其他情况一律 null —— 让「空着」成为默认。
  final int? amountMinor;

  /// 需要用户确认时的候选（`一百一` → [11000, 10100] 分）。
  /// 用户点选比重新输入快，这是把「猜测」变成「选择」的关键。
  final List<int> candidatesMinor;

  /// 命中的原文区间，可直接用于高亮（必须与原文索引一致）
  final int? start;
  final int? end;

  final MoneyTransactionType? type;   // 收到/退款/工资 → income
  final DateTime? occurredAt;         // 昨天/前天/上周五
  final List<String> reasons;         // 「走了口语省略补全」「无金额单位」「偏离历史中位数 12 倍」
}
```

两点关键变化：

1. **`amountMinor` 只在 confirmed 时非 null。** 这把「不猜」从口头约定变成类型强制——`ambiguous` 的值进不了金额框，只能进候选 chip。
2. **候选集合取代布尔。** 你说的「一百一 也可能是 101 的误说」，正确处置不是「高亮 + 让用户重打」，而是**把 110 和 101 两个 chip 摆出来让用户点**。同样，`low` 兜底可以给出 [20, 3]（「二十」和「三本书」的 3），让用户一秒分辨。这样 `needsReview` 从「警告」升级成「交互」。

`reasons` 是为了排查：现在 `confidence` 只说了多可信，没说**为什么**不可信，跑口音测试时无法归因。

---

## 5. 建议的接入设计

### 放置位置

```
lib/features/bookkeeping/application/money_voice_amount_parser.dart
```

理由：`money_receipt_parser.dart` 就在同一层、同为纯函数、同为「文本 → 草稿」，命名前缀 `money_` 一致。不要放 `core/`——`core/ocr` 是平台能力封装（`io`/`stub` 条件导入），业务文本解析不属此列。

### 分层

```
ASR 文本
  ↓  money_voice_amount_parser.dart   纯 Dart，零依赖，可 dart test 直接跑
VoiceAmountReading { amountMinor?, candidates, start/end, type?, occurredAt?, reasons }
  ↓  money_voice_entry_draft.dart      合并类目（热词匹配）+ 支付方式 + 账本默认值
MoneyReceiptDraft 等价物（复用现有类型或新建 VoiceEntryDraft）
  ↓  TransactionFormDialog(initialAmountMinor: ...)
用户确认后落库
```

**第二层要复用 `parseReceiptPage` 已经建立的形状**（`amountMinor/merchant/occurredAt/paymentMethod/type/categoryName/notes/recommendedFieldCount`），这样 `MoneyQuickActionLauncher._openReceiptScanDialog` 那套「预填 → 弹表单 → 用户确认 → 落账」的代码几乎可以照搬，只是在前面多一步长按录音。

### 平台门控必须照抄既有写法

`pubspec.yaml` 目前**没有任何音频依赖**。语音要在 Android/iOS 可用、Web/桌面能编译，必须复制 `app_text_recognizer.dart` 的三件套模式：

```
core/voice/app_speech_recognizer.dart        // library + 条件导出
core/voice/app_speech_recognizer_io.dart     // 真实实现
core/voice/app_speech_recognizer_stub.dart   // isSpeechRecognitionSupported => false
```

并沿用「调用方先问 `isXxxSupported` 再决定是否展示入口，而不是调用了再去接异常」的约定（`app_text_recognizer.dart` 注释明确要求）。

### UI 落点

`money_quick_action_launcher.dart` 的 `_openReceiptScanDialog`（line 124）是模板。语音入口应当是它的兄弟方法，同样遵守那条注释：

> 识别结果一律回填表单让用户确认，**绝不自动落账**

---

## 6. 最小修复清单

按性价比排序，前四项都是几行改动：

| # | 问题 | 改法 |
|---|---|---|
| 1 | 万/亿 错位 10% | `_parseCnInt` 改 `if (cur == 0 && section == 0)` |
| 2 | 千分位 | `_isNumeralChar` 加 `,`；数字解析复用 `parseMoneyAmountToMinor` |
| 3 | 「点」小数 | `_parseCnInt` 支持 `数点[数字]`（`点` 后必须跟数字字符，避开「三点开会」） |
| 4 | 「分」假阳性 | `分` 仅当「毛/角之后」或「后跟钱」或「同片断有块/元」 |
| 5 | 索引错位 | 去掉 `replaceAll(' ','')`，改为扫描时跳过空白但按原文推进 |
| 6 | 0 与超大值 | `amountMinor > 0`；上限建议 1e9 分（1000 万），超限转 ambiguous |
| 7 | 返回分 | 改 `int amountMinor`，去掉 `_round2` |
| 8 | 多金额 | 统一为「取最后一个带单位的金额」并保留全部候选 |
| 9 | 兜底 | 不再产出 `amount`，只产出 `candidates` |
| 10 | 方向/时间 | 加 `收到/退款/报销/工资 → income`、`昨天/前天/上周X` |

测试补充（`test/features/bookkeeping/application/money_voice_amount_parser_test.dart`，与既有 `money_receipt_parser_test.dart` 同风格）：

- 反向用例优先：**「不该出金额」的断言比「金额对不对」更重要**
- 万/亿矩阵：十/二十/一百/一千 + 万/亿 全组合
- 千分位、中文「点」、`分` 假阳性
- 索引一致性：`text.substring(start, end) == raw` 作为不变量断言

---

## 7. 实施顺序建议（与你的下一步相反）

你建议「先接 voice_recognizer 跑通长按→文本→parser→高亮」。**我建议把顺序调一下**，理由是可归因性：

现在 parser 对「带单位」路径的错误率不是识别噪声，是**解析 bug**。如果先接 ASR，录音测试统计出的错误率会把两类错误混在一起——你无法判断「错 15%」里多少该换 SenseVoice、多少只是 `十万` 那行代码。换模型解决不了 `1,200 → 200`。

建议：

1. **先修 P0 六项 + 补反向用例**（纯 Dart，当天可完成，不需要设备）
2. **用文本样本打表，不要用录音**：直接收集 200+ 条「人们真的会怎么说」的句子（含大量不带单位的、带数量词的、说错又改口的），跑 parser，人工标注。这一步能在没有 ASR 的情况下把 parser 的错误率压到接近 0
3. **再接 ASR**，此时录音测试测到的才是纯粹的声学问题
4. 最后才是 `AmountSanityChecker`，接 Drift 真实历史

### 关于「声学混淆（三十/十三）」

`AmountSanityChecker` 只能兜住「离谱」，兜不住「30 记成 13」——这两者都在正常区间内。对这个错误，我的判断是：**不要试图用算法解决，用交互解决。**

语音记账真正的价值是省掉「打开 App → 选类目 → 填金额」的导航成本，**不是省掉核对**。所以金额字段应当做成大号数字 + 步进器 + 候选 chip，让「核对」这个动作只值一次点击。如果为了「全自动」去追精度，会掉进一个投入产出比很差的坑。

---

## 8. 需要你拍板的三个取舍

1. **`low` 兜底要不要保留？**
   保留 = 覆盖「打车二十」这类口语，但会造出 `三本书 → 3 元`。
   我的建议：保留，但只进 `candidates`、绝不进 `amountMinor`。这样既不丢能力，也不违铁律。

2. **多金额取第一个还是最后一个？**
   我倾向最后一个（「我刚说的这笔」），但需要和「早饭十块，午饭二十块」的实际情况核对。无论选哪个，都要把其余候选留着。

3. **语音入口是否只在 Android/iOS 出现？**
   取决于 `sherpa_onnx` 的桌面支持。如果按 OCR 的老路（`isTextRecognitionSupported`），Windows/macOS 用户会看不到入口——需要确认这是可接受的。

---

## 附：本次实测命令

```bash
cd docs && dart run cn_amount_parser.dart        # 30/30 passed
# 对抗用例（临时脚本，未入库）见评审过程记录
```

关键反例一览（可直接作为回归用例）：

```
十万块      → 110000  (应 100000)   high / 不提示
二十万      → 210000  (应 200000)   low
一点五元    → 5.0     (应 1.5)      high / 不提示
1,200块     → 200     (应 1200)     high / 不提示
3,500.50元  → 500.5   (应 3500.5)   high / 不提示
今天十分好吃 → 0.0     (应无金额)    high / 不提示
买了三本书   → 3.0     (应无金额)    low
午饭 三十五 块 → start/end 与原文错位一位
```
