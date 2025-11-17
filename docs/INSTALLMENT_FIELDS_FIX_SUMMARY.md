# 分期字段显示完整修复总结

## 问题描述
用户反馈编辑分期交易时，以下字段没有显示值：
1. ✅ **第几期** - 已修复
2. ❌ **每期金额** - 现已修复
3. ❌ **入账日期**（已入账的期） - 现已修复
4. ❌ **待入账日期**（应还日期） - 现已修复

## 核心数据源

### installment_details 表
所有需要的字段都在这个表中：
```sql
CREATE TABLE installment_details (
  serial_num TEXT PRIMARY KEY,
  plan_serial_num TEXT NOT NULL,
  period_number INTEGER NOT NULL,      -- ✓ 第几期
  due_date DATE NOT NULL,              -- ✓ 到期日期（应还日期）
  amount DECIMAL NOT NULL,             -- ✓ 每期金额
  status TEXT NOT NULL,                -- ✓ 状态（PENDING/PAID/OVERDUE）
  paid_date DATE,                      -- ✓ 入账日期
  paid_amount DECIMAL,                 -- ✓ 实付金额
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP
);
```

## 修复方案

### 1. 改进 `installmentDetails` Computed（行 285-347）

#### 关键改进点：
```typescript
// 获取第一期的金额作为默认值
const firstPeriodAmount = sourceDetails.length > 0 
  ? Number(sourceDetails[0].amount) 
  : 0;

const details = sourceDetails.map(detail => {
  const amount = detail.amount ? Number(detail.amount) : firstPeriodAmount;
  return {
    period: detail.period_number,        // ✓ 期数
    amount: amount,                      // ✓ 金额（使用第一期作为降级）
    dueDate: detail.due_date || '',      // ✓ 到期日期
    status: detail.status || 'PENDING',  // ✓ 状态
    paidDate: detail.paid_date || null,  // ✓ 入账日期
    paidAmount: detail.paid_amount ? Number(detail.paid_amount) : null,
  };
});
```

#### 详细日志输出：
```typescript
console.log('📊 分期计划详情列表（编辑模式）:', {
  detailsCount: details.length,
  firstPeriodAmount,
  details: details.map(d => ({
    period: d.period,
    amount: d.amount,
    dueDate: d.dueDate,
    status: d.status,
    paidDate: d.paidDate,
  })),
});
```

### 2. 改进 `calculatedInstallmentAmount` Computed（行 275-291）

#### 关键改进点：
```typescript
if (installmentPlanDetails.value) {
  // 优先使用 installment_amount
  if (installmentPlanDetails.value.installment_amount) {
    return Number(installmentPlanDetails.value.installment_amount);
  }
  // 降级方案：使用第一期的金额
  if (installmentPlanDetails.value.details && 
      installmentPlanDetails.value.details.length > 0) {
    return Number(installmentPlanDetails.value.details[0].amount) || 0;
  }
  return 0;
}
```

**作用**：确保"每期金额"输入框显示正确的值，即使 `installment_amount` 字段为空。

### 3. 改进显示模板（行 1416-1439）

#### 期数和状态显示：
```vue
<span class="period-label">第 {{ detail.period || (index + 1) }} 期</span>
<span class="status-text">{{ getStatusText(detail.status) }}</span>
```

#### 到期日期显示：
```vue
<span class="due-date">
  {{ detail.status === 'PAID' ? '到期日' : '应还日' }}: 
  {{ detail.dueDate || '未设置' }}
</span>
```

#### 金额显示：
```vue
<span class="amount-label">
  ¥{{ detail.amount ? safeToFixed(detail.amount) : '0.00' }}
</span>
```

#### 状态详情显示：
```vue
<!-- 已入账 -->
<div v-if="detail.status === 'PAID'">
  <span class="paid-date">入账: {{ detail.paidDate || '未知' }}</span>
  <span class="paid-amount">实付: ¥{{ safeToFixed(detail.paidAmount) }}</span>
</div>

<!-- 待入账 -->
<div v-else-if="detail.status === 'PENDING'">
  <span class="pending-text">待入账 ({{ detail.dueDate || '未设置日期' }})</span>
</div>

<!-- 已逾期 -->
<div v-else-if="detail.status === 'OVERDUE'">
  <span class="overdue-text">已逾期 ({{ detail.dueDate || '未知' }})</span>
</div>
```

## 预期显示效果

### 示例：3期分期交易，第1期已入账

#### 分期字段（顶部输入框）
- **总期数**: `3`
- **每期金额**: `40.00` ← 从第一期的金额获取
- **首期日期**: `2025-11-17`

#### 分期计划列表

**第 1 期 [已入账]**
- 到期日: 2025-11-17
- ¥40.00
- 入账: 2025-11-17
- 实付: ¥40.00

**第 2 期 [待入账]**
- 应还日: 2025-12-17
- ¥40.00
- 待入账 (2025-12-17)

**第 3 期 [待入账]**
- 应还日: 2026-01-17
- ¥40.00
- 待入账 (2026-01-17)

## 数据流程

```
后端 installment_details 表
    ↓ (period_number, amount, due_date, status, paid_date, paid_amount)
installmentPlanDetails.value.details[]
    ↓ 映射处理
installmentDetails computed
    ↓
模板显示
```

### 关键字段映射
```typescript
// 后端字段 → 前端字段
period_number  → period      // 第几期
amount         → amount      // 每期金额
due_date       → dueDate     // 到期/应还日期
status         → status      // 状态
paid_date      → paidDate    // 入账日期
paid_amount    → paidAmount  // 实付金额
```

## 调试日志

编辑分期交易时，控制台会输出：

```
📝 加载交易数据: {
  isInstallment: true,
  totalPeriods: 3,
  installmentAmount: 120,
  firstDueDate: "2025-11-17",
  ...
}

📋 表单初始化后的分期字段: {
  totalPeriods: 3,
  installmentAmount: 120,
  firstDueDate: "2025-11-17"
}

🔄 使用交易序列号加载分期计划: ...

✅ 已加载分期计划详情: {
  totalPeriods: 3,
  installmentAmount: 40,
  firstDueDate: "2025-11-17",
  detailsCount: 3
}

📊 分期计划详情列表（编辑模式）: {
  detailsCount: 3,
  firstPeriodAmount: 40,
  details: [
    {
      period: 1,
      amount: 40,
      dueDate: "2025-11-17",
      status: "PAID",
      paidDate: "2025-11-17"
    },
    {
      period: 2,
      amount: 40,
      dueDate: "2025-12-17",
      status: "PENDING",
      paidDate: null
    },
    {
      period: 3,
      amount: 40,
      dueDate: "2026-01-17",
      status: "PENDING",
      paidDate: null
    }
  ]
}
```

## 修改的文件

### 前端
- ✅ `src/features/money/components/TransactionModal.vue`
  - 行 275-291: 改进 `calculatedInstallmentAmount` 计算逻辑
  - 行 285-347: 改进 `installmentDetails` 数据映射
  - 行 1416-1439: 改进显示模板

### 后端（上一步已完成）
- ✅ `src-tauri/crates/money/src/services/installment.rs`
- ✅ `src-tauri/crates/money/src/command.rs`
- ✅ `src-tauri/src/commands.rs`

## 测试清单

- [ ] 创建新的3期分期交易（金额120）
- [ ] 保存后编辑，检查：
  - [ ] 总期数显示：3
  - [ ] 每期金额显示：40.00
  - [ ] 首期日期显示：正确日期
- [ ] 检查分期计划列表：
  - [ ] 每期显示"第 X 期"
  - [ ] 每期显示金额"¥40.00"
  - [ ] 待入账期显示"应还日: YYYY-MM-DD"
  - [ ] 待入账期显示"待入账 (YYYY-MM-DD)"
- [ ] 完成第1期入账
- [ ] 再次编辑，检查：
  - [ ] 第1期显示"到期日: YYYY-MM-DD"
  - [ ] 第1期显示"入账: YYYY-MM-DD"
  - [ ] 第1期显示"实付: ¥40.00"
  - [ ] 第2期和第3期仍显示"应还日"
- [ ] 查看浏览器控制台，确认所有日志正常

## 故障排查

### 如果金额仍然显示为 0.00

1. **检查后端数据**：
   ```sql
   SELECT period_number, amount, due_date, status, paid_date
   FROM installment_details
   WHERE plan_serial_num = 'YOUR_PLAN_SERIAL_NUM'
   ORDER BY period_number;
   ```

2. **检查浏览器控制台日志**：
   - 查看 `📊 分期计划详情列表` 日志
   - 确认 `firstPeriodAmount` 有值
   - 确认每个 `detail.amount` 有值

3. **检查 installmentPlanDetails**：
   ```javascript
   console.log('installmentPlanDetails:', installmentPlanDetails.value);
   console.log('details[0].amount:', installmentPlanDetails.value?.details[0]?.amount);
   ```

### 如果日期不显示

1. **检查后端返回的日期格式**：
   - 应该是 `"YYYY-MM-DD"` 格式
   - 检查 `detail.due_date` 和 `detail.paid_date`

2. **检查日志输出**：
   ```javascript
   console.log('detail.dueDate:', detail.dueDate);
   console.log('detail.paidDate:', detail.paidDate);
   ```

### 如果状态不正确

1. **检查数据库中的 status 值**：
   - 应该是 `"PENDING"`, `"PAID"`, 或 `"OVERDUE"`
   - 大小写敏感

2. **检查模板条件**：
   ```vue
   <div v-if="detail.status === 'PAID'">  <!-- 注意大小写 -->
   ```

## 相关文档
- `INSTALLMENT_COMPLETE_FIX.md` - 完整修复方案
- `INSTALLMENT_DISPLAY_FIX.md` - 显示问题分析
- `INSTALLMENT_DEBUG_GUIDE.md` - 调试指南
- `INSTALLMENT_CALCULATION_FIX.md` - 计算问题修复

## 关键要点

1. ✅ **每期金额**：从 `installment_details` 表的 `amount` 字段获取，如果为空则使用第一期的金额
2. ✅ **入账日期**：从 `installment_details` 表的 `paid_date` 字段获取（仅已入账的期）
3. ✅ **应还日期**：从 `installment_details` 表的 `due_date` 字段获取（所有期都显示）
4. ✅ **状态区分**：
   - PAID：显示"到期日"和"入账日期"
   - PENDING：显示"应还日"
   - OVERDUE：显示"已逾期"并显示应还日期
5. ✅ **容错处理**：所有字段都有后备值，防止显示空白
