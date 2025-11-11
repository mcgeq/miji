# Bug 修复：sortOptions 缺少 desc 字段

**修复时间**: 2025-11-11  
**问题**: 调用后端分页接口时 sortOptions 缺少必需的 `desc` 字段

---

## 🐛 错误描述

### 错误信息
```
SystemError: System error: invalid args `query` for command `budget_list_paged`: missing field `desc`
```

### 错误堆栈
```
at invokeCommand (http://localhost:9428/src/types/api.ts:66:13)
at async BudgetMapper.listPaged (http://localhost:9428/src/services/money/budgets.ts:63:22)
at async Proxy.fetchBudgetsPaged (http://localhost:9428/src/stores/money/budget-store.ts:36:29)
at async loadBudgets (http://localhost:9428/src/composables/useBudgetActions.ts:79:9)
```

### 根本原因
在重构过程中，多处代码使用了空的 `sortOptions: {}`，但后端接口要求 `SortOptions` 必须包含 `desc` 字段。

---

## ✅ 修复内容

### 修复的文件 (5个)

| 文件 | 位置 | 修复内容 |
|------|------|---------|
| useBudgetActions.ts | line 103 | 添加 `desc: true` |
| budget-store.ts | line 135 | 添加 `desc: true` |
| reminder-store.ts | line 168 | 添加 `desc: true` |
| account-store.ts | line 72 | 添加 `desc: true` |
| **CategorySelector.vue** | **line 2** | **添加缺失的 import** |

### 修复前
```typescript
sortOptions: {}
```

### 修复后
```typescript
sortOptions: {
  desc: true,
}
```

---

## 📋 详细修复清单

### 1. useBudgetActions.ts
**位置**: `src/composables/useBudgetActions.ts:100-106`

```typescript
// 修复前
await budgetStore.fetchBudgetsPaged({
  currentPage: 1,
  pageSize: 10,
  sortOptions: {},  // ❌ 缺少 desc
  filter: {},
});

// 修复后
await budgetStore.fetchBudgetsPaged({
  currentPage: 1,
  pageSize: 10,
  sortOptions: {
    desc: true,    // ✅ 添加 desc
  },
  filter: {},
});
```

### 2. budget-store.ts
**位置**: `src/stores/money/budget-store.ts:132-139`

```typescript
// toggleBudgetActive 方法中
await this.fetchBudgetsPaged({
  currentPage: this.budgetsPaged.currentPage,
  pageSize: this.budgetsPaged.pageSize,
  sortOptions: {
    desc: true,    // ✅ 添加 desc
  },
  filter: {},
});
```

### 3. reminder-store.ts
**位置**: `src/stores/money/reminder-store.ts:165-172`

```typescript
// toggleReminderActive 方法中
await this.fetchRemindersPaged({
  currentPage: this.remindersPaged.currentPage,
  pageSize: this.remindersPaged.pageSize,
  sortOptions: {
    desc: true,    // ✅ 添加 desc
  },
  filter: {},
});
```

### 4. account-store.ts
**位置**: `src/stores/money/account-store.ts:69-76`

```typescript
// fetchAccounts 方法中
this.accounts = filters
  ? await MoneyDb.listAccountsPaged({
      currentPage: 1,
      pageSize: 1000,
      sortOptions: {
        desc: true,    // ✅ 添加 desc
      },
      filter: filters,
    }).then(r => r.rows)
  : await MoneyDb.listAccounts();
```

### 5. CategorySelector.vue ⚠️
**位置**: `src/components/common/CategorySelector.vue:1-3`

**问题**: 使用了 `useCategoryStore()` 但忘记导入

```typescript
// 修复前 ❌
<script setup lang="ts">
import { lowercaseFirstLetter } from '@/utils/common';
// ... 没有导入 useCategoryStore

const categoryStore = useCategoryStore(); // ❌ ReferenceError

// 修复后 ✅
<script setup lang="ts">
import { useCategoryStore } from '@/stores/money'; // ✅ 添加导入
import { lowercaseFirstLetter } from '@/utils/common';

const categoryStore = useCategoryStore(); // ✅ 正常工作
```

**错误信息**:
```
ReferenceError: useCategoryStore is not defined
    at setup (CategorySelector.vue:52:23)
```

---

## 🔍 SortOptions 接口定义

**位置**: `src/schema/common.ts:254-259`

```typescript
export interface SortOptions {
  customOrderBy?: string;  // 可选：完整排序 SQL
  sortBy?: string;         // 可选：排序字段
  sortDir?: SortDirection; // 可选：排序方向
  desc?: boolean;          // 必需：是否降序
}
```

### 重要说明
虽然 TypeScript 接口中 `desc` 定义为可选（`desc?: boolean`），但后端 Rust 代码要求此字段必须存在。

---

## ⚠️ 注意事项

### 为什么会出现这个问题？

1. **重构遗留**: 在将 moneyStore 拆分为模块化 stores 时，复制了旧代码中的空对象
2. **类型不匹配**: TypeScript 定义为可选，但 Rust 后端要求必需
3. **默认值缺失**: 没有提供合理的默认值

### 其他潜在问题

搜索发现还有其他文件使用了 `sortOptions: {}`，但这些是**默认参数定义**，不会导致运行时错误：

**无需修复的位置** (函数默认参数):
- `services/money/money.ts` - 默认参数
- `services/money/accounts.ts` - 默认参数
- `services/money/budgets.ts` - 默认参数
- `services/money/billReminder.ts` - 默认参数
- `services/todo.ts` - 默认参数
- 等等...

这些位置的空对象是作为函数默认参数，调用时会被实际参数替换。

---

## ✅ 验证方法

### 测试步骤
1. 启动应用
2. 打开财务页面
3. 查看预算列表
4. 切换预算状态
5. 检查控制台无错误

### 预期结果
- ✅ 预算列表正常加载
- ✅ 提醒列表正常加载
- ✅ 账户列表正常加载
- ✅ 无 "missing field `desc`" 错误

---

## 🎯 经验教训

### 1. 类型安全的局限性
TypeScript 的可选字段 (`?`) 不能保证运行时正确性，特别是与后端交互时。

### 2. 重构时的检查清单
- [ ] 检查所有 API 调用参数
- [ ] 验证必需字段
- [ ] 测试所有修改的代码路径

### 3. 最佳实践
```typescript
// ❌ 不好：使用空对象
sortOptions: {}

// ✅ 更好：提供默认值
sortOptions: {
  desc: true,
}

// ✅ 最好：使用常量
const DEFAULT_SORT_OPTIONS: SortOptions = {
  desc: true,
  sortDir: SortDirection.Desc,
};

sortOptions: DEFAULT_SORT_OPTIONS
```

---

## 📚 相关文档

- `MIGRATION_COMPLETED.md` - 迁移完成报告
- `CLEANUP_COMPLETED.md` - 清理完成报告
- `src/schema/common.ts` - 接口定义

---

## ✅ 修复完成

**状态**: 已修复  
**影响范围**: 
- Budget、Reminder、Account 的分页查询
- CategorySelector 组件的正常使用

**修复问题**:
1. ✅ 修复 sortOptions 缺少 `desc` 字段（4处）
2. ✅ 修复 CategorySelector 缺少 import（1处）

**测试状态**: 待验证

---

## 📊 修复总结

### 问题1: sortOptions 缺少 desc 字段
- **影响**: 所有分页查询失败
- **修复数量**: 4个文件
- **优先级**: 🔴 高（阻塞性）

### 问题2: 缺少 import 语句
- **影响**: CategorySelector 组件崩溃
- **修复数量**: 1个文件
- **优先级**: 🔴 高（阻塞性）

### 根本原因
重构过程中的疏忽：
1. 复制了旧代码的空对象 `{}`
2. 修改了代码但忘记添加 import

### 经验教训
- ✅ 重构后必须运行测试
- ✅ 修改代码时检查 import
- ✅ 使用 TypeScript strict 模式
- ✅ 添加 ESLint 规则检查未导入的引用

---

*修复时间: 2025-11-11*  
*修复人员: AI Assistant*  
*修复文件: 5个*
