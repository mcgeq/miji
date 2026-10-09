# 老数据专题：「已完成却仍是 pending」的账单提醒

> 配套文档：`docs/reminder-center-posting-fix-plan.md`（第 9 条要求"进一步分析"，本文是分析结论）

---

## 0. 结论先说

**这不是阶段 A 上线后才需要擦的屁股，而是一个此刻正在发生的 bug。**

阶段 A（完成回写源头）只能阻止**新增**的不一致；存量数据里已经存在的一批
「用户在提醒中心处理过、但 `moneyBillReminders.status` 仍是 `pending`」的提醒，
今天就在两个 UI 面上报错。所以修正必须做，而且要**独立于阶段 A 先修**。

推荐做法：**读取时自愈（repair）**，而不是一次性迁移。理由和排除项见第 3、4 节。

---

## 1. 为什么是"已经在线上"：今天就有三个可见症状

根因：`MoneyBillReminderEntity.isActive`（`money_bill_reminder_entity.dart:123`）

```dart
bool get isActive => !isDeleted && status == MoneyBillReminderStatus.pending;
```

而**全库至今没有任何一处**写过 `MoneyBillReminderStatus.done`（grep 零命中）。
唯一的终止手段是 `deleteBillReminder`（它会置 `cancelled` + `isDeleted = true`）。
所以用户在提醒中心点过「完成」或「忽略」之后，`status` 永远停在 `pending`。

### 症状 1：系统通知停不下来，逾期后逐日重复推送

链路：`scanNow()`（`bookkeeping_providers.dart:1600`）→
`currentUserBillRemindersProvider`（`:1126`，底层 `watchBillRemindersForUser` **不带 status 过滤**）→
`MoneyBillReminderNotificationService.scanAndNotify`（`:17`）→ 只靠 `reminder.isActive` 判 skip。

于是这条已处理的提醒继续通往下发，并且 `_alertToken`（`:103-113`）里带了 `overdueDays`：

```dart
return '${alert.dueDate.millisecondsSinceEpoch}:${reminder.status.storageValue}'
    '${overdue > 0 ? ':od$overdue' : ''}';
```

→ 逾期N天推一次，第二天 `od` 变 N+1，token 变化 → **再推一次，每天如此**。
用户视角就是「我都点完成了，还天天弹信用卡还款提醒」。

退路只有一条：`prefs.remove(storageKey)` 只在 `!isActive` 或 `amountMinor <= 0` 时触发——
前者永远不成立（这就是 bug），后者只对 `amountSource == creditAccountDebt` 且欠款归零有效。

### 症状 2：统计页「即将到期账单」金额虚高

`money_upcoming_bills_card.dart:36-37`

```dart
for (final bill in bills) {
  if (!bill.isActive) { continue; }
```

`bills` 来自 `currentUserBillRemindersProvider`（全量、**不按 status 过滤**，
见 `money_statistics_section.dart:352` → `:1151`）。
→ 已处理完的账单仍计入「未来待付」，预测现金流偏大。

### 症状 3（潜在）：编辑到期日后「复活」

`itemKey = sourceType:sourceId:YYYY-MM-DD(dueDate)`，含到期日。
用户把一条早先已完成的提醒改了日期 → key 失配 → 处理记录遮不住 → 它回到待处理列表。

---

## 2. 受影响数据的精确范围

满足全部条件的数据：

```
moneyBillReminders
  is_deleted = 0
  status     = 'pending'
  repeat_period_type IS NULL      -- 排除周期性提醒，见 4.2
  auto_managed = 0                -- 排除自动托管提醒，见 4.3（硬约束）
且存在 money_reminder_center_processing 记录满足
  item_key = 'bill_reminder|<id>|<dueDate>'  或  'credit_card_bill|<id>|<dueDate>'
  state   IN ('completed', 'ignored')
  is_deleted = 0
```

非重复提醒的 `dueDate` 不滚动，且 `_billReminderCenterItem`（`drift_money_repository.dart:4068`）
用的是**原始** `reminder.dueDate`（不是 `effectiveBillReminderDueDate`），
所以 key 可以离线用静态值算出来，链路闭合。

> 明确**不**处理：没有处理记录、单纯被用户遗忘的逾期提醒。
> 它在待处理里显示为「已逾期」是正确行为，不该被悄悄置终态。

---

## 3. 三个方案对比

| 方案 | 做法 | 评价 |
| --- | --- | --- |
| ① 一次性迁移 | 写迁移脚本 + 执行标记，启动刷一遍 | **不推荐** |
| ② 读取时自愈 | provider 流里 yield 前调 repair | **推荐** |
| ③ 改 `isActive` 语义 | 把"有无终态处理记录"纳入 active 判断 | 备选 |

### 为什么不推荐 ①

- 本仓库没有 Handshake/版本标记的迁移设施，得自己造「已执行标记」存 SharedPreferences
- 不可逆，且多端场景下各端执行时机不可控
- **无法覆盖未来新产生的不一致**（比如跨端同步回填的行）
- 一旦漏跑，用户端症状持续

### 为什么推荐 ②

**这个仓库已经有完全相同的先例**——`currentUserInstallmentPlansProvider`
（`bookkeeping_providers.dart:1389`，`repairInstallmentPlanStatuses`）就是这么做的：

```dart
await repository.repairInstallmentPlanStatuses(userId, ledgerId: ledger.id);
yield* repository.watchInstallmentPlansForUser(userId, ledgerId: ledger.id);
```

照抄这个模式到 `currentUserBillRemindersProvider`（`:1126-1148`）即可。优点：

- 幂等、可按 session 收敛、不需要迁移标记
- 每端各自收敛，天然适配多端/远端同步回填的场景
- 和既有代码风格一致，不需要新概念

### ③ 作为备选

零写入、不用写 repair。但需要给「是否 active」的判断注入 processing 数据，
`MoneyBillReminderEntity.isActive` 就得带参或改成外部计算，
而 `isActive` 目前被通知服务、`money_upcoming_bills_card` 等多处直接消费，
扩散面反而比 ② 更大。**只在完全不想碰数据库写入时考虑。**

---

## 4. 实现要点与三个必须排除项

### 4.1 函数签名与挂载点

`lib/features/bookkeeping/domain/money_repository.dart`

```dart
/// 把「已在提醒中心处理过（completed/ignored）但 status 仍是 pending」的
/// 非重复、非自动托管账单提醒收敛为 done。幂等，可重复执行。
Future<int> repairBillReminderProcessingStatuses(
  String userId, {
  String? ledgerId,
});
```

返回受影响行数，便于测试和临时埋点。

**挂载**：`bookkeeping_providers.dart:1148` 之前，与 installment 的写法对齐：

```dart
await repository.repairBillReminderProcessingStatuses(userId, ledgerId: ledger.id);
yield* repository.watchBillRemindersForUser(userId, ledgerId: ledger.id);
```

> `currentUserBillRemindersProvider` 是 `autoDispose` 且被统计页和提醒中心同时 watch，
> repair 会随每次实例化跑一遍。个人账本量级下两条查询可接受；
> 若要省，可在 session 内加一次性 guard（照 `_scheduleBillReminderScan` 的写法）。

### 4.2 排除周期性提醒（`repeatPeriodType != null`）

否则：6 月处理完 → 置 `done` → 7 月不再出现，周期性提醒被一次性杀死。

顺带点出一个既有事实：周期性提醒的 itemKey 依赖滚动后的 `dueDate`，
下一次滚动会产生新 key、旧处理记录遮不住 → 自动重新出现。
**这恰好就是重复提醒期望的行为**，所以让它们永远保持 `pending` 是对的。

代价是 4.1 对周期性提醒永久无效：症状 1、2 在周期性提醒上依然存在。
这个遗留限制建议在方案里显式记下来，不要假装已解决（见第 7 节）。

### 4.3 排除自动托管提醒（`autoManaged == true`）— 硬约束

查 `_syncCreditAccountRepaymentReminder`（`drift_money_repository.dart:1196-1400`）会发现两件事：

```dart
'status': MoneyBillReminderStatus.pending.storageValue,   // :1245
'related_transaction_id': null,                           // :1244
...
_putIfChanged(changedFields, 'status', existing.status, pending);  // :1351
```

而且它的调用点遍布**每一次流水写入**
（`transactions.dart:280/451/564/693/823/859/907`、`accounts.dart:404/480/527/570/638`、
`installments.dart:569`、`auto_posting.dart:463`）。

两条硬结论：

1. **`status` 会被随时重置回 `pending`。** 若 repair 把它置 `done`，
   下一次任何一笔记账触发 sync，`changedFields` 就会带上 status → 变回 pending →
   repair 再置 done → **两个逻辑互相踢，version 无限递增**。必须整体排除。
2. **`relatedTransactionId` 会被清成 `null`。**
   阶段 A 设计的 `linkBillReminderTransaction` 对这类提醒没有意义，同样要跳过。

识别方式：`sourceKey` 形如 `credit_repayment::<accountId>`（`_creditRepaymentReminderSourceKey:3697`），
或更直接地用 `autoManaged` 布尔列。

**好消息**：这类提醒有它自己的正确终止路径——`amountDueMinor <= 0` 时
`_deleteAutoManagedBillReminder` 会删掉它（`:1231-1236`）。
也就是说，只要走「完成 = 真的记了还款流水」，欠款下降，它自然消失。
**这反过来验证了决策 1（完成必须记账）是对的方向。**

### 4.4 参考实现骨架

```dart
Future<int> repairBillReminderProcessingStatuses(
  String userId, {String? ledgerId}) async {
  final resolvedLedgerId =
      ledgerId == null ? null : await _resolveLedgerId(userId, ledgerId);

  final query = database.select(database.moneyBillReminders)
    ..where((r) =>
        r.userId.equals(userId) &
        r.isDeleted.equals(false) &
        r.status.equals(MoneyBillReminderStatus.pending.storageValue) &
        r.autoManaged.equals(false) &
        r.repeatPeriodType.isNull() &
        (resolvedLedgerId == null
            ? const Constant(true)
            : (r.ledgerId.equals(resolvedLedgerId) | r.ledgerId.isNull())));

  final candidates = await query.get();
  if (candidates.isEmpty) return 0;

  final keysByReminderId = {
    for (final r in candidates)
      r.id: MoneyReminderCenterItem(
        sourceType: r.sourceType ==
                MoneyBillReminderSourceType.creditRepayment.storageValue
            ? MoneyReminderCenterSourceType.creditCardBill
            : MoneyReminderCenterSourceType.billReminder,
        sourceId: r.id,
        title: r.name,
        dueDate: _dateFromKey(r.dueDate),
        amountMinor: r.amountMinor,
        currencyCode: r.currencyCode,
        actionType: MoneyReminderCenterActionType.openReminder, // 不参与 key
      ).itemKey,
  };

  final records =
      await (database.select(database.moneyReminderCenterProcessing)..where((p) =>
          p.userId.equals(userId) &
          p.isDeleted.equals(false) &
          p.itemKey.isIn(keysByReminderId.values.toSet().toList()) &
          p.state.isIn([
            MoneyReminderCenterState.completed.storageValue,
            MoneyReminderCenterState.ignored.storageValue,
          ])))
          .get();
  if (records.isEmpty) return 0;

  final terminalKeys = records.map((e) => e.itemKey).toSet();
  final now = _utcNow();
  var count = 0;
  for (final reminder in candidates) {
    if (!terminalKeys.contains(keysByReminderId[reminder.id])) continue;
    await (database.update(database.moneyBillReminders)
          ..where((r) => r.id.equals(reminder.id) & r.userId.equals(userId)))
        .write(MoneyBillRemindersCompanion(
          status: Value(MoneyBillReminderStatus.done.storageValue),
          version: Value(reminder.version + 1),
          updatedAt: Value(now),
        ));
    await _recordBillReminderChange(
      userId: userId,
      recordId: reminder.id,
      operation: SyncChangeOperation.update,
      changedFields: {'status': MoneyBillReminderStatus.done.storageValue},
      beforeVersion: reminder.version,
      afterVersion: reminder.version + 1,
    );
    count++;
  }
  return count;
}
```

> `ignored` 也映射成 `done`：`MoneyBillReminderStatus` 只有 `pending/done/cancelled` 三态，
> 「完成 vs 忽略」的真值始终留在 processing 记录里，不需要为此加枚举值
> （加值会牵动 storageValue 和 sync payload，不划算）。

---

## 5. 与其他阶段的耦合

- **必须先于或与阶段 A 同批做**。只做 A 不做 repair → 存量数据照常重复推送，用户体感没变。
- **阶段 A 的 `_syncSource` 要补两条守卫**：`autoManaged` 跳过、`repeatPeriodType != null` 跳过（跳过 baseline 已有）。
- **`linkBillReminderTransaction` 对 autoManaged 跳过**（写了也会被 sync 清 null）。
- **阶段 B/C/D 上线后 repair 会自然退化为 no-op**（新流程会把 status 直接写对），
  保留它作为跨端同步回填的收敛兜底即可，不会有副作用。

---

## 6. 验证方式

仓储层用例（`test/features/bookkeeping/data/`）：

1. 造一条非重复提醒 + 一条 `completed` 的 processing 记录 → repair 后 status 为 `done`，返回 1
2. 再跑一次 → 返回 0（幂等性）
3. 周期性提醒（`repeatPeriodType = monthly`）+ 终态处理记录 → status 仍为 `pending`
4. `autoManaged = true` + 终态处理记录 → status 仍为 `pending`
5. 只有非终态处理记录（`snoozed`）→ status 仍为 `pending`
6. repair 后 `isActive == false`，且 `_alertFor` 链路不再产生 token（可直接断言 `isActive`）
7. `ignored` 也会收敛为 `done`

8. repair 之后该提醒**不再**出现在 `getPendingReminderCenterItems`
   （源数据已经是 `done`，不再进 source items）——这是预期结果；
   但 `getReminderCenterHistory` 必须仍能读到那条 completed/ignored 记录。

---

## 7. 遗留限制（建议显式接受，不要假装已解决）

**周期性提醒无法用本次修正摆平。** 它们的 `status` 必须永远保持 `pending` 才能在下一周期重新出现，
代价是症状 1、2 在周期性提醒上继续存在：处理完这一期，逾期后通知仍可能再推。

真正的解法是给周期性提醒引入「本期已处理」的概念——
即 processing 记录的 itemKey 已有 `dueDate` 粒度，让**通知服务和统计卡也按 itemKey 过滤**，
而不是只看 reminder 的 `status`。这是一个独立、更大的改造（涉及通知服务入参、统计卡入参），
建议单独立项，不在本次范围。

短期内如果想要缓解，最低成本的补丁是：让 `MoneyBillReminderNotificationService.scanAndNotify`
也接收 `pending` 列表（通知服务的入口 `scanNow()` 里**已经算过**
`currentUserPendingReminderCenterItemsProvider`，见 `:1624`），
用它来过滤掉已有终态处理记录的提醒。这条改动很小（十几行），
可以作为一个可选的「阶段 0.5」先上线止血。

---

## 8. 建议

1. **先做阶段 0.5**（可选补丁，十几行）：把 `scanNow()` 里已经算好的 `pending` 列表传给通知服务，
   立即止住「已处理还天天推」。
2. **再做 repair（本文）**：结构性修复，覆盖非重复提醒的三个症状。
3. **最后做阶段 A**：从源头杜绝继续产生这类不一致。
