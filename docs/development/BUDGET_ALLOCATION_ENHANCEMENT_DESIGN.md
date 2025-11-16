# 预算分配增强设计方案

**创建时间**: 2025-11-16  
**目的**: 支持家庭预算的成员分配规则和超支控制

---

## 🎯 需求分析

### 核心需求
1. **分配规则** - 固定金额 vs 百分比 vs 共享
2. **超支控制** - 允许/禁止超支，超支限额
3. **预警提醒** - 可配置的预警阈值
4. **优先级** - 分配的优先级

### 使用场景

#### 场景1：成员固定预算
```
11月家庭预算 5000元
├─ 张三（成员）：1500元 餐饮
│  ├─ 不允许超支
│  └─ 达到80%时提醒
├─ 李四（成员）：1000元 交通
│  ├─ 允许超支10%
│  └─ 达到90%时提醒
└─ 共用：1700元 其他
   └─ 自由使用
```

#### 场景2：按分类分配
```
餐饮总预算 2000元
├─ 外卖：800元 - 不允许超支
├─ 聚餐：700元 - 允许超支20%
└─ 零食：500元 - 自由
```

#### 场景3：组合分配
```
张三的预算 3000元
├─ 餐饮：1000元
├─ 交通：500元
└─ 娱乐：1500元
每个都可以设置独立的超支规则
```

---

## 💡 设计方案

### 方案A：扩展 budget_allocations 表 ⭐ 推荐

#### 新增字段

```sql
ALTER TABLE budget_allocations ADD COLUMN:
  
-- 分配规则
allocation_type VARCHAR         -- FIXED_AMOUNT, PERCENTAGE, SHARED
rule_config JSONB               -- 规则配置（复杂规则）

-- 超支控制
allow_overspend BOOLEAN DEFAULT FALSE
overspend_limit_type VARCHAR    -- PERCENTAGE, FIXED_AMOUNT, NONE
overspend_limit_value DECIMAL   -- 超支限额值

-- 预警设置
alert_enabled BOOLEAN DEFAULT TRUE
alert_threshold INTEGER DEFAULT 80  -- 预警阈值百分比
alert_config JSONB              -- 复杂预警配置

-- 优先级
priority INTEGER DEFAULT 0      -- 优先级（1-5）
is_mandatory BOOLEAN DEFAULT FALSE  -- 是否强制（不可削减）

-- 状态
status VARCHAR DEFAULT 'ACTIVE' -- ACTIVE, PAUSED, COMPLETED
notes TEXT                      -- 备注说明
```

#### 完整表结构

```sql
CREATE TABLE budget_allocations (
  -- 基础字段
  serial_num VARCHAR PRIMARY KEY,
  budget_serial_num VARCHAR NOT NULL,
  category_serial_num VARCHAR NULL,
  member_serial_num VARCHAR NULL,
  
  -- 金额字段
  allocated_amount DECIMAL(15,2) NOT NULL,
  used_amount DECIMAL(15,2) DEFAULT 0,
  remaining_amount DECIMAL(15,2) NOT NULL,
  percentage DECIMAL(5,2) NULL,
  
  -- 分配规则（新增）
  allocation_type VARCHAR DEFAULT 'FIXED_AMOUNT',
  rule_config JSONB NULL,
  
  -- 超支控制（新增）
  allow_overspend BOOLEAN DEFAULT FALSE,
  overspend_limit_type VARCHAR NULL,
  overspend_limit_value DECIMAL(10,2) NULL,
  
  -- 预警设置（新增）
  alert_enabled BOOLEAN DEFAULT TRUE,
  alert_threshold INTEGER DEFAULT 80,
  alert_config JSONB NULL,
  
  -- 管理字段（新增）
  priority INTEGER DEFAULT 0,
  is_mandatory BOOLEAN DEFAULT FALSE,
  status VARCHAR DEFAULT 'ACTIVE',
  notes TEXT NULL,
  
  -- 时间戳
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NULL
);
```

---

## 📋 字段详细说明

### allocation_type - 分配类型

```typescript
enum AllocationType {
  FIXED_AMOUNT = 'FIXED_AMOUNT',   // 固定金额
  PERCENTAGE = 'PERCENTAGE',        // 按百分比
  SHARED = 'SHARED',               // 共享池
  DYNAMIC = 'DYNAMIC'              // 动态分配（根据规则）
}
```

**示例**：
```json
// 固定金额
{ "type": "FIXED_AMOUNT", "amount": 1500 }

// 百分比
{ "type": "PERCENTAGE", "percentage": 30 }

// 共享池（所有成员共享）
{ "type": "SHARED" }

// 动态（根据使用情况调整）
{ "type": "DYNAMIC", "min": 500, "max": 2000 }
```

### allow_overspend - 允许超支

```typescript
boolean // true = 允许超支, false = 严格限制
```

### overspend_limit_type - 超支限额类型

```typescript
enum OverspendLimitType {
  NONE = 'NONE',               // 无限制
  PERCENTAGE = 'PERCENTAGE',   // 百分比限制
  FIXED_AMOUNT = 'FIXED_AMOUNT' // 固定金额限制
}
```

**示例**：
```json
// 不允许超支
{ "allow_overspend": false }

// 允许超支10%
{ 
  "allow_overspend": true,
  "overspend_limit_type": "PERCENTAGE",
  "overspend_limit_value": 10
}

// 允许超支最多200元
{
  "allow_overspend": true,
  "overspend_limit_type": "FIXED_AMOUNT",
  "overspend_limit_value": 200
}
```

### alert_threshold - 预警阈值

```typescript
number // 1-100，表示使用率达到多少时提醒
```

**示例**：
```json
// 使用80%时提醒
{ "alert_threshold": 80 }

// 使用50%时就提醒（保守）
{ "alert_threshold": 50 }

// 使用95%时才提醒（宽松）
{ "alert_threshold": 95 }
```

### alert_config - 复杂预警配置

```typescript
interface AlertConfig {
  thresholds: number[];           // 多级预警 [50, 80, 90, 100]
  methods: string[];              // 提醒方式 ['notification', 'email']
  recipients: string[];           // 接收人
  quietHours?: {                  // 免打扰时段
    start: string;
    end: string;
  };
}
```

**示例**：
```json
{
  "thresholds": [50, 80, 95, 100],
  "methods": ["notification", "email"],
  "recipients": ["member_001", "member_002"],
  "quietHours": {
    "start": "22:00",
    "end": "08:00"
  }
}
```

### priority - 优先级

```typescript
number // 1-5
// 1 = 最低优先级（可削减）
// 3 = 中等优先级
// 5 = 最高优先级（必须保障）
```

### is_mandatory - 是否强制

```typescript
boolean
// true = 强制分配，预算调整时不可削减
// false = 可选分配，预算不足时可以削减
```

---

## 🔄 业务逻辑

### 1. 创建分配时的验证

```typescript
async function createAllocation(data: AllocationCreateRequest) {
  // 1. 验证金额
  if (data.allocationType === 'FIXED_AMOUNT') {
    assert(data.allocatedAmount > 0);
  }
  
  if (data.allocationType === 'PERCENTAGE') {
    assert(data.percentage > 0 && data.percentage <= 100);
    data.allocatedAmount = budgetTotal * (data.percentage / 100);
  }
  
  // 2. 验证总额不超预算
  const totalAllocated = await sumAllocatedAmount(budgetSerialNum);
  assert(totalAllocated + data.allocatedAmount <= budgetTotalAmount);
  
  // 3. 设置默认值
  data.alertThreshold = data.alertThreshold || 80;
  data.allowOverspend = data.allowOverspend || false;
  data.priority = data.priority || 3;
  
  return save(data);
}
```

### 2. 记录使用时的检查

```typescript
async function recordUsage(
  allocationSerialNum: string,
  amount: Decimal,
  transactionSerialNum: string
) {
  const allocation = await findAllocation(allocationSerialNum);
  
  // 1. 更新使用金额
  const newUsedAmount = allocation.usedAmount + amount;
  const newRemainingAmount = allocation.allocatedAmount - newUsedAmount;
  
  // 2. 检查是否超支
  if (newRemainingAmount < 0) {
    if (!allocation.allowOverspend) {
      throw new Error('预算不足，且不允许超支');
    }
    
    // 检查超支限额
    const overspendAmount = Math.abs(newRemainingAmount);
    if (allocation.overspendLimitType === 'PERCENTAGE') {
      const maxOverspend = allocation.allocatedAmount * 
        (allocation.overspendLimitValue / 100);
      if (overspendAmount > maxOverspend) {
        throw new Error(`超支超过限额 ${allocation.overspendLimitValue}%`);
      }
    } else if (allocation.overspendLimitType === 'FIXED_AMOUNT') {
      if (overspendAmount > allocation.overspendLimitValue) {
        throw new Error(`超支超过限额 ${allocation.overspendLimitValue}元`);
      }
    }
  }
  
  // 3. 检查预警
  const usagePercentage = (newUsedAmount / allocation.allocatedAmount) * 100;
  if (allocation.alertEnabled && 
      usagePercentage >= allocation.alertThreshold) {
    await createAlert({
      type: 'BUDGET_ALERT',
      allocation: allocation,
      usagePercentage: usagePercentage,
      message: `预算使用已达 ${usagePercentage.toFixed(1)}%`
    });
  }
  
  // 4. 更新分配
  await updateAllocation(allocationSerialNum, {
    usedAmount: newUsedAmount,
    remainingAmount: newRemainingAmount
  });
  
  return { success: true, alert: usagePercentage >= allocation.alertThreshold };
}
```

### 3. 超支检查

```typescript
function canSpend(
  allocation: BudgetAllocation,
  amount: Decimal
): { allowed: boolean; reason?: string } {
  const afterAmount = allocation.usedAmount + amount;
  const remaining = allocation.allocatedAmount - afterAmount;
  
  // 未超支，允许
  if (remaining >= 0) {
    return { allowed: true };
  }
  
  // 不允许超支
  if (!allocation.allowOverspend) {
    return { 
      allowed: false, 
      reason: '预算不足，且不允许超支' 
    };
  }
  
  // 检查超支限额
  const overspendAmount = Math.abs(remaining);
  
  if (allocation.overspendLimitType === 'PERCENTAGE') {
    const maxOverspend = allocation.allocatedAmount * 
      (allocation.overspendLimitValue / 100);
    if (overspendAmount > maxOverspend) {
      return { 
        allowed: false, 
        reason: `超支将超过限额 ${allocation.overspendLimitValue}%` 
      };
    }
  } else if (allocation.overspendLimitType === 'FIXED_AMOUNT') {
    if (overspendAmount > allocation.overspendLimitValue) {
      return { 
        allowed: false, 
        reason: `超支将超过限额 ${allocation.overspendLimitValue}元` 
      };
    }
  }
  
  return { allowed: true };
}
```

---

## 📊 使用示例

### 示例1：严格控制的成员预算

```typescript
// 张三的餐饮预算：1500元，不允许超支，80%提醒
{
  budgetSerialNum: 'B001',
  memberSerialNum: 'M001',  // 张三
  categorySerialNum: 'C001', // 餐饮
  allocatedAmount: 1500,
  allocationType: 'FIXED_AMOUNT',
  allowOverspend: false,      // 不允许超支
  alertEnabled: true,
  alertThreshold: 80,         // 使用1200元时提醒
  priority: 5,                // 高优先级
  isMandatory: true,          // 强制保障
  status: 'ACTIVE'
}

// 使用场景
// 当张三消费到1200元（80%）→ 发送提醒
// 当张三消费到1500元 → 允许
// 当张三尝试消费1501元 → 拒绝（不允许超支）
```

### 示例2：允许适度超支

```typescript
// 李四的交通预算：1000元，允许超支10%，90%提醒
{
  budgetSerialNum: 'B001',
  memberSerialNum: 'M002',  // 李四
  categorySerialNum: 'C002', // 交通
  allocatedAmount: 1000,
  allocationType: 'FIXED_AMOUNT',
  allowOverspend: true,        // 允许超支
  overspendLimitType: 'PERCENTAGE',
  overspendLimitValue: 10,     // 最多超支10%（100元）
  alertEnabled: true,
  alertThreshold: 90,          // 使用900元时提醒
  priority: 3,
  status: 'ACTIVE'
}

// 使用场景
// 当李四消费到900元（90%）→ 发送提醒
// 当李四消费到1000元 → 允许，开始超支
// 当李四消费到1100元（超支10%）→ 允许
// 当李四尝试消费1101元 → 拒绝（超过10%限额）
```

### 示例3：共享预算池

```typescript
// 家庭共用预算：2000元，所有成员共享
{
  budgetSerialNum: 'B001',
  memberSerialNum: null,     // 所有成员共享
  categorySerialNum: 'C099', // 其他
  allocatedAmount: 2000,
  allocationType: 'SHARED',   // 共享类型
  allowOverspend: true,
  overspendLimitType: 'FIXED_AMOUNT',
  overspendLimitValue: 300,  // 最多超支300元
  alertEnabled: true,
  alertThreshold: 80,
  priority: 2,
  status: 'ACTIVE'
}

// 任何成员都可以使用这个预算
// 使用1600元时所有成员都收到提醒
// 最多可以使用2300元
```

### 示例4：多级预警

```typescript
// 王五的娱乐预算：800元，多级预警
{
  budgetSerialNum: 'B001',
  memberSerialNum: 'M003',
  categorySerialNum: 'C003',
  allocatedAmount: 800,
  allocationType: 'FIXED_AMOUNT',
  allowOverspend: false,
  alertEnabled: true,
  alertThreshold: 50,  // 主要阈值
  alertConfig: {
    thresholds: [50, 75, 90, 100],  // 多级预警
    methods: ['notification', 'email'],
    recipients: ['M003', 'M001']  // 王五和张三都收到
  },
  priority: 1,  // 低优先级，可削减
  status: 'ACTIVE'
}

// 使用400元（50%）→ 提醒
// 使用600元（75%）→ 再次提醒
// 使用720元（90%）→ 严重警告
// 使用800元（100%）→ 预算用尽提醒
```

---

## 🎨 前端展示

### 分配卡片

```vue
<div class="allocation-card">
  <div class="header">
    <span class="member-name">张三</span>
    <span class="category">餐饮</span>
    <badge v-if="!allowOverspend" type="warning">严格控制</badge>
  </div>
  
  <div class="amount">
    <div class="allocated">预算: ¥1,500</div>
    <div class="used">已用: ¥1,200</div>
    <div class="remaining" :class="{ warning: usageRate >= 80 }">
      剩余: ¥300
    </div>
  </div>
  
  <div class="progress-bar">
    <div class="bar" :style="{ width: `${usageRate}%` }"></div>
    <div class="threshold-line" :style="{ left: `${alertThreshold}%` }"></div>
  </div>
  
  <div class="status">
    <span class="usage-rate">使用率: 80%</span>
    <icon v-if="usageRate >= alertThreshold" name="alert" />
  </div>
  
  <div class="settings">
    <tag v-if="priority === 5">高优先级</tag>
    <tag v-if="isMandatory">强制保障</tag>
  </div>
</div>
```

---

## 🚀 实施步骤

### Step 1: 数据库迁移
```rust
// 创建新的迁移文件
m20251116_000008_enhance_budget_allocations.rs
```

### Step 2: 更新 Schema
```rust
pub enum BudgetAllocations {
    // 新增字段
    AllocationType,
    RuleConfig,
    AllowOverspend,
    OverspendLimitType,
    OverspendLimitValue,
    AlertEnabled,
    AlertThreshold,
    AlertConfig,
    Priority,
    IsMandatory,
    Status,
    Notes,
}
```

### Step 3: 更新 Entity
```rust
pub struct Model {
    // 新增字段
    pub allocation_type: String,
    pub rule_config: Option<Json>,
    pub allow_overspend: bool,
    // ...
}
```

### Step 4: 更新 DTO
```rust
pub struct BudgetAllocationCreateRequest {
    // 新增字段
    pub allocation_type: Option<String>,
    pub allow_overspend: Option<bool>,
    pub overspend_limit_type: Option<String>,
    pub alert_threshold: Option<i32>,
    // ...
}
```

### Step 5: Service 层逻辑
```rust
impl BudgetAllocationService {
    async fn record_usage() { /* 检查超支 */ }
    async fn check_overspend() { /* 验证限额 */ }
    async fn check_alerts() { /* 触发预警 */ }
}
```

---

## ✅ 总结

### 推荐方案
**扩展 budget_allocations 表**，添加 10个新字段：
1. allocation_type - 分配类型
2. rule_config - 规则配置
3. allow_overspend - 允许超支
4. overspend_limit_type - 超支限额类型
5. overspend_limit_value - 超支限额值
6. alert_enabled - 启用预警
7. alert_threshold - 预警阈值
8. alert_config - 预警配置
9. priority - 优先级
10. is_mandatory - 是否强制
11. status - 状态
12. notes - 备注

### 优势
- ✅ 单表设计，简单高效
- ✅ 支持所有场景
- ✅ 灵活的规则配置
- ✅ 完善的超支控制
- ✅ 多级预警系统

### 不需要额外的表
现有设计足够支持所有需求！

---

**需要我立即实现这个增强方案吗？** 🚀
