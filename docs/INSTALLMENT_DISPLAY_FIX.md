# 分期交易字段显示问题修复

## 问题描述
编辑分期交易时：
1. **分期字段显示为空**：总期数、每期金额、首期日期没有显示值
2. **分期计划列表缺少信息**：期数和日期信息未显示

## 问题分析

### 1. 数据流程
```
后端 Transaction → 前端 props.transaction → form.value → 显示
                                                ↓
                            loadInstallmentPlanDetails() → installmentPlanDetails
```

### 2. 已修复的问题

#### 问题 A: Form 初始化时数字字段可能为 undefined
**原因**: 从 transaction 对象扩展时，分期字段可能为 `null` 或 `undefined`

**修复**: 
```typescript
// 确保分期相关字段都是有效的数字
totalPeriods: Number(trans.totalPeriods) || 0,
remainingPeriods: Number(trans.remainingPeriods) || 0,
installmentAmount: Number(trans.installmentAmount) || 0,
remainingPeriodsAmount: Number(trans.remainingPeriodsAmount) || 0,
firstDueDate: trans.firstDueDate || undefined,
```

#### 问题 B: Transaction watcher 没有保留 firstDueDate
**修复**: 添加 `firstDueDate: transaction.firstDueDate || undefined`

#### 问题 C: loadInstallmentPlanDetails 可能覆盖空值
**修复**: 添加 null 检查
```typescript
// 更新表单中的分期相关字段（如果有值才更新）
if (response.total_periods !== undefined && response.total_periods !== null) {
  form.value.totalPeriods = Number(response.total_periods);
  form.value.remainingPeriods = Number(response.total_periods);
}
if (response.installment_amount !== undefined && response.installment_amount !== null) {
  form.value.installmentAmount = Number(response.installment_amount);
}
if (response.first_due_date) {
  form.value.firstDueDate = response.first_due_date;
}
```

### 3. 分期计划显示

分期计划通过 `installmentDetails` computed 属性生成：

```typescript
const installmentDetails = computed(() => {
  // 编辑模式：使用分期计划详情数据
  if (installmentPlanDetails.value && installmentPlanDetails.value.details) {
    return installmentPlanDetails.value.details.map(detail => ({
      period: detail.period_number,        // 期数
      amount: Number(safeToFixed(detail.amount)),
      dueDate: detail.due_date,            // 到期日期
      status: detail.status || 'PENDING',
      paidDate: detail.paid_date,          // 入账日期
      paidAmount: detail.paid_amount,
    }));
  }
  // ...
});
```

显示模板：
```vue
<span class="period-label">
  {{ t('financial.transaction.period', { period: detail.period }) }}
</span>
<span class="due-date">{{ detail.dueDate }}</span>
<span class="paid-date">入账日期: {{ detail.paidDate }}</span>
```

## 后端数据结构

### InstallmentPlanResponse
```rust
pub struct InstallmentPlanResponse {
    pub serial_num: String,
    pub transaction_serial_num: String,
    pub total_amount: Decimal,
    pub total_periods: i32,              // ✓ 总期数
    pub installment_amount: Decimal,      // ✓ 每期金额
    pub first_due_date: NaiveDate,       // ✓ 首期日期
    pub status: String,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
    pub details: Vec<InstallmentDetailResponse>,
}
```

### InstallmentDetailResponse
```rust
pub struct InstallmentDetailResponse {
    pub serial_num: String,
    pub plan_serial_num: String,
    pub period_number: i32,              // ✓ 期数
    pub due_date: NaiveDate,             // ✓ 到期日期
    pub amount: Decimal,
    pub status: String,
    pub paid_date: Option<NaiveDate>,    // ✓ 入账日期
    pub paid_amount: Option<Decimal>,
    pub created_at: DateTime<FixedOffset>,
    pub updated_at: Option<DateTime<FixedOffset>>,
}
```

## 调试步骤

### 1. 检查后端返回数据
在浏览器控制台查看日志：
```
已加载分期计划详情: {
  totalPeriods: 3,
  installmentAmount: 41,
  firstDueDate: "2025-11-17",
  detailsCount: 3
}
```

### 2. 检查 Transaction 对象
编辑交易时，查看 `props.transaction` 是否包含分期字段：
```javascript
console.log('Transaction:', props.transaction);
// 应该包含:
// - isInstallment: true
// - totalPeriods: 3
// - installmentAmount: 123
// - firstDueDate: "2025-11-17"
// - installmentPlanSerialNum: "..."
```

### 3. 检查 installmentPlanDetails
```javascript
console.log('installmentPlanDetails:', installmentPlanDetails.value);
// 应该包含完整的分期计划数据
```

### 4. 检查 installmentDetails computed
```javascript
console.log('installmentDetails:', installmentDetails.value);
// 应该是一个数组，每个元素包含:
// { period, amount, dueDate, status, paidDate, paidAmount }
```

## 可能的其他问题

### 问题 1: installmentPlanSerialNum 为 null
如果交易的 `installmentPlanSerialNum` 为 `null`，`loadInstallmentPlanDetails` 不会被调用。

**检查**: 确认创建分期交易时正确保存了 `installment_plan_serial_num`

### 问题 2: 日期格式问题
NaiveDate 在 Rust 中格式为 `"YYYY-MM-DD"`，前端应该能正确显示。

**检查**: 查看 `detail.dueDate` 和 `detail.paidDate` 的值

### 问题 3: status 字段大小写
后端使用 `"PENDING"`, `"PAID"`，前端也应该匹配。

## 修改文件

### src/features/money/components/TransactionModal.vue

1. **Form 初始化** (行 83-100)
2. **Transaction watcher** (行 853-886)
3. **loadInstallmentPlanDetails** (行 219-254)

## 测试清单

- [ ] 创建新的分期交易
- [ ] 保存后立即编辑，检查字段是否显示
- [ ] 刷新页面后编辑，检查字段是否显示
- [ ] 检查分期计划列表的期数显示
- [ ] 检查分期计划列表的到期日期显示
- [ ] 完成一期入账后，检查入账日期显示
- [ ] 查看浏览器控制台日志，确认数据加载

## 预期结果

### 编辑分期交易时
- 总期数输入框显示正确的值（如 3）
- 每期金额输入框显示正确的值（如 41.00）
- 首期日期输入框显示正确的日期（如 2025-11-17）

### 分期计划列表
每一项显示：
```
第 1 期          [已入账]
到期日期: 2025-11-17
¥41.00
入账日期: 2025-11-17
实付: ¥41.00
```

## 相关文件
- 前端组件: `src/features/money/components/TransactionModal.vue`
- 前端类型: `src/services/money/transactions.ts`
- 前端 Schema: `src/schema/money/transaction.ts`
- 后端 DTO: `src-tauri/crates/money/src/dto/installment.rs`
- 后端 Service: `src-tauri/crates/money/src/services/installment.rs`
- 后端 Command: `src-tauri/crates/money/src/command.rs`
