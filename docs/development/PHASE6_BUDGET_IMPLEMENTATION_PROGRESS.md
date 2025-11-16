# Phase 6.1: 家庭预算功能 - 实施进度

**开始时间**: 2025-11-16  
**当前状态**: 🚧 进行中  
**完成度**: 35%  
**设计方案**: ✅ 扩展现有Budget表

---

## 🎯 设计决策

### 方案选择：扩展现有 Budget 表 ⭐

**理由**:
- ✅ 避免代码重复（DRY原则）
- ✅ 统一的预算管理逻辑
- ✅ 符合项目现有设计模式
- ✅ 更简洁的架构

**实现方式**:
```sql
-- 扩展 Budget 表
ALTER TABLE budget ADD COLUMN family_ledger_serial_num VARCHAR;
ALTER TABLE budget ADD COLUMN created_by VARCHAR;

-- 区分个人预算和家庭预算：
-- - account_serial_num 有值 = 个人预算
-- - family_ledger_serial_num 有值 = 家庭预算
```

---

## ✅ 已完成

### 1. 数据库层 (100%)

#### 新增迁移文件
- ✅ `m20251116_000007_enhance_budget_for_family.rs`

#### Budget 表扩展
- ✅ 添加 `family_ledger_serial_num` 字段（可选）
- ✅ 添加 `created_by` 字段
- ✅ 创建索引 `idx_budget_family_ledger`

#### 新表：budget_allocations
```sql
budget_allocations:
- serial_num (PK, String)  # 遵循项目设计模式
- budget_serial_num (FK → budget.serial_num)
- category_serial_num (可选)  # null = 所有分类
- member_serial_num (可选)    # null = 所有成员
- allocated_amount, used_amount, remaining_amount
- percentage (占总预算的百分比)
- timestamps
```

**索引**:
- `idx_budget_allocations_budget`
- `idx_budget_allocations_category`
- `idx_budget_allocations_member`

**外键**:
- `fk_budget_allocations_budget` (CASCADE)

### 2. Schema层 (100%)
- ✅ 在 `schema.rs` 添加 `BudgetAllocations` 定义
- ✅ 注册迁移到 `lib.rs`

### 3. Entity层 (100%)
- ✅ 创建 `budget_allocations.rs` Entity
  - 使用 `serial_num` 作为主键 ✅
  - 定义与 `Budget` 的关系

### 4. DTO层 (100%)
- ✅ 创建 `dto/family_budget.rs`

**核心DTO**:
1. `BudgetAllocationResponse` - 分配响应
2. `FamilyBudgetCreateRequest` - 创建请求（扩展Budget）
3. `BudgetAllocationCreateRequest` - 分配请求
4. `BudgetAllocationUpdateRequest` - 分配更新
5. `BudgetUsageRequest` - 使用记录
6. `BudgetStatisticsResponse` - 统计响应
7. `FamilyBudgetListQuery` - 查询参数
8. `BudgetAlertResponse` - 提醒响应
9. `BudgetAdjustmentSuggestion` - 调整建议

**说明**:
- 家庭预算的响应使用现有 `BudgetResponse`（从budget.rs）
- 家庭预算的更新使用现有 `BudgetUpdateRequest`
- 只需要额外的分配管理DTO

---

## 🚧 进行中

### 5. Service层 (0%)

需要创建 `services/family_budget_service.rs`:

**核心功能**:
```rust
// 1. 家庭预算CRUD（扩展Budget Service）
- create_family_budget() - 创建家庭预算
  - 验证 family_ledger_serial_num
  - 创建Budget记录
  - 创建分配记录
- get_family_budget() - 获取预算详情（含分配）
- list_family_budgets() - 按账本查询
- update_family_budget() - 更新（复用Budget逻辑）
- delete_family_budget() - 删除（软删除）

// 2. 预算分配管理
- create_allocations() - 批量创建分配
- update_allocation() - 更新单个分配
- delete_allocation() - 删除分配
- get_allocations_by_budget() - 查询预算的所有分配

// 3. 使用追踪（核心功能）
- record_budget_usage() - 记录预算使用
  - 根据交易自动更新预算
  - 更新对应分配的使用金额
  - 检查预警阈值
- sync_with_transaction() - 与交易同步

// 4. 统计与分析
- get_budget_statistics() - 统计数据
- check_budget_alerts() - 检查预警
- calculate_usage_percentage() - 计算使用率

// 5. 智能建议
- get_adjustment_suggestions() - 获取调整建议
- analyze_budget_health() - 预算健康度分析
```

---

## ⏳ 待完成

### 6. Commands层 (0%)

在 `command.rs` 添加 Tauri Commands:

```rust
// 家庭预算管理（扩展Budget Commands）
- family_budget_create
- family_budget_get
- family_budget_list
- family_budget_update (复用budget_update)
- family_budget_delete

// 预算分配管理
- budget_allocation_create_batch
- budget_allocation_update
- budget_allocation_delete
- budget_allocations_list

// 统计查询
- family_budget_statistics
- family_budget_alerts
- budget_usage_record
```

### 7. 前端Store (0%)

创建 `stores/money/family-budget.ts`:

```typescript
export const useFamilyBudgetStore = defineStore('family-budget', () => {
  // State
  const budgets = ref<Budget[]>([])  // 复用Budget类型
  const currentBudget = ref<Budget | null>(null)
  const allocations = ref<BudgetAllocation[]>([])
  const alerts = ref<BudgetAlert[]>([])
  
  // Getters
  const familyBudgets = computed(() => 
    budgets.value.filter(b => b.familyLedgerSerialNum)
  )
  const activeBudgets = computed(() =>
    familyBudgets.value.filter(b => b.isActive)
  )
  
  // Actions
  async function fetchFamilyBudgets(ledgerSerialNum: string) {}
  async function createFamilyBudget(data: FamilyBudgetCreate) {}
  // ... 其他方法
})
```

### 8. 前端组件 (0%)

复用现有预算组件，添加家庭预算特有功能：

1. **BudgetAllocationEditor.vue** (~400行) ⭐ 新增
   - 分配配置界面
   - 成员选择
   - 分类选择
   - 金额/百分比输入
   
2. **FamilyBudgetCard.vue** (~300行) - 扩展现有BudgetCard
   - 显示分配信息
   - 成员使用情况
   
3. **BudgetMemberUsageChart.vue** (~250行) ⭐ 新增
   - 成员使用对比图
   - ECharts可视化

### 9. 页面集成 (0%)

扩展 `/money/budgets.vue`:
- 添加"家庭预算"tab
- 显示家庭账本的预算列表
- 集成分配编辑器

---

## 📊 数据模型对比

### Budget 表（扩展后）

| 字段 | 个人预算 | 家庭预算 |
|------|---------|----------|
| `account_serial_num` | ✅ 有值 | ❌ null |
| `family_ledger_serial_num` | ❌ null | ✅ 有值 |
| `created_by` | 用户ID | 成员SerialNum |
| 其他字段 | 共用 | 共用 |

### 关系图

```
Budget (扩展)
├─ account_serial_num → Account (个人预算)
├─ family_ledger_serial_num → FamilyLedger (家庭预算)
└─ BudgetAllocations (1:N)
    ├─ category_serial_num → Categories
    └─ member_serial_num → FamilyMember
```

---

## 🎯 使用场景

### 场景1：创建家庭月度预算

```typescript
// 前端调用
const result = await invoke('family_budget_create', {
  familyLedgerSerialNum: 'FL001',
  name: '11月家庭预算',
  budgetType: 'MONTHLY',
  amount: 5000,
  startDate: '2025-11-01',
  endDate: '2025-11-30',
  currency: 'CNY',
  createdBy: 'M001',
  allocations: [
    { categorySerialNum: 'C001', allocatedAmount: 1500 }, // 餐饮
    { categorySerialNum: 'C002', allocatedAmount: 800 },  // 交通
    { memberSerialNum: 'M001', allocatedAmount: 2000 },   // 张三
    { memberSerialNum: 'M002', allocatedAmount: 700 },    // 李四
  ]
})
```

### 场景2：交易自动更新预算

```rust
// 后端逻辑
当创建交易时：
1. 检查交易所属账本的活动预算
2. 找到匹配的分配（按分类/成员）
3. 更新 used_amount 和 remaining_amount
4. 检查是否达到预警阈值
5. 生成预警记录
```

---

## 📝 技术要点

### 预算类型判断

```rust
fn is_family_budget(budget: &Budget) -> bool {
    budget.family_ledger_serial_num.is_some()
}

fn is_personal_budget(budget: &Budget) -> bool {
    budget.account_serial_num.is_some()
}
```

### 分配验证

```rust
// 创建分配时验证
1. 所有分配金额之和 <= 总预算
2. category_serial_num 和 member_serial_num 不能都为 null
3. 同一预算下，相同的(category, member)组合不能重复
4. percentage如果指定，计算 allocated_amount = total * percentage / 100
```

### 使用记录

```rust
// 交易创建/更新时
async fn update_budget_usage(
    transaction: &Transaction,
    family_ledger_serial_num: &str,
    db: &DatabaseConnection
) -> Result<()> {
    // 1. 查找活动的家庭预算
    let budgets = find_active_family_budgets(family_ledger_serial_num, db).await?;
    
    for budget in budgets {
        // 2. 找到匹配的分配
        let allocations = find_matching_allocations(
            &budget,
            transaction.category,
            transaction.member_serial_num,
            db
        ).await?;
        
        for allocation in allocations {
            // 3. 更新使用金额
            update_allocation_usage(&allocation, transaction.amount, db).await?;
        }
        
        // 4. 更新预算总使用额
        update_budget_used_amount(&budget, db).await?;
        
        // 5. 检查预警
        check_and_create_alerts(&budget, db).await?;
    }
    
    Ok(())
}
```

---

## 🎉 优势总结

### vs. 创建独立FamilyBudgets表

| 方面 | 扩展Budget | 独立FamilyBudgets |
|------|-----------|------------------|
| 代码复用 | ✅ 100% | ❌ 大量重复 |
| 维护成本 | ✅ 低 | ❌ 高 |
| 一致性 | ✅ 统一 | ❌ 可能不一致 |
| 学习曲线 | ✅ 平缓 | ❌ 需要理解两套逻辑 |
| 扩展性 | ✅ 良好 | ⚠️ 一般 |

### 设计原则遵循

1. **DRY (Don't Repeat Yourself)** ✅
2. **Single Source of Truth** ✅
3. **项目一致性** ✅ (使用serial_num作为主键)
4. **最小化改动** ✅ (只扩展,不重构)

---

## 📊 当前进度

```
Phase 6.1 家庭预算管理:
├── 数据库层    ████████████ 100% ✅
├── Schema层    ████████████ 100% ✅
├── Entity层    ████████████ 100% ✅
├── DTO层       ████████████ 100% ✅
├── Service层   ░░░░░░░░░░░░   0% ⏳
├── Commands层  ░░░░░░░░░░░░   0% ⏳
├── 前端Store   ░░░░░░░░░░░░   0% ⏳
├── 前端组件    ░░░░░░░░░░░░   0% ⏳
└── 页面集成    ░░░░░░░░░░░░   0% ⏳
─────────────────────────────────
整体完成度:     ████░░░░░░░░  35%
```

---

## 📁 已创建/修改文件

### 后端
1. `src-tauri/migration/src/m20251116_000007_enhance_budget_for_family.rs` ✅ 新建
2. `src-tauri/migration/src/schema.rs` ✅ 修改
3. `src-tauri/migration/src/lib.rs` ✅ 修改
4. `src-tauri/entity/src/budget_allocations.rs` ✅ 新建
5. `src-tauri/entity/src/lib.rs` ✅ 修改
6. `src-tauri/crates/money/src/dto/family_budget.rs` ✅ 修改
7. `src-tauri/crates/money/src/dto.rs` ✅ 修改

### 文档
8. `docs/development/PHASE6_BUDGET_IMPLEMENTATION_PROGRESS.md` ✅ 更新

---

## 🚀 下一步

**立即任务**: 实现Service层（预计1-2小时）
- 家庭预算CRUD
- 分配管理
- 使用追踪逻辑

**明天任务**: 实现Commands层和前端Store

---

**状态**: 基础架构完成35%，准备实现业务逻辑！ 💪
