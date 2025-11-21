# 全局 Store 使用指南

## 📚 概述

本项目已实现统一的全局 Store 管理系统，用于管理 Currency、Category、SubCategory、Account 等核心数据。所有 Store 通过事件系统实现自动同步，确保数据一致性。

## 🎯 核心特性

### 1. 统一数据源
- 所有数据通过 Store 集中管理
- 避免组件内部维护重复状态
- 提供统一的 API 接口

### 2. 自动同步
- 使用事件系统实现跨 Store 通信
- 交易操作自动触发账户余额更新
- 转账操作同时更新两个账户

### 3. 缓存策略
- Category Store: 5分钟缓存
- Currency Store: 30分钟缓存
- 支持强制刷新

### 4. 错误处理
- 统一的错误处理机制
- 友好的错误提示
- 不影响主流程的静默更新

## 📦 可用的 Store

### 1. Account Store (`useAccountStore`)

管理账户的 CRUD 操作和余额更新。

```typescript
import { useAccountStore } from '@/stores/money';

const accountStore = useAccountStore();

// 获取账户列表
await accountStore.fetchAccounts();

// 访问账户数据
const accounts = accountStore.accounts;
const activeAccounts = accountStore.activeAccounts;
const totalBalance = accountStore.totalBalance;

// 创建账户
const newAccount = await accountStore.createAccount({
  name: '招商银行',
  accountType: 'BankCard',
  balance: '10000',
  currency: 'CNY',
});

// 更新账户
await accountStore.updateAccount(serialNum, {
  name: '招商银行储蓄卡',
});

// 删除账户
await accountStore.deleteAccount(serialNum);

// 手动刷新账户（通常不需要，事件系统会自动处理）
await accountStore.refreshAccount(serialNum);
```

### 2. Category Store (`useCategoryStore`)

管理分类和子分类数据。

```typescript
import { useCategoryStore } from '@/stores/money';

const categoryStore = useCategoryStore();

// 获取分类列表（带缓存）
await categoryStore.fetchCategories();
await categoryStore.fetchSubCategories();

// 访问分类数据
const categories = categoryStore.categories;
const subCategories = categoryStore.subCategories;

// 获取特定分类的子分类
const foodSubCategories = categoryStore.getSubCategoriesByCategory('餐饮');

// UI 格式的数据（用于选择器）
const uiCategories = categoryStore.uiCategories;
const uiSubCategories = categoryStore.uiSubCategories;

// 强制刷新缓存
await categoryStore.fetchCategories(true);
```

### 3. Currency Store (`useCurrencyStore`)

管理货币数据。

```typescript
import { useCurrencyStore } from '@/stores/money';

const currencyStore = useCurrencyStore();

// 获取货币列表（带缓存）
await currencyStore.fetchCurrencies();

// 访问货币数据
const currencies = currencyStore.currencies;
const activeCurrencies = currencyStore.activeCurrencies;
const defaultCurrency = currencyStore.primaryCurrency;

// 根据代码获取货币
const cny = currencyStore.getCurrencyByCode('CNY');

// 创建货币
const newCurrency = await currencyStore.createCurrency({
  code: 'USD',
  name: '美元',
  symbol: '$',
  isActive: true,
});

// 设置默认货币
await currencyStore.setDefaultCurrency('CNY');
```

### 4. Transaction Store (`useTransactionStore`)

管理交易数据，自动触发账户更新事件。

```typescript
import { useTransactionStore } from '@/stores/money';

const transactionStore = useTransactionStore();

// 创建交易（自动更新关联账户）
const transaction = await transactionStore.createTransaction({
  transactionType: 'Expense',
  accountSerialNum: 'acc_xxx',
  amount: 100,
  category: '餐饮',
  date: new Date().toISOString(),
});

// 创建转账（自动更新两个账户）
const [fromTx, toTx] = await transactionStore.createTransfer({
  fromAccountSerialNum: 'acc_1',
  toAccountSerialNum: 'acc_2',
  amount: 500,
  date: new Date().toISOString(),
});

// 更新交易（自动更新账户）
await transactionStore.updateTransaction(serialNum, {
  amount: 150,
});

// 删除交易（自动更新账户）
await transactionStore.deleteTransaction(serialNum);
```

## 🔄 事件系统

### 自动同步机制

当交易发生变化时，相关账户会自动更新：

```typescript
// 1. 创建交易
await transactionStore.createTransaction(data);
// ↓ 自动触发
// → 'transaction:created' 事件
// → Account Store 监听到事件
// → 自动刷新关联账户余额

// 2. 创建转账
await transactionStore.createTransfer(data);
// ↓ 自动触发
// → 'transfer:created' 事件
// → Account Store 监听到事件
// → 自动刷新两个账户余额
```

### 手动发送事件（高级用法）

```typescript
import { emitStoreEvent } from '@/stores/money';

// 手动触发账户更新
emitStoreEvent('account:updated', {
  serialNum: 'acc_xxx',
});
```

### 监听事件（高级用法）

```typescript
import { onStoreEvent } from '@/stores/money';

// 监听交易创建事件
const cleanup = onStoreEvent('transaction:created', async ({ accountSerialNum }) => {
  console.log('Transaction created for account:', accountSerialNum);
  // 执行自定义逻辑
});

// 清理监听器
cleanup();
```

## 🎨 组件中的使用模式

### 基础用法

```vue
<script setup lang="ts">
import { useAccountStore, useCategoryStore, useCurrencyStore } from '@/stores/money';

// 1. 初始化 Store
const accountStore = useAccountStore();
const categoryStore = useCategoryStore();
const currencyStore = useCurrencyStore();

// 2. 在组件挂载时加载数据
onMounted(async () => {
  await Promise.all([
    accountStore.fetchAccounts(),
    categoryStore.fetchCategories(),
    categoryStore.fetchSubCategories(),
    currencyStore.fetchCurrencies(),
  ]);
});

// 3. 使用计算属性访问数据
const accounts = computed(() => accountStore.accounts);
const categories = computed(() => categoryStore.categories);
const currencies = computed(() => currencyStore.currencies);

// 4. 使用 loading 状态
const isLoading = computed(() => 
  accountStore.loading || 
  categoryStore.loading || 
  currencyStore.loading
);
</script>

<template>
  <div v-if="isLoading">加载中...</div>
  <div v-else>
    <!-- 使用数据 -->
    <select v-model="selectedAccount">
      <option v-for="account in accounts" :key="account.serialNum" :value="account.serialNum">
        {{ account.name }} - {{ account.balance }}
      </option>
    </select>
  </div>
</template>
```

### 交易表单示例

```vue
<script setup lang="ts">
import { useAccountStore, useTransactionStore } from '@/stores/money';

const accountStore = useAccountStore();
const transactionStore = useTransactionStore();

const form = reactive({
  accountSerialNum: '',
  amount: 0,
  category: '',
  date: new Date().toISOString(),
});

// 提交表单
async function handleSubmit() {
  try {
    // 创建交易（自动更新账户余额）
    await transactionStore.createTransaction({
      transactionType: 'Expense',
      ...form,
    });
    
    // 不需要手动刷新账户，事件系统会自动处理
    toast.success('交易创建成功');
  } catch (error) {
    toast.error('创建失败');
  }
}

// 账户列表会自动更新，无需手动刷新
const accounts = computed(() => accountStore.accounts);
</script>
```

## ⚠️ 注意事项

### 1. 避免重复加载

Store 已实现缓存机制，避免在多个组件中重复调用：

```typescript
// ❌ 不推荐：每次都强制刷新
await categoryStore.fetchCategories(true);

// ✅ 推荐：使用缓存
await categoryStore.fetchCategories(); // 5分钟内不会重复请求
```

### 2. 不要在组件中维护重复状态

```typescript
// ❌ 不推荐
const accounts = ref([]);
onMounted(async () => {
  accounts.value = await MoneyDb.listAccounts();
});

// ✅ 推荐
const accountStore = useAccountStore();
onMounted(async () => {
  await accountStore.fetchAccounts();
});
const accounts = computed(() => accountStore.accounts);
```

### 3. 信任事件系统

交易操作后不需要手动刷新账户：

```typescript
// ❌ 不推荐
await transactionStore.createTransaction(data);
await accountStore.refreshAccount(accountSerialNum); // 多余的调用

// ✅ 推荐
await transactionStore.createTransaction(data);
// 事件系统会自动刷新账户
```

### 4. 错误处理

Store 已处理错误，组件只需显示：

```typescript
try {
  await accountStore.createAccount(data);
} catch (error) {
  // Store 已经设置了 error 状态
  toast.error(accountStore.error || '操作失败');
}
```

## 🔧 调试技巧

### 1. 查看事件流

在浏览器控制台查看事件日志：

```typescript
// 在 store-events.ts 中已添加错误日志
// 事件触发时会在控制台显示
```

### 2. 检查 Store 状态

使用 Vue DevTools 查看 Store 状态：
- Pinia 标签页
- 查看各个 Store 的 state
- 查看 actions 调用历史

### 3. 手动触发刷新

如果自动同步出现问题，可以手动刷新：

```typescript
// 刷新单个账户
await accountStore.refreshAccount(serialNum);

// 刷新多个账户
await accountStore.refreshAccounts([id1, id2]);
```

## 📝 最佳实践总结

1. ✅ 统一使用 Store 管理数据
2. ✅ 利用缓存机制减少请求
3. ✅ 信任事件系统的自动同步
4. ✅ 使用计算属性访问 Store 数据
5. ✅ 在 onMounted 中加载初始数据
6. ❌ 不要在组件中维护重复状态
7. ❌ 不要手动刷新已自动同步的数据
8. ❌ 不要频繁调用强制刷新

## 🚀 迁移指南

如果你的组件还在使用旧的方式，按以下步骤迁移：

### 步骤 1: 移除直接的 API 调用

```typescript
// 旧代码
import { MoneyDb } from '@/services/money/money';
const accounts = ref([]);
accounts.value = await MoneyDb.listAccounts();

// 新代码
import { useAccountStore } from '@/stores/money';
const accountStore = useAccountStore();
await accountStore.fetchAccounts();
const accounts = computed(() => accountStore.accounts);
```

### 步骤 2: 移除手动刷新逻辑

```typescript
// 旧代码
await transactionStore.createTransaction(data);
await loadAccounts(); // 手动刷新

// 新代码
await transactionStore.createTransaction(data);
// 自动刷新，无需手动调用 ✅

// 同样适用于其他 Store
await currencyStore.updateCurrency(code, data);
// 自动刷新，无需手动调用 ✅
```

**已实现自动刷新的 Store**：
- ✅ **Transaction Store**：创建/更新/删除交易 → 自动刷新账户
- ✅ **Currency Store**：创建/更新/删除货币 → 自动发送事件
- ⚠️ **Category Store**：仅读取功能，无 CRUD 操作

### 步骤 3: 使用统一的错误处理

```typescript
// 旧代码
try {
  await MoneyDb.createAccount(data);
} catch (error: any) {
  toast.error(error.message);
}

// 新代码
try {
  await accountStore.createAccount(data);
} catch (error) {
  toast.error(accountStore.error || '操作失败');
}
```

## 📚 相关文档

- [Store 重构方案](./GLOBAL_STORE_REFACTOR_PLAN.md)
- [事件系统设计](./STORE_EVENTS_DESIGN.md)
- [API 文档](../api/README.md)
