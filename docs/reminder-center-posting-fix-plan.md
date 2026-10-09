# 提醒中心「处理 → 落流水」改造方案

> 目标：让「完成」一个待处理提醒时，钱账同步产生流水，并保持提醒状态与源头数据一致。

## 落地进度

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 0.5 | 通知扫描按待处理列表过滤（`actionableReminderIds`） | ✅ 已落地 |
| 0 | `repairBillReminderProcessingStatuses` 读取时自愈 | ✅ 已落地（挂在 `currentUserBillRemindersProvider`） |
| A | 完成回写源头状态 + `linkBillReminderTransaction` | ✅ 已落地 |
| B | `TransactionFormDialog` 预填 + 「记账」闭环 | ✅ 已落地 |
| C | 分期走 `postInstallmentDetail` | ✅ 已落地 |
| D | 还款复用 `TransferFormDialog` 预填 | ✅ 已落地 |
| E1 | 删 `openReminder` 死分支 | ✅ 已落地 |
| E2 | 补刷新链路 | ✅ 无需改动：`createTransaction` → `refreshAfterTransactionChanged` 已 bump 全局 money 版本 |
| E3 | 处理历史加「查看流水」入口 | ⏭ 保持挂起：processing 表没有 transactionId 列，详见 §11 末尾说明 |

> 存量数据修正（第 9 条）见 `reminder-center-legacy-data-analysis.md`，采用「读取时自愈」，
> 且在 `_syncSource` 里整体跳过 `autoManaged` 提醒，避免与 `_syncCreditAccountRepaymentReminder` 互踢。

---

## 0. 现状结论复盘

`处理` = `setReminderCenterState` = **只写 `moneyReminderCenterProcessing` 一张表**，与 `moneyTransactions` 无任何连接点。  
四个伴随问题（详见会话中的分析）：源头状态不回写、记一笔表单不预填也不回写、`openReminder` 死分支、itemKey 含 dueDate 易失效。

另外两条关键事实，决定了下面的方案形状：

| 事实                                                                                | 证据                                                              | 影响                    |
| --------------------------------------------------------------------------------- | --------------------------------------------------------------- | --------------------- |
| `MoneyBillReminderStatus.done` 全库**零引用**                                          | grep `MoneyBillReminderStatus.done` 无业务命中                       | 「完成」从未回写过提醒状态，这是纯漏实现  |
| `moneyBillReminders.relatedTransactionId` 已存在且在 sync 里                            | `bill_reminders.dart:281/526/592`、`delta_sync_service.dart:803` | 关联流水**不需要数据库迁移**      |
| `TransferFormDialog` 已支持 `initialToAccountId / initialAmountMinor / initialNotes` | `money_accounts_section.dart:1636-1640`                         | 还款路径有可直接复用的现成写法       |
| `TransactionFormDialog` **不支持**金额/描述/账户预填                                         | `transaction_form_dialog.dart:47-70`                            | 需要新增三个可选入参            |
| `postInstallmentDetail` 本身就完整生成流水 + 改 detail 状态 + 更新计划进度 + 刷预算                    | `installments.dart:368-…`                                       | 分期提醒应该直接走它，而不是另写      |
| 重复提醒（repeatPeriodType）**没有**推进下一周期的逻辑                                             | grep `repeatPeriodType` 仅出现在 create/update                      | 重复提醒完成时不该置终态，否则下月不再出现 |

---

## 1. 核心设计决策

### 决策 1：「完成」的语义

建议把「完成」定义为 **「这笔钱已经付了」**，按 `sourceType` 分流:

| sourceType / actionType                                          | 现在的「完成」 | 建议改为                                               |
| ---------------------------------------------------------------- | ------- | -------------------------------------------------- |
| `billReminder` / `creditCardBill`，actionType `recordTransaction` | 纯标记     | 打开**预填**的支出表单 → 保存成功后自动标记 completed                |
| `creditCardBill`，actionType `repay`                              | 纯标记     | 打开**预填**的转账表单（转入 = 信用账户）→ 成功后自动标记 completed        |
| `installment`，actionType `recordTransaction`                     | 纯标记     | 直接 `postInstallmentDetail`（自带确认弹窗）→ 自动标记 completed |
| `budget`，actionType `viewBudget`                                 | 纯标记     | **保持纯标记**（超支警告不是一笔要付的钱）                            |
| 左滑「完成」/ 行尾 ✓ / 批量「完成」                                            | 纯标记     | 同上述分流（而不是塞回 `_setState`）                           |

### 决策 2：是否需要保留「不记账，只标记」

**已拍板：不保留。**

「完成」不再是一个独立语义——提醒中心里所有能推动提醒走向 `completed` 的入口，
都必须先产生一笔流水。唯一的例外是 `viewBudget`（预算提醒），它被整体移除了完成能力，
只能忽略或等周期结束。

落地形态：

| 入口 | 处理 |
| --- | --- |
| 行尾图标按钮 | 「标记完成」→「记账」（`Icons.receipt_long_rounded`），走 `_runRecordFlow` |
| 左滑第一项 | 同上 |
| 批量操作条「完成」 | **直接下线**，只留「延后」「忽略」——批量要连弹 N 个表单，体验不成立 |
| 预算提醒 | 不提供记账入口，只能忽略 |

由此顺带产生的约束：UI 里再也不应有不带流水的 `complete(...)` 调用
（全库仅 `money_reminder_center_section.dart` 一处，且必带 `transactionId`）。

### 决策 3：标记为 completed 后，是否回写源头状态

**建议回写**（阶段 A），这是修 Item 1 的关键：

- 账单提醒 → `setBillReminderStatus(userId, sourceId, MoneyBillReminderStatus.done)`
- **跳过重复提醒**（`repeatPeriodType != null`）——否则重复账单下个月不再提醒
- 若已产生流水 → 额外写 `relatedTransactionId`，使提醒 ↔ 流水双向可查
- 分期不动（由 `postInstallmentDetail` 负责改 detail 状态）

---

## 2. 阶段 A — 完成回写源头（必须先做）

**收益**：修掉「源头 status 永远是 pending」「编辑日期后已完成提醒复活」两个一致性问题，且不动 UI，风险最低。

### A1. `MoneyReminderCenterItem` 增加两个瞬时字段

`lib/features/bookkeeping/domain/money_reminder_center_entity.dart`

```dart
// MoneyReminderCenterItem 增加（不落库，仅运行时携带）
final bool isRepeatable;      // 是否周期性提醒
final String? linkedTransactionId; // 已关联的流水 id（回写后的结果）
```

- `copyWith` 补对应参数
- `_billReminderCenterItem`（`drift_money_repository.dart:4068`）处填 `isRepeatable: reminder.repeatPeriodType != null`
- 其余构造点填默认值即可

> 因为不进 `MoneyReminderCenterProcessingCompanion`，**不需要改数据库 schema**，也不需要迁移。

### A2. 新增仓库方法

`lib/features/bookkeeping/domain/money_repository.dart`（在 `setBillReminderStatus` 旁边）

```dart
/// 把已产生的流水 id 回写到账单提醒上（relatedTransactionId）。
Future<void> linkBillReminderTransaction(
  String userId,
  String reminderId,
  String transactionId,
);
```

`lib/features/bookkeeping/data/parts/bill_reminders.dart` 实现：update `relatedTransactionId` + version + updatedAt，  
并用 `changedFields: {'related_transaction_id': transactionId}` 记一次 `_recordBillReminderChange`。

### A3. 应用层 `_setState` 加回写

`lib/features/bookkeeping/providers/bookkeeping_providers.dart:2017-2032`

```dart
Future<void> _setState(
  MoneyReminderCenterItem item,
  MoneyReminderCenterState state, {
  DateTime? snoozedUntil,
  String? transactionId,
}) async {
  final userId = _requireUnlockedUserId();
  await _ref.read(moneyRepositoryProvider).setReminderCenterState(
        userId, item, state,
        snoozedUntil: snoozedUntil,
      );
  await _syncSource(userId, item, state, transactionId: transactionId);
  _refresh();
}

Future<void> _syncSource(
  String userId,
  MoneyReminderCenterItem item,
  MoneyReminderCenterState state, {
  String? transactionId,
}) async {
  if (state != MoneyReminderCenterState.completed) return;
  final repo = _ref.read(moneyRepositoryProvider);
  switch (item.sourceType) {
    case MoneyReminderCenterSourceType.billReminder:
    case MoneyReminderCenterSourceType.creditCardBill:
      if (item.isRepeatable) return;           // 周期性提醒不置终态
      if (transactionId != null) {
        await repo.linkBillReminderTransaction(userId, item.sourceId, transactionId);
      }
      await repo.setBillReminderStatus(userId, item.sourceId, MoneyBillReminderStatus.done);
    case MoneyReminderCenterSourceType.installment:
    case MoneyReminderCenterSourceType.budget:
    case MoneyReminderCenterSourceType.recurringExpense:
      return;                                   // 各自有 owner
  }
}
```

`complete` 签名放宽为 `Future<void> complete(item, {String? transactionId})`，向后兼容现有调用点。

---

## 2.5 实际实现与本文的差异

以下五点与原方案不同，以代码为准：

1. **`installmentDetailId` 不走 `split(':').last`**：改在 `MoneyReminderCenterItem` 上加 getter，
   对非 installment 来源返回 null，避免把账单提醒的 id 误当明细 id。
2. **没有加「确认弹窗」**（C 方案里的 `showAppConfirmDialog`）：`postInstallmentDetail` 自身对
   非 pending 明细会抛 `invalidInstallmentStatus`，重复点击不会重复入账，弹窗是多余的摩擦。
3. **`createTransfer` 保持返回 `void`**：还款提醒是 `autoManaged`，`_syncSource` 本来就跳过它，
   拿不到也不需要 transactionId，没必要改签名。
4. **`postInstallmentDetail`（provider 层）改为返回 `MoneyTransactionEntity`**，与原方案一致。
5. **提醒编辑入口消失**：`_editableReminder` 原来依赖 `openReminder`（从未产出的枚举值）才可能命中，
   删死分支后「点卡片编辑提醒」彻底没有了入口 —— 已知缺口，需要的话从别处补（比如卡片右上角菜单）。

---

## 3. 阶段 B — 支出型提醒：预填表单 + 成功后闭环

### B1. `TransactionFormDialog` 支持预填

`lib/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart`

构造增加三个可选参数（对齐 `TransferFormDialog` 的写法）：

```dart
final int? initialAmountMinor;
final String? initialDescription;
final String? initialAccountId;
```

`initState`（`:123-153`）在非编辑分支补：

```dart
if (transaction == null) {
  _categoryId = widget.categoryId;
  _subCategoryId = widget.subCategoryId;
  final amount = widget.initialAmountMinor;
  if (amount != null) {
    _amountController.text = (amount / 100).toStringAsFixed(2);
  }
  _accountId = widget.initialAccountId ?? _accountId;
  _categoryId ??= widget.categoryId;
  return;
}
```

注意两个坑：

1. `_accountId ??= defaults.accountId`（`:706`）在 initState 之后跑，`??=` 语义下预填优先，**无需改动**。
2. `description` 目前是硬编码 `widget.type.label`（`:875`），用户根本没法填描述。  
   需要新增 `String? initialDescription` 并在 draft 构造处 `description: widget.initialDescription ?? widget.type.label`。
   > 这是一个**顺带的 UX 修复**：否则预填了标题也无处落。

### B2. `MoneyQuickActionLauncher` 支持携带预填

`lib/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart`

`_openTransactionDialog`（`:132-144`）与 `_openTransferDialog`（`:173-193`）各加一个可选 prefill 参数对象，  
或者更简洁：`run(action, {MoneyEntryPrefill? prefill})`，内部透传给对话框。

```dart
class MoneyEntryPrefill {
  const MoneyEntryPrefill({
    this.amountMinor, this.title, this.accountId,
    this.toAccountId, this.categoryId, this.notes,
  });
  final int? amountMinor;
  final String? title;
  final String? accountId;      // 支出/转账的「转出」
  final String? toAccountId;    // 转账的「转入」
  final String? categoryId;
  final String? notes;
}
```

### B3. 提醒卡片改为「记账并完成」

`lib/features/bookkeeping/presentation/reminders/money_reminder_center_section.dart`

新增一个协调方法（放在 `_MoneyReminderCenterSectionState`）：

```dart
Future<void> _runRecordFlow(MoneyReminderCenterItem item) async {
  switch (item.actionType) {
    case MoneyReminderCenterActionType.recordTransaction:
      if (item.sourceType == MoneyReminderCenterSourceType.installment) {
        return _postInstallmentAndComplete(item);   // 见阶段 C
      }
      return _openExpenseAndComplete(item);         // 打开预填表单
    case MoneyReminderCenterActionType.repay:
      return _openRepaymentAndComplete(item);       // 见阶段 D
    case MoneyReminderCenterActionType.viewBudget:
      return actions.complete(item);                // 纯标记
    case MoneyReminderCenterActionType.openInstallment:
      return _postInstallmentAndComplete(item);
    case MoneyReminderCenterActionType.openReminder:
      return actions.complete(item);
  }
}

Future<void> _openExpenseAndComplete(MoneyReminderCenterItem item) async {
  final result = await showAppResponsiveDialog<Object>(
    context: context, expandCompactSheet: true,
    builder: (context) => TransactionFormDialog(
      type: MoneyTransactionType.expense,
      ledger: ref.read(currentUserEffectiveTransactionLedgerValueProvider),
      initialAmountMinor: item.amountMinor,
      initialDescription: item.title,
      initialAccountId: item.accountId,
      categoryId: /* 账单提醒携带的 categoryId，见下 */ null,
      onSubmit: (result) => _submitExpense(item, result),
    ),
  );
  // onSubmit 内部已处理成功/失败；成功后标记 completed 并 dismiss
}
```

**成功才标记**：在 `_submitExpense` 里拿到 createTransaction 的返回 id 后调用  
`actions.complete(item, transactionId: id)`，失败则保持 pending 不动。

**categoryId 的传递**：`MoneyReminderCenterItem` 目前不带 categoryId，而 `MoneyBillReminderEntity` 有。  
需要先给 item 增加 `categoryId` 瞬时字段（同 A1 的做法），否则预填表单里分类是空的、用户体验不完整。

### B4. UI 入口调整

- 行尾图标按钮（`money_reminder_center_section.dart:779-793`）：`tooltip` 由「标记完成」改为「记账」，图标换 `Icons.receipt_long_rounded`
- 左滑 actions（`:667-674`）「完成」保留但改走 `_runRecordFlow`
- 批量操作条 `onComplete`（`:111`）同上
- 多选批量时若混合了预算类提醒，按各 item 自己的 actionType 分流，不要统一处理

---

## 4. 阶段 C — 分期提醒：直接 `postInstallmentDetail`

`item.sourceId` 的格式是 `'${plan.id}:${detail.id}'`（`bill_reminders.dart:717`），直接拆出 detailId 即可。

```dart
Future<void> _postInstallmentAndComplete(MoneyReminderCenterItem item) async {
  final detailId = item.sourceId.split(':').last;
  final ok = await showAppConfirmDialog(...);  // 对齐 installments_section.dart:201-203 的确认文案
  if (ok != true) return;
  try {
    final tx = await actions.postInstallment(detailId);
    await ref.read(currentUserReminderCenterActionsProvider)
             .complete(item, transactionId: tx.id);
    AppToast.success(_toast!, context, '已入账');
  } on MoneyRepositoryException catch (e) {
    AppToast.error(_toast!, context, '入账失败');
  }
}
```

> 注意：这里**不要**在 `postInstallmentDetail` 之后再补 `setBillReminderStatus` —— 分期 reminder 的 `sourceId` 不是 reminderId，  
> 层级 A 的 `_syncSource` 里 installment 分支必须 `return`（已处理）。

`CurrentUserMoneyInstallmentActions.postInstallmentDetail`（`bookkeeping_providers.dart:2278`）目前返回 `void`，  
需要改成返回 `MoneyTransactionEntity`（repository 层已经是 `Future<MoneyTransactionEntity>`，只差上层透传）。

---

## 5. 阶段 D — 还款提醒：复用现成的转账预填

直接对齐 `money_accounts_section.dart:1627-1663` 已经跑通的写法：

```dart
Future<void> _openRepaymentAndComplete(MoneyReminderCenterItem item) async {
  final result = await showAppResponsiveDialog<Object>(
    context: context, expandCompactSheet: true,
    builder: (context) => TransferFormDialog(
      initialToAccountId: item.accountId,      // 信用账户
      initialAmountMinor: item.amountMinor,
      initialNotes: '信用卡还款',
    ),
  );
  if (!context.mounted || result is! MoneyTransferDraft) return;
  try {
    final id = await ref.read(currentUserMoneyTransactionActionsProvider)
                        .createTransfer(result);
    await actions.complete(item, transactionId: id);
  } catch (_) { /* toast 失败 */ }
}
```


需要确认 `createTransfer` 当前返回类型（若为 `void` 需改为返回 id）。

---

## 6. 阶段 E — 收尾清理

1. **删死分支**：`money_reminder_center_section.dart:286-291` 里 `item.actionType == openReminder` 的判空逻辑。  
   `openReminder` 从未被任何生成点产出（只有 `fromStorageValue` 的 fallback 用到），是陈腐代码。  
   同时修正 :613、:205 两条与之矛盾的注释。
2. **同步刷新**：完成 + 落流水后，`MoneyDataRefreshCoordinator.refreshAfterReminderChanged`（`:1660`）  
   还需要补 `_bumpTransactions()` 之外的**账户 / 预算 / 现金流** invalidation，否则新流水写入后  
   「账户余额」「本月支出」不会即时刷新。建议新增 `refreshAfterTransactionFromReminder()`。
3. **处理历史展示**：`getReminderCenterHistory` 读的是快照。有了 `relatedTransactionId` 后，  
   `_HistoryReminderCard` 可以补一个「查看流水」的入口（可选，建议放到下一期）。

---

## 7. 涉及文件清单

| 文件                                                                                     | 阶段      | 改动                                                                      |
| -------------------------------------------------------------------------------------- | ------- | ----------------------------------------------------------------------- |
| `lib/features/bookkeeping/domain/money_reminder_center_entity.dart`                    | A       | 加 `isRepeatable` / `linkedTransactionId` / `categoryId` 瞬时字段 + copyWith |
| `lib/features/bookkeeping/domain/money_repository.dart`                                | A       | 新增 `linkBillReminderTransaction` 声明                                     |
| `lib/features/bookkeeping/data/parts/bill_reminders.dart`                              | A       | 实现 `linkBillReminderTransaction`                                        |
| `lib/features/bookkeeping/data/drift_money_repository.dart`                            | A       | `_billReminderCenterItem` 填 `isRepeatable` / `categoryId`               |
| `lib/features/bookkeeping/providers/bookkeeping_providers.dart`                        | A/D     | `_setState` 增回写；`postInstallmentDetail` 返回实体                            |
| `lib/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart`      | B       | 三个 prefill 入参 + description 可写                                          |
| `lib/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart` | B       | prefill 透传                                                              |
| `lib/features/bookkeeping/presentation/reminders/money_reminder_center_section.dart`   | B/C/D/E | 分流主逻辑 + UI 文案 + 死分支                                                     |

---

## 8. 测试改动

**必须同步改**（现有断言把「不写流水」固化成了期望行为）：

- `test/features/bookkeeping/data/drift_money_repository_reminder_center_test.dart:98`  
  `lists bill reminders and moves completed items to history`  
  → 保留原有断言，另加：「完成后 `watchBillRemindersForUser` 里该提醒 status 为 `done`」；  
  对重复提醒加反向用例（status 保持 `pending`）。
- `test/features/bookkeeping/presentation/reminders/money_reminder_center_section_test.dart:201`  
  批量「完成」用例 → 改为断言「打开记账表单」，新增「预填金额正确」和「提交后提醒进入历史」两条。

**新增**：

- `linkBillReminderTransaction` 仓储用例
- 走完 `_runRecordFlow` 后 `moneyTransactions` 确实有一条记录的集成用例
- 分期路径：完成后 installment detail.status == posted 且 plan.progress 前进一期

---

## 9. 风险与缓解（落地后复核）

| 风险 | 缓解 | 现状 |
| --- | --- | --- |
| 用户误以为「完成」=「忽略」而被迫记一笔 | 决策 2 定为**不保留**纯标记；批量条明确写「忽略不会产生流水」，toast 说「已忽略 N 项（未记账）」；成功文案是「已记账」而不是「已完成」 | ✅ |
| 全额预填导致用户不核对直接保存 | 表单一律不自动提交，预填值可改；金额走与手填相同的校验 | ✅ |
| 重复提醒被置终态后下一期失联 | `_syncSource` 里 `isRepeatable → return`；集成测试与仓储测试双重守护 | ✅ |
| 自动托管提醒与 `_syncCreditAccountRepaymentReminder` 互踢 | `_syncSource` / `repair` 均跳过 `autoManaged`；已验证该提醒创建时 `autoManaged=true`（`drift_money_repository.dart:1290/1358/1389`） | ✅ |
| 老数据「已处理但 status 仍 pending」 | 采用读取时自愈而非一次性迁移，见专项分析文档 | ✅ |
| 后来者绕过 `_runRecordFlow` 直接调 `complete` | 新增源码守卫测试 `reminder_posting_guard_test.dart` | ✅ |
| 历史项丢失 `isRepeatable` / `isAutoManaged` | processing 表不存这两列；历史卡片不提供任何处理入口，已在 `_mapReminderProcessingItem` 注明：谁要给历史加「撤销」必须先修这里 | ⚠️ 约束 |

---

## 10. 执行顺序（实际）

实际顺序与最初设想不同——先止血、再自愈、最后才动 UI：

1. **0.5** 通知门禁（十几行，立即止住重复推送）
2. **0** 读取时自愈（照抄 `repairInstallmentPlanStatuses` 的既有惯例）
3. **A** 回写源头（此时「完成」仍不记流水，是预期的中间态）
4. **B/C/D** UI 闭环 —— 到这里「完成 = 落流水」才真正成立
5. **E** 清理 + 收尾（补批量说明文案、补回编辑入口、补守卫测试）

A 与 B/C/D 之间存在一个**中间态**：源头已经会置 `done`、不再重复推送，但完成动作仍然不产生流水。
它是刻意保留的（每步都可独立回滚），不是半成品状态。

---

## 11. 实际落地清单（代码位置）

| 位置 | 内容 |
| --- | --- |
| `domain/money_reminder_center_entity.dart` | `isRepeatable` / `isAutoManaged` / `categoryId` 瞬时字段；`installmentDetailId` getter |
| `data/parts/bill_reminders.dart` | `repairBillReminderProcessingStatuses`、`linkBillReminderTransaction` |
| `data/drift_money_repository.dart` | `_billReminderCenterItem` 补 `isRepeatable` / `isAutoManaged` / `categoryId` |
| `application/money_bill_reminder_notification_service.dart` | `scanAndNotify(actionableReminderIds:)` 门禁 |
| `providers/bookkeeping_providers.dart` | `complete(item, {transactionId})`、`_syncSource`、`repair` 挂载、`postInstallmentDetail` 返回实体 |
| `presentation/transactions/transaction_form_dialog.dart` | `initialAmountMinor` / `initialAccountId` / `initialDescription` / `initialNotes` / `initialTransactionAt` 预填；`description` 不再写死为类型名 |
| `presentation/quick_actions/money_quick_action_launcher.dart` | `recordExpenseFromReminder` / `recordRepaymentFromReminder` / `postInstallmentFromReminder` |
| `presentation/reminders/money_reminder_center_section.dart` | `_runRecordFlow` 统一出口；行尾 / 左滑改「记账」；批量「完成」下线；预算提醒无完成入口；批量条说明文案；账单提醒卡片的「更多 → 编辑提醒」 |
| `data/drift_money_repository.dart` | `_mapReminderProcessingItem` 注明无法还原 `isRepeatable` / `isAutoManaged` |

### 测试

| 文件 | 覆盖 |
| --- | --- |
| `test/features/bookkeeping/data/drift_money_repository_reminder_repair_test.dart` | repair 收敛 / 幂等 / 排除项 / sync 落库；`linkBillReminderTransaction` |
| `test/features/bookkeeping/providers/reminder_center_posting_integration_test.dart` | **真仓储 + ProviderContainer** 跑完整序列，落流水 / 状态 / 关联 / 幂等 / 守卫 |
| `test/features/bookkeeping/presentation/transactions/transaction_form_dialog_prefill_test.dart` | 金额 / 备注 / 日期预填，及无上下文时的空表单 |
| `test/features/bookkeeping/presentation/reminders/reminder_posting_guard_test.dart` | 源码扫描：禁止绕过 `_runRecordFlow` 的完成路径、禁止 UI 直调 `setReminderCenterState` |
| `test/features/bookkeeping/domain/money_reminder_center_entity_test.dart` | `installmentDetailId` 解析 |
| `test/features/bookkeeping/application/money_bill_reminder_notification_service_test.dart` | 通知门禁与「状态回退后可再推送」 |

### E3「处理历史查看流水」为何仍挂起

`relatedTransactionId` 已经回填了，但**历史列表读的是 processing 表，那张表没有这一列**，
`_mapReminderProcessingItem` 拿不到 `transactionId`。要支持就得给
`moneyReminderCenterProcessing` 加列（含 sync 变更），或者在历史里反查提醒——前者有迁移成本，后者脆。
收益（一个可选入口）明显小于成本，所以**保持挂起**，并在代码注释里留了约束说明。
