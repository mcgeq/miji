# 费用分摊功能 - 实施指南

## ✅ 已完成的后端集成

### 1. 服务层更新

#### transaction.rs 服务
已添加以下新方法：

```rust
// 创建交易并返回包含分摊配置的完整响应
pub async fn trans_create_response(
    &self,
    db: &DbConn,
    data: CreateTransactionRequest,
) -> MijiResult<TransactionResponse>

// 查询交易并返回包含分摊配置的完整响应  
pub async fn trans_get_response(
    &self,
    db: &DbConn,
    id: String,
) -> MijiResult<TransactionResponse>

// 内部辅助方法：将模型转换为响应
pub async fn model_to_response(
    &self,
    db: &DbConn,
    model: entity::transactions::Model,
) -> MijiResult<TransactionResponse>
```

#### split_record.rs 服务
提供分摊记录的 CRUD 操作：

```rust
// 创建分摊记录
pub async fn create_split_records(
    db: &DatabaseConnection,
    transaction_serial_num: String,
    family_ledger_serial_num: String,
    payer_member_serial_num: String,
    split_config: SplitConfigRequest,
    total_amount: Decimal,
    currency: String,
) -> Result<(), AppError>

// 查询分摊配置
pub async fn get_split_config(
    db: &DatabaseConnection,
    transaction_serial_num: &str,
) -> Result<Option<SplitConfigResponse>, AppError>

// 更新分摊记录
pub async fn update_split_records(...) -> Result<(), AppError>

// 删除分摊记录
pub async fn delete_split_records(...) -> Result<(), AppError>
```

### 2. 数据流程

```
前端提交
    ↓
CreateTransactionRequest {
    splitConfig: Some(SplitConfigRequest {
        splitType: "PERCENTAGE",
        members: [...]
    })
}
    ↓
trans_create_with_relations()
    ├─ 创建交易
    ├─ 创建账本关联
    └─ 如果有 splitConfig，调用 create_split_records()
        ├─ 创建 split_records 主记录
        └─ 创建 split_record_details 详情记录
    ↓
trans_create_response()
    ├─ 转换为 TransactionResponse
    └─ 调用 get_split_config() 填充分摊信息
    ↓
返回前端
```

## 🔧 Tauri Command 更新指南

### 创建交易命令

```rust
// 文件: src-tauri/src/commands/money/transaction.rs (或类似路径)

use money::services::transaction::TransactionService;
use money::dto::transactions::{CreateTransactionRequest, TransactionResponse};

#[tauri::command]
pub async fn create_transaction(
    state: State<'_, AppState>,
    request: CreateTransactionRequest,
) -> Result<TransactionResponse, String> {
    let db = &state.db;
    let service = TransactionService::default();
    
    // 使用新的 trans_create_response 方法
    // 它会自动处理分摊记录的创建和查询
    service.trans_create_response(db, request)
        .await
        .map_err(|e| e.to_string())
}
```

### 查询交易命令

```rust
#[tauri::command]
pub async fn get_transaction(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<TransactionResponse, String> {
    let db = &state.db;
    let service = TransactionService::default();
    
    // 使用新的 trans_get_response 方法
    // 它会自动加载分摊配置
    service.trans_get_response(db, serial_num)
        .await
        .map_err(|e| e.to_string())
}
```

### 更新交易命令（需要添加）

```rust
#[tauri::command]
pub async fn update_transaction(
    state: State<'_, AppState>,
    serial_num: String,
    request: UpdateTransactionRequest,
) -> Result<TransactionResponse, String> {
    let db = &state.db;
    let service = TransactionService::default();
    
    // 1. 更新交易
    let model = service.update(db, &serial_num, request.clone())
        .await
        .map_err(|e| e.to_string())?;
    
    // 2. 如果有分摊配置，更新分摊记录
    if let Some(split_cfg) = request.split_config {
        // 获取账本信息
        if let Some(ledger_nums) = request.family_ledger_serial_nums {
            if let Some(first_ledger) = ledger_nums.first() {
                // TODO: 获取实际付款人
                let payer = split_cfg.members.first()
                    .map(|m| m.member_serial_num.clone())
                    .unwrap_or_default();
                
                money::services::split_record::update_split_records(
                    db,
                    serial_num.clone(),
                    first_ledger.clone(),
                    payer,
                    split_cfg,
                    model.amount,
                    model.currency.clone(),
                ).await.map_err(|e| e.to_string())?;
            }
        }
    }
    
    // 3. 返回完整响应
    service.trans_get_response(db, serial_num)
        .await
        .map_err(|e| e.to_string())
}
```

## 📊 前端调用示例

### 创建带分摊的交易

```typescript
import { invoke } from '@tauri-apps/api/tauri';

async function createTransactionWithSplit() {
  const transaction = {
    transactionType: 'Expense',
    amount: 100,
    accountSerialNum: 'account-123',
    category: '餐饮',
    currency: 'CNY',
    date: new Date().toISOString(),
    // ... 其他必需字段
    
    // 家庭账本
    familyLedgerSerialNums: ['ledger-123'],
    
    // 分摊配置
    splitConfig: {
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
  
  try {
    const response = await invoke('create_transaction', { request: transaction });
    console.log('创建成功:', response);
    console.log('分摊配置:', response.splitConfig);
  } catch (error) {
    console.error('创建失败:', error);
  }
}
```

### 查询交易（包含分摊信息）

```typescript
async function getTransactionWithSplit(serialNum: string) {
  try {
    const response = await invoke('get_transaction', { 
      serialNum 
    });
    
    console.log('交易详情:', response);
    
    if (response.splitConfig) {
      console.log('启用了分摊');
      console.log('分摊类型:', response.splitConfig.splitType);
      console.log('成员:', response.splitConfig.members);
    } else {
      console.log('未启用分摊');
    }
  } catch (error) {
    console.error('查询失败:', error);
  }
}
```

## 🔍 验证清单

### 后端验证

- [x] ✅ `trans_create_with_relations` 使用 `split_config` 而非 `split_members`
- [x] ✅ 调用 `split_record::create_split_records` 创建分摊记录
- [x] ✅ `trans_create_response` 自动查询分摊配置
- [x] ✅ `trans_get_response` 返回包含分摊配置的响应
- [x] ✅ `model_to_response` 辅助方法正确实现
- [x] ✅ `split_record` 模块已导出到 `services.rs`

### 前端验证

- [ ] ⏳ TransactionModal 发送正确的 `splitConfig` 格式
- [ ] ⏳ TransactionSplitSection 数据格式匹配后端
- [ ] ⏳ 编辑交易时正确显示分摊配置
- [ ] ⏳ 创建交易后能看到分摊详情

### Tauri Command 验证

- [ ] ⏳ `create_transaction` 命令使用 `trans_create_response`
- [ ] ⏳ `get_transaction` 命令使用 `trans_get_response`  
- [ ] ⏳ 命令返回类型更新为 `TransactionResponse`

## 📝 数据示例

### 请求数据

```json
{
  "transactionType": "Expense",
  "amount": 100.00,
  "splitConfig": {
    "splitType": "PERCENTAGE",
    "members": [
      {
        "memberSerialNum": "member-uuid-1",
        "memberName": "Alice",
        "amount": 60.00,
        "percentage": 60.0
      },
      {
        "memberSerialNum": "member-uuid-2",
        "memberName": "Bob",
        "amount": 40.00,
        "percentage": 40.0
      }
    ]
  }
}
```

### 响应数据

```json
{
  "serialNum": "transaction-uuid",
  "amount": 100.00,
  "splitConfig": {
    "enabled": true,
    "splitType": "PERCENTAGE",
    "members": [
      {
        "memberSerialNum": "member-uuid-1",
        "memberName": "Alice",
        "amount": 60.00,
        "percentage": 60.0,
        "weight": null,
        "isPaid": false,
        "paidAt": null
      },
      {
        "memberSerialNum": "member-uuid-2",
        "memberName": "Bob",
        "amount": 40.00,
        "percentage": 40.0,
        "weight": null,
        "isPaid": false,
        "paidAt": null
      }
    ]
  }
}
```

## 🐛 常见问题

### Q1: 创建交易成功但没有分摊记录？
**A**: 检查以下项：
- `splitConfig` 是否正确传递
- `members` 数组是否为空
- `family_ledger_serial_nums` 是否设置
- 日志中是否有错误信息

### Q2: 查询交易时 `splitConfig` 为 null？
**A**: 检查：
- `split_records` 表中是否有对应记录
- `get_split_config` 方法是否正确执行
- 数据库外键关联是否正确

### Q3: 分摊金额总和不等于交易金额？
**A**: 
- 前端应该在提交前验证
- 后端需要添加验证逻辑（待实现）

## 🚀 下一步

1. **测试**：
   - 创建带分摊的交易
   - 查询并验证分摊信息正确显示
   - 更新分摊配置
   
2. **完善**：
   - 添加分摊金额验证
   - 实现付款人自动识别
   - 添加分摊状态更新（已付/未付）
   
3. **文档**：
   - API 文档
   - 前端组件使用说明
   - 数据库查询优化建议
