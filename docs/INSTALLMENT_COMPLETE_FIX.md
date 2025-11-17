# 分期交易显示完整修复方案

## 问题总结
1. **分期字段显示为空**：总期数、每期金额、首期日期没有显示
2. **分期计划列表显示不完整**：
   - 显示"第期"（缺少期数）
   - 显示"到期:"（缺少日期）
   - 显示"入账:"（缺少日期）

## 根本原因分析

### 数据流程
```
交易记录 (transactions)
    ↓
installment_plan_serial_num (可能为 null)
    ↓
分期计划 (installment_plans) ← transaction_serial_num
    ↓
分期详情 (installment_details) ← plan_serial_num
    ↓
前端显示
```

### 问题点
1. 某些分期交易的 `installment_plan_serial_num` 字段为 `null`
2. 前端只能根据 `installment_plan_serial_num` 查询，导致无法获取分期详情
3. 模板显示逻辑对 `undefined` 值处理不够健壮

## 完整解决方案

### 1. 后端改进

#### 添加新查询方法 (`installment.rs`)
```rust
/// 根据交易序列号获取分期计划
pub async fn get_installment_plan_by_transaction(
    &self,
    db: &DbConn,
    transaction_serial_num: &str,
) -> MijiResult<InstallmentPlanResponse> {
    let plan = installment_plans::Entity::find()
        .filter(installment_plans::Column::TransactionSerialNum.eq(transaction_serial_num))
        .one(db)
        .await?
        .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "该交易没有分期计划"))?;
    
    self.build_installment_plan_response(db, plan).await
}
```

#### 重构响应构建逻辑
```rust
async fn build_installment_plan_response(
    &self,
    db: &DbConn,
    plan: entity::installment_plans::Model,
) -> MijiResult<InstallmentPlanResponse> {
    let details = installment_details::Entity::find()
        .filter(installment_details::Column::PlanSerialNum.eq(&plan.serial_num))
        .order_by_asc(installment_details::Column::PeriodNumber)
        .all(db)
        .await?;
    
    // 构建详情响应，包含所有字段：
    // - period_number
    // - due_date
    // - paid_date
    // - amount
    // - status
}
```

#### 新增 Tauri 命令 (`command.rs`)
```rust
#[tauri::command]
pub async fn installment_plan_get_by_transaction(
    state: State<'_, AppState>,
    transaction_serial_num: String,
) -> Result<ApiResponse<InstallmentPlanResponse>, String> {
    let service = InstallmentService::default();
    Ok(ApiResponse::from_result(
        service
            .get_installment_plan_by_transaction(&state.db, &transaction_serial_num)
            .await,
    ))
}
```

#### 注册命令 (`commands.rs`)
```rust
money_cmd::installment_plan_get,
money_cmd::installment_plan_get_by_transaction,  // 新增
money_cmd::installment_calculate,
```

### 2. 前端改进

#### 智能加载逻辑 (`TransactionModal.vue`)
```typescript
// 如果是分期付款交易，加载分期计划详情
if (transaction.isInstallment) {
  if (transaction.installmentPlanSerialNum) {
    // 优先使用分期计划序列号
    await loadInstallmentPlanDetails(transaction.installmentPlanSerialNum);
  } else {
    // 降级方案：使用交易序列号查询
    await loadInstallmentPlanDetailsByTransaction(transaction.serialNum);
  }
}
```

#### 新增查询方法
```typescript
// 根据交易序列号加载分期计划
async function loadInstallmentPlanDetailsByTransaction(transactionSerialNum: string) {
  try {
    const response = await invokeCommand<InstallmentPlanResponse>(
      'installment_plan_get_by_transaction',
      { transactionSerialNum }
    );
    processInstallmentPlanResponse(response);
  } catch (error) {
    console.warn('该交易没有分期计划');
  }
}
```

#### 重构响应处理
```typescript
// 处理分期计划响应（共用逻辑）
function processInstallmentPlanResponse(response: InstallmentPlanResponse | null) {
  if (response && response.details) {
    // 存储原始数据
    rawInstallmentDetails.value = response.details;
    installmentPlanDetails.value = response;
    
    // 安全更新表单字段
    if (response.total_periods !== undefined && response.total_periods !== null) {
      form.value.totalPeriods = Number(response.total_periods);
      form.value.remainingPeriods = Number(response.total_periods);
    }
    // ... 更多字段
  }
}
```

#### 改进显示模板
```vue
<div v-for="(detail, index) in visibleInstallmentDetails">
  <!-- 期数显示，带后备值 -->
  <span class="period-label">
    第 {{ detail.period || (index + 1) }} 期
  </span>
  
  <!-- 到期日期，带后备值 -->
  <span class="due-date">
    到期: {{ detail.dueDate || '未设置' }}
  </span>
  
  <!-- 入账日期，带后备值 -->
  <div v-if="detail.status === 'PAID'">
    <span class="paid-date">
      入账: {{ detail.paidDate || '未知' }}
    </span>
  </div>
</div>
```

### 3. 数据映射确保正确

#### installmentDetails Computed
```typescript
const installmentDetails = computed(() => {
  if (installmentPlanDetails.value && installmentPlanDetails.value.details) {
    return installmentPlanDetails.value.details.map(detail => ({
      period: detail.period_number,      // ✓ 期数
      amount: Number(detail.amount),     // ✓ 金额
      dueDate: detail.due_date,          // ✓ 到期日期
      status: detail.status,             // ✓ 状态
      paidDate: detail.paid_date,        // ✓ 入账日期
      paidAmount: detail.paid_amount,    // ✓ 实付金额
    }));
  }
  return null;
});
```

## 修改文件清单

### 后端
- ✅ `src-tauri/crates/money/src/services/installment.rs`
  - 新增 `get_installment_plan_by_transaction`
  - 重构 `build_installment_plan_response`
- ✅ `src-tauri/crates/money/src/command.rs`
  - 新增 `installment_plan_get_by_transaction` 命令
- ✅ `src-tauri/src/commands.rs`
  - 注册新命令

### 前端
- ✅ `src/features/money/components/TransactionModal.vue`
  - 新增 `loadInstallmentPlanDetailsByTransaction` 方法
  - 重构 `processInstallmentPlanResponse` 方法
  - 改进显示模板（带后备值）
  - 增强表单初始化逻辑
  - 添加详细调试日志

## 预期效果

### 编辑分期交易时
- ✅ 总期数输入框显示：`3`
- ✅ 每期金额输入框显示：`40.00`
- ✅ 首期日期输入框显示：`2025-11-17`

### 分期计划列表
每一期显示：
```
第 1 期                [已入账]
到期: 2025-11-17
¥40.00
入账: 2025-11-17
实付: ¥40.00
```

### 调试日志
```
📝 加载交易数据: { isInstallment: true, totalPeriods: 3, ... }
📋 表单初始化后的分期字段: { totalPeriods: 3, ... }
🔄 使用交易序列号加载分期计划: ...
✅ 已加载分期计划详情: { totalPeriods: 3, detailsCount: 3, ... }
📊 分期计划详情列表: [
  { period: 1, dueDate: "2025-11-17", ... },
  { period: 2, dueDate: "2025-12-17", ... },
  { period: 3, dueDate: "2026-01-17", ... }
]
```

## 数据库表结构

### transactions 表
```sql
CREATE TABLE transactions (
  serial_num TEXT PRIMARY KEY,
  -- ... 其他字段 ...
  is_installment BOOLEAN,
  total_periods INTEGER,
  installment_amount DECIMAL,
  first_due_date DATE,
  installment_plan_serial_num TEXT,  -- 可能为 NULL
  -- ...
);
```

### installment_plans 表
```sql
CREATE TABLE installment_plans (
  serial_num TEXT PRIMARY KEY,
  transaction_serial_num TEXT NOT NULL,  -- 关键字段
  total_amount DECIMAL NOT NULL,
  total_periods INTEGER NOT NULL,
  installment_amount DECIMAL NOT NULL,
  first_due_date DATE NOT NULL,
  status TEXT NOT NULL,
  -- ...
  FOREIGN KEY (transaction_serial_num) REFERENCES transactions(serial_num)
);
```

### installment_details 表
```sql
CREATE TABLE installment_details (
  serial_num TEXT PRIMARY KEY,
  plan_serial_num TEXT NOT NULL,         -- 关联分期计划
  period_number INTEGER NOT NULL,         -- 期数 ✓
  due_date DATE NOT NULL,                 -- 到期日期 ✓
  amount DECIMAL NOT NULL,                -- 每期金额 ✓
  status TEXT NOT NULL,                   -- 状态 ✓
  paid_date DATE,                         -- 入账日期 ✓
  paid_amount DECIMAL,                    -- 实付金额 ✓
  -- ...
  FOREIGN KEY (plan_serial_num) REFERENCES installment_plans(serial_num)
);
```

## 查询路径

### 方案 A: 使用 installment_plan_serial_num
```
transaction.installment_plan_serial_num
    ↓
installment_plans.serial_num
    ↓
installment_details.plan_serial_num
```

### 方案 B: 使用 transaction_serial_num（新增）
```
transaction.serial_num
    ↓
installment_plans.transaction_serial_num
    ↓
installment_details.plan_serial_num
```

## 测试步骤

1. **创建分期交易**
   - 金额：120
   - 分期数：3
   - 首期日期：今天

2. **保存并关闭**

3. **重新编辑该交易**
   - 检查总期数是否显示 `3`
   - 检查每期金额是否显示 `40.00`
   - 检查首期日期是否正确

4. **查看分期计划列表**
   - 每一期应该显示"第 X 期"
   - 每一期应该显示到期日期
   - 状态应该正确显示（待入账/已入账）

5. **完成一期入账**
   - 再次编辑交易
   - 已入账的期应该显示入账日期

6. **检查浏览器控制台**
   - 应该有详细的日志输出
   - 没有错误信息

## 故障排查

### 如果字段仍然为空
1. 检查浏览器控制台日志
2. 查看 `📝 加载交易数据` 日志中的字段值
3. 查看 `✅ 已加载分期计划详情` 日志中的字段值
4. 检查数据库 `transactions` 表
5. 检查数据库 `installment_plans` 表
6. 检查数据库 `installment_details` 表

### 如果期数和日期不显示
1. 检查 `📊 分期计划详情列表` 日志
2. 确认 `detail.period` 有值
3. 确认 `detail.dueDate` 有值
4. 检查后端返回的数据结构

### SQL 调试查询
```sql
-- 查询交易的分期信息
SELECT 
  t.serial_num as transaction_sn,
  t.is_installment,
  t.total_periods,
  t.installment_amount,
  t.first_due_date,
  t.installment_plan_serial_num,
  p.serial_num as plan_sn,
  COUNT(d.serial_num) as details_count
FROM transactions t
LEFT JOIN installment_plans p ON t.installment_plan_serial_num = p.serial_num
  OR t.serial_num = p.transaction_serial_num
LEFT JOIN installment_details d ON p.serial_num = d.plan_serial_num
WHERE t.is_installment = 1
GROUP BY t.serial_num;

-- 查询分期详情
SELECT 
  period_number,
  due_date,
  amount,
  status,
  paid_date,
  paid_amount
FROM installment_details
WHERE plan_serial_num = 'YOUR_PLAN_SERIAL_NUM'
ORDER BY period_number;
```

## 优势

1. **健壮性**：即使 `installment_plan_serial_num` 为 null 也能查询
2. **完整性**：显示所有必要信息（期数、日期、金额、状态）
3. **容错性**：使用后备值防止显示空白
4. **可调试**：详细的日志帮助排查问题
5. **向后兼容**：不影响现有正常的分期交易

## 相关文档
- `INSTALLMENT_DISPLAY_FIX.md` - 问题分析
- `INSTALLMENT_DEBUG_GUIDE.md` - 调试指南
- `INSTALLMENT_CALCULATION_FIX.md` - 计算问题修复
