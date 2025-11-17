# 费用分摊功能 - 实施清单

## ✅ 已完成

### 数据库层
- [x] 移除 `split_config` JSON 字段迁移
- [x] 清理 schema.rs 中的 SplitConfig 定义
- [x] 更新 transactions 实体，移除 split_config 字段
- [x] 添加 split_records 关联到 transactions 实体

### DTO 层
- [x] 创建 `SplitConfigRequest` 结构体
- [x] 创建 `SplitMemberRequest` 结构体
- [x] 创建 `SplitConfigResponse` 结构体
- [x] 创建 `SplitMemberResponse` 结构体
- [x] 更新 `CreateTransactionRequest` 使用新结构
- [x] 更新 `UpdateTransactionRequest` 使用新结构
- [x] 更新 `TransactionResponse` 返回分摊信息

### 服务层
- [x] 创建 `split_record.rs` 服务文件（基础版本）
- [x] 实现 `create_split_records` 方法
- [x] 实现 `get_split_config` 方法
- [x] 实现 `delete_split_records` 方法
- [x] 实现 `update_split_records` 方法

### 前端层
- [x] 更新 TypeScript SplitConfigSchema
- [x] 添加 enabled 字段
- [x] 调整成员字段结构

## ⏳ 待完成

### 1. 后端集成（高优先级）✅ 已完成基础集成

#### transaction.rs 服务更新 ✅
```rust
// 文件: src-tauri/crates/money/src/services/transaction.rs

// ✅ 已完成: trans_create_response 方法
// 创建交易并返回包含分摊配置的完整响应
pub async fn trans_create_response(
    db: &DbConn,
    data: CreateTransactionRequest,
) -> MijiResult<TransactionResponse>

// ✅ 已完成: trans_get_response 方法
// 查询交易并返回包含分摊配置的完整响应  
pub async fn trans_get_response(
    db: &DbConn,
    id: String,
) -> MijiResult<TransactionResponse>

// ✅ 已完成: model_to_response 辅助方法
// 将模型转换为响应并加载分摊配置
pub async fn model_to_response(
    db: &DbConn,
    model: entity::transactions::Model,
) -> MijiResult<TransactionResponse>
```

#### Tauri 命令更新
```rust
// 文件: src-tauri/src/commands/money/transaction.rs

// TODO: 确保命令调用新的服务方法
#[tauri::command]
pub async fn create_transaction(
    state: State<'_, AppState>,
    request: CreateTransactionRequest,
) -> Result<TransactionResponse, String> {
    // 调用 create_with_split
}

#[tauri::command]
pub async fn get_transaction(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<TransactionResponse, String> {
    // 调用 get_with_split
}
```

### 2. 前端适配（高优先级）✅ 已完成

#### TransactionModal.vue ✅
```vue
<!-- ✅ 已完成：保存逻辑已更新 -->
<script>
function emitTransaction(amount: number) {
  const transaction = {
    // ... 其他字段
    splitConfig: splitConfig.value.enabled && 
                 splitConfig.value.members && 
                 splitConfig.value.members.length > 0
      ? {
          splitType: splitConfig.value.splitType || 'EQUAL',
          members: splitConfig.value.members,
        }
      : undefined,
  };
  emit('save', transaction);
}
</script>
```

#### TransactionSplitSection.vue ✅
```vue
<!-- ✅ 已完成：数据格式已匹配后端 -->
<script>
// splitPreview 包含 percentage 和 weight
// 添加了 initialConfig prop 支持编辑
// 实现了配置恢复逻辑
</script>
```

### 3. 数据验证（中优先级）

#### 后端验证
- [ ] 验证分摊金额总和 = 交易金额
- [ ] 验证分摊比例总和 = 100%
- [ ] 验证成员存在于家庭账本中
- [ ] 验证分摊类型有效性

```rust
// TODO: 在 split_record.rs 中添加
fn validate_split_config(
    split_config: &SplitConfigRequest,
    total_amount: Decimal,
) -> Result<(), AppError> {
    // 实现验证逻辑
}
```

#### 前端验证
- [ ] 实时验证总和
- [ ] 阻止无效提交
- [ ] 友好的错误提示

### 4. 分摊记录查询功能（中优先级）

```rust
// TODO: 创建专门的查询服务
// 文件: src-tauri/crates/money/src/services/split_record_queries.rs

/// 获取成员的分摊记录
pub async fn get_member_split_records(
    db: &DatabaseConnection,
    member_serial_num: &str,
    family_ledger_serial_num: &str,
) -> Result<Vec<SplitRecordSummary>, AppError>;

/// 获取未结算的分摊
pub async fn get_pending_splits(
    db: &DatabaseConnection,
    family_ledger_serial_num: &str,
) -> Result<Vec<PendingSplit>, AppError>;

/// 获取分摊统计
pub async fn get_split_statistics(
    db: &DatabaseConnection,
    family_ledger_serial_num: &str,
    start_date: NaiveDate,
    end_date: NaiveDate,
) -> Result<SplitStatistics, AppError>;
```

### 5. 测试（中优先级）

#### 单元测试
- [ ] split_record.rs 服务方法测试
- [ ] 创建分摊记录测试
- [ ] 查询分摊配置测试
- [ ] 更新分摊记录测试
- [ ] 删除分摊记录测试

#### 集成测试
- [ ] 完整的创建交易 + 分摊流程
- [ ] 编辑交易更新分摊
- [ ] 删除交易级联删除分摊
- [ ] 查询交易包含分摊信息

#### E2E 测试
- [ ] 前端创建分摊交易
- [ ] 前端查看分摊详情
- [ ] 前端编辑分摊配置
- [ ] 分摊报表生成

### 6. 文档（低优先级）

- [x] 使用文档 (SPLIT_RECORDS_USAGE.md)
- [ ] API 文档
- [ ] 数据库设计文档
- [ ] 前端组件文档

### 7. 性能优化（低优先级）

- [ ] 添加数据库索引
  - `split_records.transaction_serial_num`
  - `split_records.family_ledger_serial_num`
  - `split_record_details.member_serial_num`
- [ ] 批量查询优化
- [ ] 缓存分摊配置

### 8. 高级功能（后期）

- [ ] 分摊提醒功能
- [ ] 自动结算建议
- [ ] 债务优化算法
- [ ] 分摊报表导出
- [ ] 分摊模板功能

## 实施顺序建议

### Phase 1: 核心功能 ✅ 已完成 95%
1. ✅ 数据库和 DTO 层清理
2. ✅ 后端服务集成（基础方法已完成）
3. ⏳ Tauri 命令更新（待验证）
4. ✅ 前端数据格式调整（已完成）

### Phase 2: 验证和测试（下周）
1. 后端数据验证
2. 前端验证优化
3. 单元测试
4. 集成测试

### Phase 3: 查询和统计（后续）
1. 分摊查询服务
2. 分摊统计功能
3. 报表生成

### Phase 4: 优化和扩展（长期）
1. 性能优化
2. 高级功能
3. 完善文档

## 注意事项

1. **事务一致性**：创建交易和分摊记录必须在同一事务中
2. **级联删除**：确保数据库外键配置正确
3. **向后兼容**：考虑已有数据的迁移
4. **错误处理**：分摊失败时应回滚整个交易创建
5. **性能监控**：关注分摊查询的性能影响

## 测试清单

### 基本功能
- [ ] 创建不启用分摊的交易
- [ ] 创建启用分摊的交易
- [ ] 查询带分摊的交易
- [ ] 编辑分摊配置
- [ ] 删除带分摊的交易

### 边界情况
- [ ] 分摊金额总和不等于交易金额
- [ ] 分摊比例总和不等于100%
- [ ] 成员不存在于账本中
- [ ] 无效的分摊类型
- [ ] 空的成员列表

### 并发场景
- [ ] 同时创建多个分摊交易
- [ ] 同时更新同一分摊记录
- [ ] 查询时删除分摊记录

## 下一步行动

**✅ 已完成：**
1. ✅ 更新 `transaction.rs` 服务，添加分摊处理逻辑
2. ✅ 创建 `split_record.rs` 服务
3. ✅ 实现创建和查询方法
4. ✅ 更新前端 `TransactionModal.vue`
5. ✅ 更新前端 `TransactionSplitSection.vue`
6. ✅ 数据格式对齐（前后端）

**立即开始：**
1. 验证并更新 Tauri 命令使用新方法
2. 测试完整流程（创建、查询、编辑）
3. 修复发现的问题

**本周完成：**
- ✅ Phase 1 核心功能（95%）
- ⏳ Tauri 命令验证（5%）
- ⏳ 基本功能测试
- ⏳ Bug 修复

**持续跟进：**
- 收集用户反馈
- 添加数据验证
- 优化性能
- 扩展高级功能

## 📚 参考文档

- **实施指南**: `docs/SPLIT_RECORDS_IMPLEMENTATION.md`
- **使用文档**: `docs/SPLIT_RECORDS_USAGE.md`
- **任务清单**: `docs/SPLIT_RECORDS_TODO.md` (本文件)
