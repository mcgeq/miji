# 分期交易显示问题调试指南

## 问题现象
1. 编辑分期交易时，总期数、每期金额、首期日期字段为空
2. 分期计划列表中缺少"第X期"和日期信息

## 调试步骤

### 步骤 1: 打开浏览器控制台

在 Chrome/Edge 中按 `F12` 打开开发者工具，切换到 Console 标签页。

### 步骤 2: 编辑一个分期交易

点击编辑按钮，查看控制台输出的日志。

### 步骤 3: 检查日志输出

#### 应该看到的日志（按顺序）:

```
📝 加载交易数据: {
  serialNum: "20251117121424139770400747635632515955",
  isInstallment: true,
  totalPeriods: 3,                    // ← 应该有值
  installmentAmount: 123,             // ← 应该有值
  firstDueDate: "2025-11-17",        // ← 应该有值
  installmentPlanSerialNum: "20251117121424139770400747635632515956"  // ← 应该有值
}
```

```
📋 表单初始化后的分期字段: {
  totalPeriods: 3,                    // ← 应该有值
  installmentAmount: 123,             // ← 应该有值
  firstDueDate: "2025-11-17"         // ← 应该有值
}
```

```
🔄 开始加载分期计划详情: 20251117121424139770400747635632515956
```

```
已加载分期计划详情: {
  totalPeriods: 3,                    // ← 应该有值
  installmentAmount: 41,              // ← 应该有值（平均分摊）
  firstDueDate: "2025-11-17",        // ← 应该有值
  detailsCount: 3                     // ← 应该有值
}
```

```
📊 分期计划详情列表（编辑模式）: [
  {
    period: 1,                        // ← 第1期
    amount: 41,
    dueDate: "2025-11-17",           // ← 到期日期
    status: "PENDING",
    paidDate: null,
    paidAmount: null
  },
  {
    period: 2,                        // ← 第2期
    amount: 41,
    dueDate: "2025-12-17",
    status: "PENDING",
    paidDate: null,
    paidAmount: null
  },
  {
    period: 3,                        // ← 第3期
    amount: 41,
    dueDate: "2026-01-17",
    status: "PENDING",
    paidDate: null,
    paidAmount: null
  }
]
```

## 问题诊断

### 场景 A: transaction 对象中字段为 null

**现象**: 
```
📝 加载交易数据: {
  totalPeriods: null,               // ❌ 为 null
  installmentAmount: null,          // ❌ 为 null
  firstDueDate: null                // ❌ 为 null
}
```

**原因**: 后端 `transaction_get` 命令没有返回分期字段

**检查**: 
1. 查看后端 `TransactionResponse` 结构
2. 确认 `trans_get_response` 方法正确返回分期字段
3. 检查数据库 `transactions` 表中是否有这些字段的值

**解决**: 
- 检查 `src-tauri/crates/money/src/dto/transactions.rs` 中的 `TransactionResponse`
- 确保 `From<TransactionWithRelations>` 实现正确映射字段

### 场景 B: installmentPlanSerialNum 为 null

**现象**:
```
📝 加载交易数据: {
  installmentPlanSerialNum: null    // ❌ 为 null
}
⚠️ 分期交易但没有分期计划SerialNum
```

**原因**: 创建分期交易时没有正确保存 `installment_plan_serial_num`

**检查**:
1. 查看 `transaction_hooks::after_create` 是否创建了分期计划
2. 查看数据库 `transactions` 表的 `installment_plan_serial_num` 字段

**解决**:
- 检查 `src-tauri/crates/money/src/services/transaction_hooks.rs::after_create`
- 确保分期计划创建成功并更新到 transaction

### 场景 C: loadInstallmentPlanDetails 失败

**现象**:
```
🔄 开始加载分期计划详情: ...
Error 加载分期计划详情失败: ...
```

**原因**: 
- 分期计划不存在
- 数据库查询失败
- 网络请求失败

**检查**:
1. 查看完整错误信息
2. 检查数据库 `installment_plans` 表
3. 检查数据库 `installment_details` 表

### 场景 D: details 数组为空

**现象**:
```
已加载分期计划详情: {
  detailsCount: 0                    // ❌ 应该 > 0
}
📊 分期计划详情列表: null
```

**原因**: `installment_details` 表中没有数据

**检查**:
1. 查看数据库 `installment_details` 表
2. 检查 `create_installment_plan_with_details` 是否正确创建明细

### 场景 E: 字段值正确但页面不显示

**现象**: 控制台日志显示所有值都正确，但页面上输入框仍然为空

**可能原因**:
1. Vue 响应式更新问题
2. 输入框绑定错误
3. CSS 隐藏了内容
4. 表单验证阻止了更新

**检查**:
1. 在浏览器中使用 Vue DevTools 查看 `form.value`
2. 检查输入框的 `v-model` 绑定
3. 检查 CSS 样式
4. 暂时禁用表单验证

## SQL 查询检查

### 检查 transaction 表
```sql
SELECT 
  serial_num,
  is_installment,
  total_periods,
  installment_amount,
  first_due_date,
  installment_plan_serial_num
FROM transactions
WHERE serial_num = 'YOUR_TRANSACTION_SERIAL_NUM';
```

### 检查 installment_plans 表
```sql
SELECT *
FROM installment_plans
WHERE transaction_serial_num = 'YOUR_TRANSACTION_SERIAL_NUM';
```

### 检查 installment_details 表
```sql
SELECT *
FROM installment_details
WHERE plan_serial_num = 'YOUR_PLAN_SERIAL_NUM'
ORDER BY period_number;
```

## 快速修复

### 如果 transaction 字段为 null

后端可能没有正确保存。手动更新数据库：

```sql
UPDATE transactions
SET 
  total_periods = 3,
  installment_amount = 41.00,
  first_due_date = '2025-11-17',
  installment_plan_serial_num = (
    SELECT serial_num 
    FROM installment_plans 
    WHERE transaction_serial_num = transactions.serial_num
    LIMIT 1
  )
WHERE serial_num = 'YOUR_TRANSACTION_SERIAL_NUM'
  AND is_installment = 1;
```

### 如果分期计划不存在

重新创建分期计划需要调用后端 API 或者手动插入数据库。

## 相关代码位置

### 前端
- 组件: `src/features/money/components/TransactionModal.vue`
  - 行 219-254: `loadInstallmentPlanDetails()`
  - 行 267-296: `installmentDetails` computed
  - 行 866-915: transaction watcher

### 后端
- Command: `src-tauri/crates/money/src/command.rs::installment_plan_get`
- Service: `src-tauri/crates/money/src/services/installment.rs::get_installment_plan`
- DTO: `src-tauri/crates/money/src/dto/installment.rs`
- Hooks: `src-tauri/crates/money/src/services/transaction_hooks.rs::after_create`

## 测试用例

创建一个测试分期交易：

```typescript
const testTransaction = {
  amount: 120,
  isInstallment: true,
  totalPeriods: 3,
  firstDueDate: new Date(),
  installmentAmount: 40,
  // ... 其他必需字段
};
```

保存后立即编辑，检查：
1. ✅ 总期数显示: 3
2. ✅ 每期金额显示: 40.00
3. ✅ 首期日期显示: 正确日期
4. ✅ 分期计划列表有 3 项
5. ✅ 每项显示"第 X 期"
6. ✅ 每项显示到期日期

## 需要帮助？

如果按照以上步骤仍无法解决问题，请提供：
1. 完整的控制台日志（包括所有 emoji 日志）
2. 数据库查询结果（SQL 结果）
3. 交易的 `serial_num`
4. 浏览器和版本信息
