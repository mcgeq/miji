# 费用分摊功能 - 独立表方案

## 概述

费用分摊功能使用独立的数据库表来存储分摊信息，而不是在 `transactions` 表中使用 JSON 字段。

## 数据库表结构

### 1. split_records（分摊记录主表）
存储交易的分摊主信息。

**关键字段：**
- `serial_num`: 主键
- `transaction_serial_num`: 关联的交易ID（外键）
- `family_ledger_serial_num`: 关联的家庭账本
- `split_type`: 分摊类型（EQUAL/PERCENTAGE/FIXED_AMOUNT/WEIGHTED）
- `total_amount`: 总金额
- `payer_member_serial_num`: 付款人

### 2. split_record_details（分摊详情表）
存储每个成员的分摊详情。

**关键字段：**
- `serial_num`: 主键
- `split_record_serial_num`: 关联的分摊记录ID（外键）
- `member_serial_num`: 成员ID
- `amount`: 分摊金额
- `percentage`: 分摊比例（可选）
- `weight`: 权重（可选）
- `is_paid`: 是否已支付
- `paid_at`: 支付时间

## 前端使用方式

### 数据结构

```typescript
// 前端发送的数据格式
interface SplitConfig {
  enabled: boolean;
  splitType: 'EQUAL' | 'PERCENTAGE' | 'FIXED_AMOUNT' | 'WEIGHTED';
  members: Array<{
    memberSerialNum: string;
    memberName: string;
    amount: number;
    percentage?: number;  // 按比例时使用
    weight?: number;      // 按权重时使用
  }>;
}

// 创建交易请求
interface CreateTransactionRequest {
  // ... 其他字段
  splitConfig?: SplitConfig;
}
```

### 示例代码

```typescript
// 创建带分摊的交易
const transaction = {
  transactionType: 'Expense',
  amount: 100,
  // ... 其他字段
  
  // 分摊配置
  splitConfig: {
    enabled: true,
    splitType: 'PERCENTAGE',
    members: [
      {
        memberSerialNum: 'member-1',
        memberName: 'Alice',
        amount: 60,
        percentage: 60,
      },
      {
        memberSerialNum: 'member-2',
        memberName: 'Bob',
        amount: 40,
        percentage: 40,
      },
    ],
  },
};

// 发送到后端
await invoke('create_transaction', { request: transaction });
```

## 后端实现

### 1. 创建交易时处理分摊

在 `transaction.rs` 服务中：

```rust
use crate::services::split_record;

pub async fn create_transaction(
    db: &DatabaseConnection,
    request: CreateTransactionRequest,
) -> Result<TransactionResponse, AppError> {
    // 1. 创建交易
    let transaction = transaction_service::create(db, request.clone()).await?;
    
    // 2. 如果有分摊配置，创建分摊记录
    if let Some(split_config) = request.split_config {
        if split_config.enabled {
            split_record::create_split_records(
                db,
                transaction.serial_num.clone(),
                family_ledger_serial_num, // 从请求中获取
                payer_member_serial_num,   // 从请求中获取
                split_config,
                transaction.amount,
                transaction.currency,
            ).await?;
        }
    }
    
    // 3. 返回交易信息
    Ok(transaction)
}
```

### 2. 查询交易时加载分摊信息

```rust
pub async fn get_transaction(
    db: &DatabaseConnection,
    serial_num: &str,
) -> Result<TransactionResponse, AppError> {
    // 1. 查询交易
    let mut transaction = transaction_service::get(db, serial_num).await?;
    
    // 2. 查询分摊配置
    if let Some(split_config) = split_record::get_split_config(db, serial_num).await? {
        transaction.split_config = Some(split_config);
    }
    
    Ok(transaction)
}
```

### 3. 更新交易时更新分摊

```rust
pub async fn update_transaction(
    db: &DatabaseConnection,
    serial_num: &str,
    request: UpdateTransactionRequest,
) -> Result<TransactionResponse, AppError> {
    // 1. 更新交易
    let transaction = transaction_service::update(db, serial_num, request.clone()).await?;
    
    // 2. 更新分摊记录
    if let Some(split_config) = request.split_config {
        split_record::update_split_records(
            db,
            serial_num.to_string(),
            family_ledger_serial_num,
            payer_member_serial_num,
            split_config,
            transaction.amount,
            transaction.currency,
        ).await?;
    }
    
    Ok(transaction)
}
```

### 4. 删除交易时删除分摊

```rust
pub async fn delete_transaction(
    db: &DatabaseConnection,
    serial_num: &str,
) -> Result<(), AppError> {
    // 1. 删除分摊记录（会级联删除详情）
    split_record::delete_split_records(db, serial_num).await?;
    
    // 2. 删除交易
    transaction_service::delete(db, serial_num).await?;
    
    Ok(())
}
```

## 判断交易是否启用分摊

### 方式1：查询是否存在分摊记录

```sql
SELECT COUNT(*) FROM split_records 
WHERE transaction_serial_num = ?;
```

### 方式2：通过关联查询

```rust
let transaction_with_split = transactions::Entity::find_by_id(serial_num)
    .find_with_related(split_records::Entity)
    .all(db)
    .await?;

let has_split = !transaction_with_split.is_empty();
```

### 方式3：使用服务方法

```rust
let split_config = split_record::get_split_config(db, serial_num).await?;
let has_split = split_config.is_some();
```

## 优势

### vs JSON 字段方案

| 特性 | 独立表 | JSON 字段 |
|------|-------|----------|
| 查询性能 | ✅ 使用索引 | ❌ 需要JSON函数 |
| 数据完整性 | ✅ 外键约束 | ❌ 无约束 |
| 统计分析 | ✅ 标准SQL | ❌ 复杂查询 |
| 扩展性 | ✅ 易于添加字段 | ❌ 结构固定 |
| 付款状态跟踪 | ✅ 每个成员独立状态 | ❌ 难以追踪 |

## 高级功能

### 1. 分摊报表

```sql
-- 统计成员的分摊总额
SELECT 
    fm.name,
    SUM(srd.amount) as total_split,
    COUNT(DISTINCT sr.transaction_serial_num) as transaction_count
FROM split_record_details srd
JOIN split_records sr ON srd.split_record_serial_num = sr.serial_num
JOIN family_member fm ON srd.member_serial_num = fm.serial_num
WHERE sr.family_ledger_serial_num = ?
GROUP BY fm.name;
```

### 2. 未结算分摊

```sql
-- 查询未支付的分摊
SELECT 
    t.description,
    srd.amount,
    fm.name
FROM split_record_details srd
JOIN split_records sr ON srd.split_record_serial_num = sr.serial_num
JOIN transactions t ON sr.transaction_serial_num = t.serial_num
JOIN family_member fm ON srd.member_serial_num = fm.serial_num
WHERE srd.is_paid = false
  AND sr.family_ledger_serial_num = ?;
```

### 3. 分摊提醒

```rust
// 查询需要发送提醒的分摊记录
pub async fn get_pending_reminders(
    db: &DatabaseConnection,
    family_ledger_serial_num: &str,
) -> Result<Vec<SplitRecordReminder>, AppError> {
    split_records::Entity::find()
        .filter(
            split_records::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num)
                .and(split_records::Column::ReminderSent.eq(false))
                .and(split_records::Column::DueDate.lte(chrono::Utc::now().date_naive()))
        )
        .all(db)
        .await
}
```

## 迁移步骤

1. ✅ 清理 `split_config` JSON 字段相关代码
2. ✅ 更新 DTO 使用 `SplitConfigRequest` 和 `SplitConfigResponse`
3. ✅ 实现 `split_record` 服务方法
4. ⏳ 在 transaction 服务中集成分摊记录处理
5. ⏳ 更新 Tauri 命令
6. ⏳ 测试完整流程

## 注意事项

- 创建交易和分摊记录应在同一个数据库事务中
- 删除交易时会自动级联删除分摊记录
- 分摊金额总和应等于交易金额（前端验证 + 后端验证）
- 支持后续扩展：提醒、自动结算、债务追踪等
