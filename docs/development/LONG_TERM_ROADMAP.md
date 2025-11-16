# Split Records 功能长期规划

## 🎯 总体目标

将 split_records 系统从基础的数据存储发展为完整的分摊管理系统，支持复杂的分摊场景、状态管理和结算流程。

## 📅 规划时间线

### Q1: 增强分摊规则（0-3个月）
完善分摊计算逻辑，支持多种分摊方式

### Q2: 状态管理与流程（3-6个月）
实现完整的确认/支付流程

### Q3: 数据优化与清理（6-9个月）
废弃冗余的 JSON 字段，全面使用规范化表

---

## 阶段1: 增强分摊规则 📊

### 目标
支持更复杂和灵活的分摊计算方式

### 1.1 按百分比分摊

**需求描述**:
- 用户可以为每个成员设置不同的分摊百分比
- 系统自动验证总百分比为 100%
- 支持不均等分摊场景

**技术实现**:
```rust
// dto/split_records.rs
pub enum SplitType {
    Equal,          // 平均分摊（当前已实现）
    Percentage,     // 按百分比 ✨ 新增
    FixedAmount,    // 固定金额
    Weighted,       // 按权重
}

pub struct SplitMemberData {
    pub member_serial_num: String,
    pub split_percentage: Option<Decimal>,  // 0-100
    pub split_amount: Option<Decimal>,
    pub weight: Option<i32>,
}
```

**前端界面**:
```vue
<template>
  <div class="split-method-selector">
    <button @click="splitMethod = 'equal'">平均分摊</button>
    <button @click="splitMethod = 'percentage'">按百分比</button>
    <button @click="splitMethod = 'amount'">固定金额</button>
  </div>

  <div v-if="splitMethod === 'percentage'">
    <div v-for="member in splitMembers" :key="member.serialNum">
      <span>{{ member.name }}</span>
      <input 
        v-model.number="member.percentage" 
        type="number" 
        min="0" 
        max="100"
      />%
    </div>
    <div class="total">总计: {{ totalPercentage }}%</div>
  </div>
</template>
```

### 1.2 固定金额分摊

**需求描述**:
- 为每个成员指定固定的分摊金额
- 系统验证总金额不超过交易金额
- 支持部分成员固定、其余平分的混合模式

**使用场景**:
```
交易总额: ¥1000
- 成员A: 固定 ¥500
- 成员B: 固定 ¥300
- 成员C和D: 平分剩余 ¥200（各 ¥100）
```

### 1.3 按权重分摊

**需求描述**:
- 根据预设的权重比例分摊
- 适用于家庭成员收入比例分摊
- 支持保存常用权重模板

**技术实现**:
```rust
// 计算权重分摊
fn calculate_weighted_split(
    total_amount: Decimal,
    members: Vec<(String, i32)>, // (member_id, weight)
) -> Vec<(String, Decimal)> {
    let total_weight: i32 = members.iter().map(|(_, w)| w).sum();
    
    members.into_iter().map(|(id, weight)| {
        let amount = total_amount * Decimal::from(weight) / Decimal::from(total_weight);
        (id, amount)
    }).collect()
}
```

### 1.4 分摊规则模板

**需求描述**:
- 保存常用的分摊规则为模板
- 快速应用到新交易
- 支持模板管理（创建、编辑、删除）

**数据结构**:
```rust
pub struct SplitRuleTemplate {
    pub serial_num: String,
    pub name: String,
    pub split_type: SplitType,
    pub members: Vec<SplitMemberData>,
    pub is_default: bool,
}
```

---

## 阶段2: 状态管理与流程 ✅

### 目标
实现完整的分摊记录生命周期管理

### 2.1 分摊记录状态流转

**状态定义**:
```rust
pub enum SplitRecordStatus {
    Pending,      // 待确认 - 刚创建
    Confirmed,    // 已确认 - 成员确认分摊
    Paid,         // 已支付 - 已完成支付
    Cancelled,    // 已取消 - 交易取消
}
```

**状态流转**:
```
创建交易
    ↓
Pending (待确认)
    ↓
成员确认
    ↓
Confirmed (已确认)
    ↓
完成支付
    ↓
Paid (已支付)
```

### 2.2 确认流程

**需求描述**:
- 成员可以查看待确认的分摊记录
- 成员确认或拒绝分摊
- 支持批量确认

**API 设计**:
```rust
#[tauri::command]
pub async fn confirm_split_records(
    state: State<AppState>,
    serial_nums: Vec<String>,
    member_serial_num: String,
) -> Result<ApiResponse<Vec<SplitRecordResponse>>, String> {
    // 1. 验证成员权限
    // 2. 更新状态为 Confirmed
    // 3. 记录确认时间
    // 4. 发送通知（如果需要）
}
```

**前端界面**:
```vue
<template>
  <div class="pending-split-list">
    <h3>待确认的分摊 ({{ pendingCount }})</h3>
    <div v-for="split in pendingSplits" :key="split.serialNum">
      <div class="split-card">
        <div class="split-info">
          <span>{{ split.description }}</span>
          <strong>¥{{ split.splitAmount }}</strong>
        </div>
        <div class="split-actions">
          <button @click="confirmSplit(split.serialNum)">确认</button>
          <button @click="rejectSplit(split.serialNum)">拒绝</button>
        </div>
      </div>
    </div>
  </div>
</template>
```

### 2.3 支付流程

**需求描述**:
- 标记分摊记录为已支付
- 记录支付时间和方式
- 更新成员债务关系

**技术实现**:
```rust
#[tauri::command]
pub async fn mark_split_paid(
    state: State<AppState>,
    split_serial_num: String,
    payment_method: String,
    payment_date: Option<DateTime<FixedOffset>>,
) -> Result<ApiResponse<SplitRecordResponse>, String> {
    // 1. 更新状态为 Paid
    // 2. 记录支付时间
    // 3. 更新 debt_relations 表
    // 4. 触发结算逻辑（如果需要）
}
```

### 2.4 提醒功能

**需求描述**:
- 定时检查未支付的分摊记录
- 到期前提醒相关成员
- 支持自定义提醒规则

**实现方案**:
```rust
// scheduler/split_reminder.rs
pub async fn check_and_send_reminders(db: &DatabaseConnection) {
    let overdue_splits = entity::split_records::Entity::find()
        .filter(entity::split_records::Column::Status.eq("Confirmed"))
        .filter(entity::split_records::Column::DueDate.lt(DateUtils::local_now()))
        .filter(entity::split_records::Column::ReminderSent.eq(false))
        .all(db)
        .await?;
    
    for split in overdue_splits {
        // 发送提醒通知
        send_reminder_notification(&split).await?;
        
        // 更新提醒状态
        update_reminder_sent(&split.serial_num, db).await?;
    }
}
```

---

## 阶段3: 数据优化与清理 🧹

### 目标
完全废弃 JSON 字段，使用规范化表存储

### 3.1 评估阶段（迁移后3个月）

**检查清单**:
- [ ] 99%+ 用户已执行数据迁移
- [ ] 新功能全部使用 split_records 表
- [ ] 无代码依赖 split_members JSON
- [ ] 性能监控数据满意

**验证查询**:
```sql
-- 检查还有多少交易只有 JSON 没有 split_records
SELECT COUNT(*) 
FROM transactions t
WHERE t.split_members IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM split_records sr 
    WHERE sr.transaction_serial_num = t.serial_num
);
```

### 3.2 代码清理

**步骤**:
1. **标记废弃**（1个月缓冲期）
   ```rust
   #[deprecated(note = "Use split_records table instead")]
   pub split_members: Option<Json>,
   ```

2. **移除读取逻辑**
   - 删除 JSON 解析代码
   - 删除回退查询逻辑
   - 更新所有依赖代码

3. **移除写入逻辑**
   - 停止更新 split_members 字段
   - 只使用 split_records 表

### 3.3 数据库迁移

**创建迁移脚本**:
```rust
// migration/src/m20260301_drop_split_members.rs
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 1. 最后检查：确保所有数据已迁移
        let pending_count = check_pending_migrations(manager).await?;
        if pending_count > 0 {
            return Err(DbErr::Migration(
                format!("Still {} transactions not migrated", pending_count)
            ));
        }
        
        // 2. 删除 split_members 列
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::SplitMembers)
                    .to_owned()
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚：重新添加列
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(
                        ColumnDef::new(Transactions::SplitMembers)
                            .json()
                            .null()
                    )
                    .to_owned()
            )
            .await
    }
}
```

### 3.4 性能优化

**索引优化**:
```sql
-- 为常用查询添加组合索引
CREATE INDEX idx_split_records_member_status 
ON split_records(owe_member_serial_num, status);

CREATE INDEX idx_split_records_ledger_date 
ON split_records(family_ledger_serial_num, created_at);

-- 分析查询性能
EXPLAIN QUERY PLAN
SELECT COUNT(*) 
FROM split_records 
WHERE owe_member_serial_num = ? AND status = 'Pending';
```

**统计缓存**:
```rust
// 缓存成员统计，避免每次计算
pub struct MemberStatsCache {
    member_serial_num: String,
    total_paid: Decimal,
    total_owed: Decimal,
    transaction_count: i32,
    last_updated: DateTime<FixedOffset>,
}

// 定时更新缓存
pub async fn refresh_member_stats_cache(db: &DatabaseConnection) {
    // 每小时或交易变更时更新
}
```

---

## 实施检查表 ✅

### 阶段1：分摊规则（预计1-2个月）
- [ ] 设计 UI/UX 原型
- [ ] 实现按百分比分摊
- [ ] 实现固定金额分摊
- [ ] 实现按权重分摊
- [ ] 创建分摊规则模板
- [ ] 编写测试用例
- [ ] 用户测试和反馈

### 阶段2：状态流程（预计2-3个月）
- [ ] 设计状态流转图
- [ ] 实现确认流程 API
- [ ] 实现支付流程 API
- [ ] 实现提醒功能
- [ ] 创建通知系统
- [ ] 前端界面开发
- [ ] 集成测试

### 阶段3：数据清理（预计1-2个月）
- [ ] 监控迁移完成度
- [ ] 标记 JSON 字段废弃
- [ ] 移除相关代码
- [ ] 创建数据库迁移
- [ ] 性能测试
- [ ] 生产环境部署

---

## 技术债务管理 ⚠️

### 当前已知问题
1. **简化的分摊逻辑**
   - 当前：付款人和欠款人相同
   - 改进：区分实际付款人和分摊成员

2. **缺少事务一致性**
   - 当前：split_records 创建失败不影响交易
   - 改进：使用数据库事务保证一致性

3. **无批量操作**
   - 当前：逐条创建 split_records
   - 改进：批量插入提升性能

### 重构建议
```rust
// 未来架构：使用事务确保一致性
pub async fn create_transaction_with_splits(
    db: &DatabaseConnection,
    transaction_data: CreateTransactionRequest,
    split_data: Vec<SplitMemberData>,
) -> MijiResult<(Transaction, Vec<SplitRecord>)> {
    let tx = db.begin().await?;
    
    // 1. 创建交易
    let transaction = create_transaction(&tx, transaction_data).await?;
    
    // 2. 批量创建 split_records
    let splits = batch_create_splits(&tx, &transaction.serial_num, split_data).await?;
    
    // 3. 更新成员统计
    update_member_stats(&tx, &splits).await?;
    
    tx.commit().await?;
    
    Ok((transaction, splits))
}
```

---

## 成功指标 📈

### 功能指标
- ✅ 支持 4+ 种分摊方式
- ✅ 状态流转完整准确
- ✅ 提醒发送及时率 > 95%
- ✅ 100% 数据使用规范化表

### 性能指标
- ✅ 查询响应时间 < 50ms
- ✅ 统计计算时间 < 100ms
- ✅ 支持 10000+ split_records

### 用户体验指标
- ✅ 界面操作流畅
- ✅ 分摊规则易理解
- ✅ 确认流程简单
- ✅ 提醒及时不扰民

---

## 参考资料 📚

### 相关文档
- `FIXES_MEMBER_STATS.md` - 基础实现
- `IMPLEMENTATION_SUMMARY.md` - 当前架构
- `MIGRATE_SPLIT_RECORDS.md` - 数据迁移

### 外部参考
- Splitwise - 分摊应用最佳实践
- Tricount - 团队费用管理
- Settle Up - 债务结算算法

---

**这是一个渐进式的改进计划，每个阶段都是独立可交付的。根据用户反馈和业务需求灵活调整优先级。** 🚀
