# 交易关联到家庭记账本和成员使用指南

## 📋 概述

本指南说明如何在创建/编辑交易时关联到家庭记账本和成员。

## 🎯 核心功能

### 1. 创建交易时关联账本和成员

```typescript
import { useTransactionLedgerLink } from '@/features/money/composables/useTransactionLedgerLink';

const {
  availableLedgers,
  selectedLedgers,
  availableMembers,
  selectedMembers,
  loadAvailableLedgers,
  loadAvailableMembers,
  createTransactionWithLinks,
  getSmartSuggestions,
} = useTransactionLedgerLink();

// 1. 加载可用的账本和成员
await loadAvailableLedgers();
await loadAvailableMembers();

// 2. 创建交易并关联
const transaction = await createTransactionWithLinks(
  transactionData,      // 交易数据
  selectedLedgers.value, // 选中的账本ID数组
  selectedMembers.value  // 选中的成员ID数组
);
```

### 2. 智能推荐账本和成员

```typescript
// 根据账户自动推荐相关的账本和成员
const { suggestedLedgers, suggestedMembers } = await getSmartSuggestions(
  accountSerialNum
);

// 自动选中推荐的账本
selectedLedgers.value = suggestedLedgers.map(l => l.serialNum);

// 自动选中推荐的成员
selectedMembers.value = suggestedMembers.map(m => m.serialNum);
```

### 3. 更新交易的关联

```typescript
// 更新现有交易的账本和成员关联
await updateTransactionLinks(
  transactionSerialNum,
  newLedgerIds,
  newMemberIds
);
```

### 4. 查询交易的当前关联

```typescript
// 获取交易当前关联的账本和成员
const { ledgers, members } = await getTransactionLinks(transactionSerialNum);
```

## 🎨 UI 组件示例

### 完整的交易表单组件

```vue
<script setup lang="ts">
import { useTransactionLedgerLink } from '@/features/money/composables/useTransactionLedgerLink';
import { MoneyDb } from '@/services/money/money';
import type { TransactionCreate } from '@/schema/money';

const emit = defineEmits(['success', 'cancel']);

// 使用 composable
const {
  availableLedgers,
  selectedLedgers,
  availableMembers,
  selectedMembers,
  loading,
  loadAvailableLedgers,
  loadAvailableMembers,
  createTransactionWithLinks,
  getSmartSuggestions,
} = useTransactionLedgerLink();

// 交易表单数据
const form = reactive<TransactionCreate>({
  transactionType: 'EXPENSE',
  date: new Date().toISOString(),
  amount: 0,
  currency: 'CNY',
  description: '',
  notes: '',
  accountSerialNum: '',
  category: '',
  subCategory: '',
  tags: [],
  paymentMethod: 'CASH',
  actualPayerAccount: 'PERSONAL',
  isDeleted: false,
});

// 加载数据
onMounted(async () => {
  await Promise.all([
    loadAvailableLedgers(),
    loadAvailableMembers(),
  ]);
});

// 当账户改变时，智能推荐账本和成员
watch(() => form.accountSerialNum, async (accountId) => {
  if (accountId) {
    const { suggestedLedgers, suggestedMembers } = await getSmartSuggestions(accountId);
    
    // 自动选中推荐的账本（如果用户还没有手动选择）
    if (selectedLedgers.value.length === 0) {
      selectedLedgers.value = suggestedLedgers.map(l => l.serialNum);
    }
    
    // 自动选中推荐的成员
    if (selectedMembers.value.length === 0) {
      selectedMembers.value = suggestedMembers.map(m => m.serialNum);
    }
  }
});

// 保存交易
async function saveTransaction() {
  try {
    const transaction = await createTransactionWithLinks(
      form,
      selectedLedgers.value,
      selectedMembers.value
    );
    
    emit('success', transaction);
  } catch (error) {
    console.error('Failed to create transaction:', error);
  }
}
</script>

<template>
  <div class="transaction-form">
    <h2>创建交易</h2>
    
    <!-- 基本交易信息 -->
    <div class="form-section">
      <h3>交易信息</h3>
      
      <div class="form-field">
        <label>交易类型</label>
        <select v-model="form.transactionType">
          <option value="EXPENSE">支出</option>
          <option value="INCOME">收入</option>
          <option value="TRANSFER">转账</option>
        </select>
      </div>
      
      <div class="form-field">
        <label>金额</label>
        <input v-model.number="form.amount" type="number" step="0.01" />
      </div>
      
      <div class="form-field">
        <label>描述</label>
        <input v-model="form.description" type="text" />
      </div>
      
      <div class="form-field">
        <label>账户</label>
        <select v-model="form.accountSerialNum">
          <option value="">请选择账户</option>
          <!-- 账户选项 -->
        </select>
      </div>
    </div>
    
    <!-- 账本关联 -->
    <div class="form-section">
      <h3>关联账本</h3>
      <p class="hint">选择此交易属于哪些家庭账本</p>
      
      <div class="ledger-selector">
        <div
          v-for="ledger in availableLedgers"
          :key="ledger.serialNum"
          class="ledger-option"
        >
          <label>
            <input
              v-model="selectedLedgers"
              type="checkbox"
              :value="ledger.serialNum"
            >
            <span class="ledger-name">{{ ledger.name }}</span>
            <span class="ledger-type">{{ ledger.ledgerType }}</span>
          </label>
        </div>
      </div>
      
      <div v-if="selectedLedgers.length === 0" class="warning">
        <LucideAlertCircle />
        <span>未选择账本，此交易将不会出现在任何家庭账本中</span>
      </div>
    </div>
    
    <!-- 成员关联 -->
    <div v-if="selectedLedgers.length > 0" class="form-section">
      <h3>分摊成员</h3>
      <p class="hint">选择参与此交易的成员（用于费用分摊）</p>
      
      <div class="member-selector">
        <div
          v-for="member in availableMembers"
          :key="member.serialNum"
          class="member-option"
        >
          <label>
            <input
              v-model="selectedMembers"
              type="checkbox"
              :value="member.serialNum"
            >
            <span class="member-name">{{ member.name }}</span>
            <span class="member-role">{{ member.role }}</span>
          </label>
        </div>
      </div>
      
      <div v-if="selectedMembers.length > 1" class="info">
        <LucideInfo />
        <span>已选择 {{ selectedMembers.length }} 位成员，可在账本中进行费用分摊</span>
      </div>
    </div>
    
    <!-- 操作按钮 -->
    <div class="form-actions">
      <button class="btn-cancel" @click="emit('cancel')">
        取消
      </button>
      <button
        class="btn-save"
        :disabled="loading"
        @click="saveTransaction"
      >
        {{ loading ? '保存中...' : '保存' }}
      </button>
    </div>
  </div>
</template>

<style scoped>
.transaction-form {
  max-width: 600px;
  margin: 0 auto;
  padding: 2rem;
}

.form-section {
  margin-bottom: 2rem;
  padding: 1.5rem;
  background: var(--component-bg-primary);
  border-radius: var(--border-radius-md);
}

.form-section h3 {
  margin: 0 0 0.5rem 0;
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--text-primary);
}

.hint {
  font-size: 0.875rem;
  color: var(--text-secondary);
  margin: 0 0 1rem 0;
}

.form-field {
  margin-bottom: 1rem;
}

.form-field label {
  display: block;
  margin-bottom: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--text-primary);
}

.form-field input,
.form-field select {
  width: 100%;
  padding: 0.5rem;
  border: 1px solid var(--border-color);
  border-radius: var(--border-radius-sm);
  font-size: 1rem;
}

.ledger-selector,
.member-selector {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.ledger-option,
.member-option {
  padding: 0.75rem;
  border: 1px solid var(--border-color);
  border-radius: var(--border-radius-sm);
  transition: all 0.2s;
}

.ledger-option:hover,
.member-option:hover {
  border-color: var(--primary-color);
  background: var(--component-bg-secondary);
}

.ledger-option label,
.member-option label {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
}

.ledger-name,
.member-name {
  flex: 1;
  font-weight: 500;
  color: var(--text-primary);
}

.ledger-type,
.member-role {
  font-size: 0.75rem;
  padding: 0.25rem 0.5rem;
  background: var(--component-bg-secondary);
  border-radius: var(--border-radius-sm);
  color: var(--text-secondary);
}

.warning,
.info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  border-radius: var(--border-radius-sm);
  font-size: 0.875rem;
  margin-top: 1rem;
}

.warning {
  background: var(--warning-bg);
  color: var(--warning-color);
}

.info {
  background: var(--info-bg);
  color: var(--info-color);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  margin-top: 2rem;
}

.btn-cancel,
.btn-save {
  padding: 0.75rem 1.5rem;
  border-radius: var(--border-radius-sm);
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-cancel {
  background: transparent;
  border: 1px solid var(--border-color);
  color: var(--text-secondary);
}

.btn-cancel:hover {
  background: var(--component-bg-secondary);
}

.btn-save {
  background: var(--primary-color);
  border: none;
  color: white;
}

.btn-save:hover:not(:disabled) {
  background: var(--primary-hover);
}

.btn-save:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}
</style>
```

## 📊 数据流程

### 创建交易的完整流程

```
1. 用户填写交易基本信息
   ↓
2. 选择账户 → 自动推荐相关账本和成员
   ↓
3. 用户选择/确认账本（可多选）
   ↓
4. 用户选择分摊成员（可多选）
   ↓
5. 点击保存
   ↓
6. createTransactionWithLinks()
   ├─ 创建交易记录
   ├─ 批量创建账本关联
   └─ 更新交易的成员字段
   ↓
7. 完成 ✅
```

## 🎯 业务场景示例

### 场景1: 家庭共同消费

```typescript
// 超市购物 ¥500
const transaction = await createTransactionWithLinks(
  {
    transactionType: 'EXPENSE',
    amount: 500,
    description: '超市购物',
    accountSerialNum: '家庭账户ID',
    category: '日常消费',
  },
  ['家庭账本ID'],           // 关联到家庭账本
  ['爸爸ID', '妈妈ID']      // 两人分摊
);
```

### 场景2: 个人消费记录到多个账本

```typescript
// 出差餐饮 ¥200
const transaction = await createTransactionWithLinks(
  {
    transactionType: 'EXPENSE',
    amount: 200,
    description: '出差午餐',
    accountSerialNum: '个人账户ID',
    category: '餐饮',
  },
  ['家庭账本ID', '项目账本ID'],  // 同时记录到两个账本
  ['我的ID']                     // 个人消费
);
```

### 场景3: 收入分配

```typescript
// 工资收入 ¥10000
const transaction = await createTransactionWithLinks(
  {
    transactionType: 'INCOME',
    amount: 10000,
    description: '月工资',
    accountSerialNum: '工资卡ID',
    category: '工资',
  },
  ['家庭账本ID'],           // 记录到家庭账本
  ['爸爸ID']                // 收入归属
);
```

## 🔧 高级功能

### 1. 批量导入交易并关联

```typescript
const transactions = [
  { /* 交易1 */ },
  { /* 交易2 */ },
  { /* 交易3 */ },
];

for (const txData of transactions) {
  await createTransactionWithLinks(
    txData,
    ['家庭账本ID'],
    ['成员ID']
  );
}
```

### 2. 根据规则自动关联

```typescript
// 根据交易分类自动选择账本
function getDefaultLedgersByCategory(category: string): string[] {
  const rules = {
    '餐饮': ['家庭账本ID'],
    '交通': ['家庭账本ID', '通勤账本ID'],
    '娱乐': ['个人账本ID'],
  };
  return rules[category] || [];
}

// 使用规则
const ledgerIds = getDefaultLedgersByCategory(form.category);
await createTransactionWithLinks(form, ledgerIds, memberIds);
```

### 3. 成员权重分摊

```typescript
// 在创建交易后，可以进一步创建分摊记录
// 详见 split_records 表的使用
```

## 📝 注意事项

1. **账本选择**: 
   - 可以不选择账本，交易仍会创建
   - 未关联账本的交易不会出现在任何家庭账本中
   - 可以随时修改交易的账本关联

2. **成员选择**:
   - 成员选择是可选的
   - 只有关联了账本才需要选择成员
   - 成员信息存储在交易的 `splitMembers` 字段

3. **性能优化**:
   - 账本和成员列表会被缓存
   - 使用智能推荐减少用户操作
   - 批量操作使用批量API

4. **数据一致性**:
   - 删除账本时会级联删除关联
   - 删除成员时需要更新相关交易
   - 使用事务保证数据一致性

## 🚀 下一步

1. 在现有的 `TransactionModal.vue` 中集成账本和成员选择功能
2. 添加快捷选择按钮（如"全选"、"清空"）
3. 实现账本和成员的搜索过滤
4. 添加最近使用的账本和成员快捷选择
5. 支持拖拽排序成员优先级

## 📚 相关文档

- [FAMILY_LEDGER_TRANSACTION_INTEGRATION.md](./FAMILY_LEDGER_TRANSACTION_INTEGRATION.md) - 账本交易关联功能文档
- [家庭账本数据库设计](./FAMILY_LEDGER_PLAN.md) - 数据库结构说明
