# TransactionModal 账本和成员关联集成完成

## ✅ 已完成的修改

### 1. **TransactionModal.vue 组件增强**

#### 新增功能：
- ✅ 导入 `useTransactionLedgerLink` composable
- ✅ 初始化账本和成员列表加载
- ✅ 编辑模式下加载现有关联
- ✅ 智能推荐：根据账户自动推荐账本和成员
- ✅ UI组件：账本选择器和成员选择器
- ✅ 完整的样式支持

#### 修改的 emit 事件：
```typescript
// 之前
emit('save', transaction);
emit('update', serialNum, transaction);

// 现在
emit('save', transaction, ledgerIds, memberIds);
emit('update', serialNum, transaction, ledgerIds, memberIds);
```

### 2. **UI 功能**

#### 账本选择器：
- 显示已选择的账本（标签形式）
- 点击"选择账本"按钮展开下拉列表
- 支持多选（复选框）
- 显示账本类型标签
- 可以移除已选择的账本

#### 成员选择器：
- 只在选择了账本后才显示
- 显示已选择的成员（标签形式）
- 点击"选择成员"按钮展开下拉列表
- 支持多选（复选框）
- 显示成员角色标签
- 可以移除已选择的成员

#### 智能推荐：
- 当用户选择账户时，自动推荐相关账本
- 根据账本自动推荐相关成员
- 只在创建模式下自动推荐（编辑模式保留原有选择）

## 📋 父组件需要的修改

### MoneyView.vue 或其他使用 TransactionModal 的组件

需要修改事件处理函数以接收新的参数：

```typescript
// 之前
async function handleSaveTransaction(transaction: TransactionCreate) {
  const result = await MoneyDb.createTransaction(transaction);
  // ...
}

// 现在
async function handleSaveTransaction(
  transaction: TransactionCreate,
  ledgerIds: string[],
  memberIds: string[]
) {
  // 1. 创建交易
  const result = await MoneyDb.createTransaction(transaction);
  
  // 2. 创建账本关联
  if (ledgerIds.length > 0) {
    const associations = ledgerIds.map(ledgerId => ({
      familyLedgerSerialNum: ledgerId,
      transactionSerialNum: result.serialNum,
    }));
    await MoneyDb.batchCreateFamilyLedgerTransactions(associations);
  }
  
  // 3. 更新成员关联（已在 transaction.splitMembers 中）
  // splitMembers 会在创建交易时自动保存
  
  // 4. 刷新数据
  await loadData();
}

// 更新交易
async function handleUpdateTransaction(
  serialNum: string,
  transaction: TransactionUpdate,
  ledgerIds: string[],
  memberIds: string[]
) {
  // 1. 更新交易
  await MoneyDb.updateTransaction(serialNum, transaction);
  
  // 2. 更新账本关联
  await MoneyDb.updateTransactionLedgers(serialNum, ledgerIds);
  
  // 3. 刷新数据
  await loadData();
}
```

### 完整示例

```vue
<template>
  <TransactionModal
    v-if="showTransactionModal"
    :type="transactionType"
    :transaction="selectedTransaction"
    :accounts="accounts"
    :readonly="isViewMode"
    @close="closeTransactionModal"
    @save="handleSaveTransaction"
    @update="handleUpdateTransaction"
    @save-transfer="handleSaveTransfer"
    @update-transfer="handleUpdateTransfer"
  />
</template>

<script setup lang="ts">
import { MoneyDb } from '@/services/money/money';
import type { TransactionCreate, TransactionUpdate } from '@/schema/money';

async function handleSaveTransaction(
  transaction: TransactionCreate,
  ledgerIds: string[],
  memberIds: string[]
) {
  try {
    // 创建交易
    const result = await MoneyDb.createTransaction(transaction);
    
    // 创建账本关联
    if (ledgerIds.length > 0) {
      const associations = ledgerIds.map(ledgerId => ({
        familyLedgerSerialNum: ledgerId,
        transactionSerialNum: result.serialNum,
      }));
      await MoneyDb.batchCreateFamilyLedgerTransactions(associations);
    }
    
    toast.success('交易创建成功');
    closeTransactionModal();
    await loadData();
  } catch (error) {
    console.error('Failed to create transaction:', error);
    toast.error('交易创建失败');
  }
}

async function handleUpdateTransaction(
  serialNum: string,
  transaction: TransactionUpdate,
  ledgerIds: string[],
  memberIds: string[]
) {
  try {
    // 更新交易
    await MoneyDb.updateTransaction(serialNum, transaction);
    
    // 更新账本关联
    await MoneyDb.updateTransactionLedgers(serialNum, ledgerIds);
    
    toast.success('交易更新成功');
    closeTransactionModal();
    await loadData();
  } catch (error) {
    console.error('Failed to update transaction:', error);
    toast.error('交易更新失败');
  }
}
</script>
```

## 🎨 UI 预览

### 创建交易时：
```
┌─────────────────────────────────────┐
│ 创建交易                            │
├─────────────────────────────────────┤
│ 交易类型: [支出 ▼]                  │
│ 金额: [100.00]                      │
│ 账户: [工资卡 ▼]                    │
│ 分类: [餐饮 ▼]                      │
│                                     │
│ 关联账本 (可选)                     │
│ ┌─────────────────────────────────┐ │
│ │ [家庭账本 ×] [项目账本 ×]       │ │
│ │ [+ 选择账本]                    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 分摊成员 (可选)                     │
│ ┌─────────────────────────────────┐ │
│ │ [爸爸 ×] [妈妈 ×]               │ │
│ │ [+ 选择成员]                    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [取消]                    [保存] │
└─────────────────────────────────────┘
```

### 选择账本下拉：
```
┌─────────────────────────────────────┐
│ 选择账本                        [×] │
├─────────────────────────────────────┤
│ ☐ 家庭账本              [FAMILY]    │
│ ☑ 项目账本              [PROJECT]   │
│ ☐ 旅游账本              [SHARED]    │
└─────────────────────────────────────┘
```

## 🔄 数据流程

```
用户填写交易信息
  ↓
选择账户 → 自动推荐账本和成员
  ↓
用户确认/修改选择
  ↓
点击保存
  ↓
TransactionModal emit('save', transaction, ledgerIds, memberIds)
  ↓
父组件 handleSaveTransaction()
  ├─ 创建交易记录
  ├─ 批量创建账本关联
  └─ 成员信息已在 transaction.splitMembers 中
  ↓
完成 ✅
```

## 🎯 关键特性

1. **智能推荐**: 根据账户自动推荐相关账本和成员
2. **多选支持**: 一笔交易可以关联多个账本和成员
3. **视觉反馈**: 已选项以标签形式显示，可快速移除
4. **条件显示**: 成员选择器只在选择了账本后才显示
5. **编辑支持**: 编辑模式下自动加载现有关联
6. **只读模式**: 只读模式下隐藏选择器

## 📝 注意事项

1. **splitMembers 字段**: 成员信息存储在交易的 `splitMembers` 字段中，类型为 `FamilyMember[]`
2. **账本关联**: 通过 `family_ledger_transaction` 中间表存储
3. **级联删除**: 删除账本或交易时会自动删除关联
4. **性能优化**: 账本和成员列表在组件挂载时一次性加载

## 🚀 下一步

1. ✅ 修改父组件的事件处理函数
2. ✅ 测试创建交易并关联账本和成员
3. ✅ 测试编辑交易时修改关联
4. ✅ 测试智能推荐功能
5. ✅ 添加错误处理和用户提示

## 📚 相关文档

- [TRANSACTION_LEDGER_LINK_GUIDE.md](./TRANSACTION_LEDGER_LINK_GUIDE.md) - 使用指南
- [FAMILY_LEDGER_TRANSACTION_INTEGRATION.md](./FAMILY_LEDGER_TRANSACTION_INTEGRATION.md) - 功能文档
- [useTransactionLedgerLink.ts](./src/features/money/composables/useTransactionLedgerLink.ts) - Composable 源码
