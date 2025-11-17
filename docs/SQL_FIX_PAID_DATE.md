# 修复已入账分期的 paid_date 字段

## 问题描述
某些分期明细的 `status = 'PAID'`（已入账），但 `paid_date` 字段为 `NULL`，导致前端无法显示入账日期。

## 原因分析
可能的原因：
1. 分期明细通过手动方式标记为 PAID，跳过了正常的入账流程
2. 旧数据：在添加 `paid_date` 字段之前就已经标记为 PAID
3. 数据迁移过程中遗漏了 `paid_date` 的更新

## 检查问题数据

### 查询没有 paid_date 的已入账记录
```sql
SELECT 
  d.serial_num,
  d.plan_serial_num,
  d.period_number,
  d.due_date,
  d.amount,
  d.status,
  d.paid_date,
  d.paid_amount,
  p.transaction_serial_num,
  t.date as transaction_date
FROM installment_details d
LEFT JOIN installment_plans p ON d.plan_serial_num = p.serial_num
LEFT JOIN transactions t ON p.transaction_serial_num = t.serial_num
WHERE d.status = 'PAID'
  AND d.paid_date IS NULL
ORDER BY d.created_at DESC;
```

## 修复方案

### 方案 1: 使用 due_date 作为 paid_date（推荐）
假设在到期日当天或之后入账，使用 `due_date` 作为 `paid_date`：

```sql
UPDATE installment_details
SET 
  paid_date = due_date,
  updated_at = CURRENT_TIMESTAMP
WHERE status = 'PAID'
  AND paid_date IS NULL;
```

### 方案 2: 使用交易日期作为 paid_date
如果需要更精确，可以使用关联交易的日期：

```sql
UPDATE installment_details
SET 
  paid_date = (
    SELECT DATE(t.date)
    FROM installment_plans p
    JOIN transactions t ON p.transaction_serial_num = t.serial_num
    WHERE p.serial_num = installment_details.plan_serial_num
  ),
  updated_at = CURRENT_TIMESTAMP
WHERE status = 'PAID'
  AND paid_date IS NULL;
```

### 方案 3: 使用当前日期（不推荐）
如果无法确定实际入账日期，使用当前日期：

```sql
UPDATE installment_details
SET 
  paid_date = CURRENT_DATE,
  updated_at = CURRENT_TIMESTAMP
WHERE status = 'PAID'
  AND paid_date IS NULL;
```

## 验证修复

### 1. 检查是否还有记录未修复
```sql
SELECT COUNT(*) as unfixed_count
FROM installment_details
WHERE status = 'PAID'
  AND paid_date IS NULL;
```

应该返回 `unfixed_count = 0`

### 2. 查看修复后的数据
```sql
SELECT 
  period_number,
  due_date,
  paid_date,
  status,
  amount,
  paid_amount
FROM installment_details
WHERE plan_serial_num = 'YOUR_PLAN_SERIAL_NUM'
ORDER BY period_number;
```

应该看到所有 `status = 'PAID'` 的记录都有 `paid_date` 值。

## 预防措施

### 1. 添加数据库约束（可选）
如果希望确保以后不会出现类似问题，可以添加检查约束：

```sql
-- 注意：SQLite 的 CHECK 约束在某些版本中可能不完全支持
ALTER TABLE installment_details
ADD CONSTRAINT chk_paid_date_when_paid
CHECK (
  (status = 'PAID' AND paid_date IS NOT NULL) 
  OR 
  (status != 'PAID')
);
```

### 2. 在代码中强制设置
确保所有将状态改为 PAID 的代码都同时设置 `paid_date`。

已有的正确代码示例：
```rust
// transaction_hooks.rs:672-673
detail_active.status = Set("PAID".to_string());
detail_active.paid_date = Set(Some(paid_date_now));
detail_active.paid_amount = Set(Some(first_period_detail.amount));
```

## 前端降级方案（已实现）

即使数据库中 `paid_date` 为 NULL，前端也会正确显示：

```typescript
// 降级顺序：
// 1. 优先使用 paid_date
// 2. 如果为null，使用 due_date（应还日期）
// 3. 如果都为null，显示"日期未记录"
入账: {{ detail.paidDate || detail.dueDate || '日期未记录' }}
```

这样即使数据库有问题，用户也能看到合理的日期显示。

## 执行步骤

### 安全执行（推荐）

1. **备份数据库**
   ```bash
   # 创建数据库备份
   cp your_database.db your_database_backup_$(date +%Y%m%d).db
   ```

2. **在测试环境执行**
   先在测试数据库上执行SQL，验证效果

3. **查看影响的记录数**
   ```sql
   SELECT COUNT(*) FROM installment_details
   WHERE status = 'PAID' AND paid_date IS NULL;
   ```

4. **执行修复SQL**（选择方案1）
   ```sql
   UPDATE installment_details
   SET 
     paid_date = due_date,
     updated_at = CURRENT_TIMESTAMP
   WHERE status = 'PAID'
     AND paid_date IS NULL;
   ```

5. **验证结果**
   ```sql
   -- 应该返回 0
   SELECT COUNT(*) FROM installment_details
   WHERE status = 'PAID' AND paid_date IS NULL;
   ```

6. **在前端测试**
   - 刷新页面
   - 编辑分期交易
   - 检查已入账期的入账日期是否正确显示

## 常见问题

### Q: 为什么推荐使用 due_date 作为 paid_date？
A: 因为：
1. `due_date` 是每期的应还日期，是已知且准确的
2. 通常情况下，用户会在到期日或之后入账
3. 比使用当前日期（可能是很久之后）更合理

### Q: 如果 due_date 也是 NULL 怎么办？
A: 这种情况很少见，因为 `due_date` 是 NOT NULL 字段。如果真的遇到，前端会显示"日期未记录"。

### Q: 执行 UPDATE 后需要重启应用吗？
A: 不需要。数据库更新后，下次查询就会返回新数据。只需刷新前端页面即可。

## 日志检查

执行修复后，在前端控制台应该看到：

```javascript
📊 分期计划详情列表（编辑模式）: {
  rawDetails: [
    {
      period_number: 1,
      status: "PAID",
      paid_date: "2025-11-17",  // ✓ 不再是 null
      due_date: "2025-11-17"
    }
  ],
  mappedDetails: [
    {
      period: 1,
      status: "PAID",
      paidDate: "2025-11-17",   // ✓ 有值了
      dueDate: "2025-11-17"
    }
  ]
}
```

页面显示：
```
第 1 期 [已入账]
应还日: 2025-11-17
¥40.00
入账: 2025-11-17  ← 正确显示
实付: ¥40.00
```
