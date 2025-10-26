# 预算总览功能

## 概述

预算总览功能提供了对用户预算使用情况的全面统计和分析。该功能能够计算当前有效预算的总金额、已使用金额、剩余金额、完成率等关键指标。

## 功能特性

### 1. 基础统计
- **总预算金额**: 所有有效预算的总和
- **已使用金额**: 当前周期内已使用的预算金额
- **剩余金额**: 总预算减去已使用金额
- **完成率**: 已使用金额占总预算的百分比
- **超预算金额**: 超出预算的金额
- **预算数量**: 有效预算的总数量
- **超预算数量**: 超出预算的预算数量

### 2. 分组统计
- **按预算类型分组**: 根据预算类型（如标准、储蓄、债务等）进行分组统计
- **按预算范围类型分组**: 根据预算范围类型（如Category、Account、Hybrid、RuleBased）进行分组统计

### 3. 时间维度
- **当前周期**: 基于`current_period_start`和`current_period_used`字段
- **指定日期**: 可以计算任意日期的预算总览

## 技术实现

### 后端服务

#### BudgetOverviewService
位于: `src-tauri/crates/money/src/services/budget_overview.rs`

主要方法:
- `calculate_overview()`: 计算总体预算总览
- `calculate_by_budget_type()`: 按预算类型分组计算
- `calculate_by_scope_type()`: 按预算范围类型分组计算

#### Tauri命令
- `budget_overview_calculate`: 计算预算总览
- `budget_overview_by_type`: 按预算类型计算
- `budget_overview_by_scope`: 按预算范围计算

### 前端服务

#### BudgetOverviewService
位于: `src/services/money/budgetOverview.ts`

主要方法:
- `getCurrentMonthOverview()`: 获取当前月份预算总览
- `getOverviewByDate()`: 获取指定日期的预算总览
- `calculateByBudgetType()`: 按预算类型分组计算
- `calculateByScopeType()`: 按预算范围类型分组计算

#### MoneyDb集成
位于: `src/services/money/money.ts`

便捷方法:
- `getBudgetOverview()`: 获取预算总览
- `getBudgetOverviewByDate()`: 获取指定日期的预算总览
- `getBudgetOverviewByType()`: 按预算类型获取总览
- `getBudgetOverviewByScope()`: 按预算范围获取总览

## 查询条件

### 基础筛选条件
```sql
SELECT * FROM budget 
WHERE is_active = true 
  AND start_date <= 当前时间 
  AND end_date >= 当前时间 
  AND currency = '基础货币'
```

### 参数说明
- `is_active`: 只计算激活的预算
- `start_date <= 当前时间 <= end_date`: 预算在当前有效期内
- `currency`: 按基础货币分组计算
- `include_inactive`: 是否包含非激活预算（可选，默认为false）

## 数据结构

### BudgetOverviewSummary
```typescript
interface BudgetOverviewSummary {
  totalBudgetAmount: number;      // 总预算金额
  usedAmount: number;             // 已使用金额（当前周期）
  remainingAmount: number;        // 剩余金额
  completionRate: number;         // 预算完成率（百分比）
  overBudgetAmount: number;       // 超预算金额
  budgetCount: number;            // 预算数量
  overBudgetCount: number;        // 超预算数量
  currency: string;               // 货币
  calculatedAt: string;           // 计算时间
}
```

### BudgetOverviewRequest
```typescript
interface BudgetOverviewRequest {
  baseCurrency: string;           // 基础货币
  calculationDate?: string;       // 计算日期（可选，默认为当前时间）
  includeInactive?: boolean;      // 是否包含非激活预算（可选，默认为false）
}
```

## 使用示例

### 1. 获取当前月份预算总览
```typescript
import { MoneyDb } from '@/services/money/money';

const overview = await MoneyDb.getBudgetOverview('CNY');
console.log('总预算:', overview.totalBudgetAmount);
console.log('已使用:', overview.usedAmount);
console.log('剩余:', overview.remainingAmount);
console.log('完成率:', overview.completionRate + '%');
```

### 2. 按预算类型分组统计
```typescript
import { MoneyDb } from '@/services/money/money';

const byType = await MoneyDb.getBudgetOverviewByType('CNY');
for (const [type, summary] of Object.entries(byType)) {
  console.log(`${type}: 总预算${summary.totalBudgetAmount}, 已使用${summary.usedAmount}`);
}
```

### 3. 获取指定日期的预算总览
```typescript
import { MoneyDb } from '@/services/money/money';

const specificDate = new Date('2024-01-15');
const overview = await MoneyDb.getBudgetOverviewByDate('CNY', specificDate, false);
console.log('指定日期预算总览:', overview);
```

## 前端集成

### MoneyView.vue
在`src/features/money/views/MoneyView.vue`中集成了预算总览功能:

- 添加了预算总览相关的响应式变量
- 实现了`syncBudgetOverview()`函数来同步预算数据
- 更新了预算总览卡片显示真实的计算数据
- 在预算变更时自动刷新预算总览

### 显示内容
- 总预算金额
- 已使用金额
- 剩余金额
- 预算完成率
- 超预算数量

## 测试

### 测试文件
位于: `src/services/money/budgetOverview.test.ts`

测试方法:
- `testBudgetOverview()`: 测试预算总览功能
- `validateBudgetOverviewData()`: 验证预算总览数据结构
- `testBudgetOverviewLogic()`: 测试预算总览计算逻辑

### 运行测试
```typescript
import budgetOverviewTest from '@/services/money/budgetOverview.test';

// 运行所有测试
await budgetOverviewTest.testBudgetOverview();
await budgetOverviewTest.testBudgetOverviewLogic();
```

## 注意事项

1. **货币一致性**: 所有计算都基于指定的基础货币
2. **时间范围**: 只计算在当前有效期内且激活的预算
3. **数据精度**: 金额计算使用Decimal类型，确保精度
4. **错误处理**: 包含完整的错误处理机制
5. **性能优化**: 使用数据库查询优化，避免N+1查询问题

## 更新日志

- **2025-01-26**: 初始版本，实现基础预算总览计算功能
- **2025-01-26**: 添加按预算类型和范围类型分组统计
- **2025-01-26**: 集成到MoneyView.vue前端界面
- **2025-01-26**: 添加测试用例和文档
