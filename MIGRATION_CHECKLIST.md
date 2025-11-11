# 前端重构迁移检查清单

本文档提供了一个清晰的迁移路径，帮助你逐步将现有代码迁移到新的架构。

---

## 📋 迁移优先级

### ✅ 已完成（无需迁移）

以下模块已经重构完成，无需额外操作：
- [x] `main.ts` - 使用新的 AppBootstrapper
- [x] `App.vue` - 使用 PlatformService
- [x] `stores/index.ts` - 使用 PlatformService

### 🔄 建议迁移（按优先级）

#### 高优先级 - 新功能优先使用

1. **新增的 Money 功能**
   - [ ] 所有新的账户相关功能使用 `useAccountStore`
   - [ ] 所有新的交易相关功能使用 `useTransactionStore`
   - [ ] 所有新的预算相关功能使用 `useBudgetStore`
   - [ ] 所有新的提醒相关功能使用 `useReminderStore`
   - [ ] 所有新的分类相关功能使用 `useCategoryStore`

2. **新增的平台判断**
   - [ ] 所有新代码使用 `PlatformService` 而不是 `detectMobileDevice()`

#### 中优先级 - 逐步迁移现有功能

3. **Account 相关组件迁移**
   - [ ] `src/views/accounts/` 下的所有组件
   - [ ] `src/components/account/` 下的所有组件
   - 替换: `useMoneyStore()` → `useAccountStore()`

4. **Transaction 相关组件迁移**
   - [ ] `src/views/transactions/` 下的所有组件
   - [ ] `src/components/transaction/` 下的所有组件
   - 替换: `useMoneyStore()` → `useTransactionStore()`

5. **Budget 相关组件迁移**
   - [ ] `src/views/budgets/` 下的所有组件
   - [ ] `src/components/budget/` 下的所有组件
   - 替换: `useMoneyStore()` → `useBudgetStore()`

6. **Reminder 相关组件迁移**
   - [ ] `src/views/reminders/` 下的所有组件
   - [ ] `src/components/reminder/` 下的所有组件
   - 替换: `useMoneyStore()` → `useReminderStore()`

#### 低优先级 - 优化性迁移

7. **Category 相关组件迁移**
   - [ ] 所有使用 `moneyStore.categories` 的地方
   - [ ] 所有使用 `moneyStore.subCategorys` 的地方
   - 替换: `useMoneyStore()` → `useCategoryStore()`

8. **平台判断迁移**
   - [ ] 搜索并替换所有 `detectMobileDevice()` 为 `PlatformService.isMobile()`
   - [ ] 搜索并替换所有 `detectTauriDevice()` 为 `PlatformService.isTauri()`

---

## 🔍 迁移步骤详解

### 步骤 1: 迁移 Account 功能

#### 查找需要迁移的文件
```bash
# 在项目中搜索使用 moneyStore 账户功能的地方
grep -r "moneyStore.*account" src/
grep -r "getAllAccounts" src/
grep -r "updateAccounts" src/
```

#### 迁移模板

**Before:**
```typescript
import { useMoneyStore } from '@/stores/moneyStore';

const moneyStore = useMoneyStore();
await moneyStore.getAllAccounts();
const accounts = moneyStore.accounts;
const total = accounts.reduce((sum, a) => sum + parseFloat(a.balance), 0);
```

**After:**
```typescript
import { useAccountStore } from '@/stores/money';

const accountStore = useAccountStore();
await accountStore.fetchAccounts();
const accounts = accountStore.accounts;
const total = accountStore.totalBalance; // 使用 getter
```

### 步骤 2: 迁移 Transaction 功能

#### 查找需要迁移的文件
```bash
grep -r "moneyStore.*transaction" src/
grep -r "updateTransactions" src/
grep -r "createTransaction" src/
```

#### 迁移模板

**Before:**
```typescript
const moneyStore = useMoneyStore();

// 创建交易
await moneyStore.createTransaction(data);
await moneyStore.updateTransactions();

// 创建转账
await moneyStore.transferCreate(transferData);

// 获取交易
const transactions = moneyStore.transactions;
```

**After:**
```typescript
import { useTransactionStore } from '@/stores/money';

const transactionStore = useTransactionStore();

// 创建交易
await transactionStore.createTransaction(data);
// 无需手动调用 updateTransactions，已在内部处理

// 创建转账
await transactionStore.createTransfer(transferData);

// 获取交易
const transactions = transactionStore.transactions;

// 或使用 getter
const incomeTransactions = transactionStore.incomeTransactions;
const expenseTransactions = transactionStore.expenseTransactions;
```

### 步骤 3: 迁移 Budget 功能

**Before:**
```typescript
const moneyStore = useMoneyStore();
await moneyStore.updateBudgets(true);
const budgets = moneyStore.budgetsPaged;
```

**After:**
```typescript
import { useBudgetStore } from '@/stores/money';

const budgetStore = useBudgetStore();
await budgetStore.fetchBudgetsPaged({
  currentPage: 1,
  pageSize: 10,
  sortOptions: {},
  filter: {},
});
const budgets = budgetStore.budgetsPaged;
```

### 步骤 4: 迁移 Reminder 功能

**Before:**
```typescript
const moneyStore = useMoneyStore();
await moneyStore.updateReminders(true);
const reminders = moneyStore.remindersPaged;
```

**After:**
```typescript
import { useReminderStore } from '@/stores/money';

const reminderStore = useReminderStore();
await reminderStore.fetchRemindersPaged(query);
const reminders = reminderStore.remindersPaged;

// 使用新的 getter
const upcomingReminders = reminderStore.upcomingReminders;
const activeReminders = reminderStore.activeReminders;
```

### 步骤 5: 迁移 Category 功能

**Before:**
```typescript
const moneyStore = useMoneyStore();
await moneyStore.updateCategories();
await moneyStore.updateSubCategories();
const categories = moneyStore.categories;
const subCategories = moneyStore.subCategorys;
```

**After:**
```typescript
import { useCategoryStore } from '@/stores/money';

const categoryStore = useCategoryStore();
await categoryStore.fetchCategories();
await categoryStore.fetchSubCategories();
const categories = categoryStore.categories;
const subCategories = categoryStore.subCategories;

// 使用缓存功能
await categoryStore.fetchCategories(false); // 使用缓存
await categoryStore.fetchCategories(true);  // 强制刷新
```

### 步骤 6: 迁移平台判断

**Before:**
```typescript
import { detectMobileDevice } from '@/utils/platform';

const isMobile = detectMobileDevice();
if (isMobile) {
  // 移动端逻辑
  await new Promise(resolve => setTimeout(resolve, 50));
} else {
  // 桌面端逻辑
  await new Promise(resolve => setTimeout(resolve, 150));
}
```

**After:**
```typescript
import { PlatformService } from '@/services/platform-service';

if (PlatformService.isMobile()) {
  // 移动端逻辑
}

// 或使用内置工具
await PlatformService.delay(50, 150);
```

---

## 🧪 迁移验证

### 验证清单

迁移每个模块后，请确认以下几点：

- [ ] **功能正常**: 所有功能按预期工作
- [ ] **无控制台错误**: 没有新的错误或警告
- [ ] **类型安全**: TypeScript 没有类型错误
- [ ] **性能稳定**: 没有明显的性能下降
- [ ] **加载状态**: loading 和 error 状态正确显示

### 测试命令

```bash
# 类型检查
npm run type-check

# 单元测试（如果有）
npm run test:unit

# 构建测试
npm run build

# 本地运行测试
npm run dev
```

---

## 📊 迁移进度跟踪

### Store 迁移统计

| Store | 预计使用位置 | 已迁移 | 待迁移 | 进度 |
|-------|------------|--------|--------|------|
| AccountStore | ~15 | 0 | 15 | 0% |
| TransactionStore | ~20 | 0 | 20 | 0% |
| BudgetStore | ~8 | 0 | 8 | 0% |
| ReminderStore | ~5 | 0 | 5 | 0% |
| CategoryStore | ~10 | 0 | 10 | 0% |
| **总计** | **~58** | **0** | **58** | **0%** |

### 平台判断迁移

| 类型 | 预计位置 | 已迁移 | 待迁移 | 进度 |
|------|---------|--------|--------|------|
| detectMobileDevice | ~10 | 3 | 7 | 30% |
| detectTauriDevice | ~5 | 0 | 5 | 0% |
| **总计** | **~15** | **3** | **12** | **20%** |

---

## ⚠️ 常见问题

### Q1: 迁移后代码不工作怎么办？

**A:** 检查以下几点：
1. 确认导入路径正确: `@/stores/money` 而不是 `@/stores/moneyStore`
2. 确认方法名称: 新 store 的方法名可能有所不同
3. 查看控制台错误信息
4. 参考本文档的迁移模板

### Q2: 是否需要立即迁移所有代码？

**A:** 不需要！
- 新功能使用新架构
- 现有功能保持不变，逐步迁移
- 旧的 `useMoneyStore` 仍然可用

### Q3: 迁移后性能会提升吗？

**A:** 会的！
- 减少 reactive 开销
- 按需加载 store
- 更少的状态监听

### Q4: 如何处理多个 store 之间的依赖？

**A:** 
```typescript
// 在组件中组合使用
import { useAccountStore, useTransactionStore } from '@/stores/money';

const accountStore = useAccountStore();
const transactionStore = useTransactionStore();

// 刷新账户后更新交易
await accountStore.fetchAccounts();
await transactionStore.fetchTransactions();
```

### Q5: 错误处理有什么变化？

**A:**
```typescript
import { useTransactionStore, handleMoneyStoreError } from '@/stores/money';

const transactionStore = useTransactionStore();

try {
  await transactionStore.createTransaction(data);
} catch (err) {
  const appError = handleMoneyStoreError(err, '创建交易失败');
  // 处理错误...
}
```

---

## 🎯 迁移建议

### 推荐迁移顺序

1. **先迁移独立模块**: 从最独立的功能开始（如 Category）
2. **再迁移核心模块**: 逐步迁移 Account、Transaction 等核心功能
3. **最后迁移复杂模块**: 处理有多个依赖的复杂场景

### 迁移策略

- **渐进式迁移**: 一次迁移一个功能模块
- **充分测试**: 每次迁移后进行充分测试
- **保留回退**: 遇到问题可以快速回退
- **团队协作**: 通知团队成员迁移进度

---

## 📞 支持

遇到问题？
1. 查看 `FRONTEND_REFACTORING_SUMMARY.md` 了解架构详情
2. 查看 `FRONTEND_ANALYSIS.md` 了解设计决策
3. 参考新 store 的源代码和注释
4. 在团队中讨论

---

**祝迁移顺利！** 🚀
