# 家庭账本与交易记录关联功能完善文档

## 📋 概述

本文档记录了交易记录与家庭账本关联功能的完善过程，包括前端服务层增强、UI组件创建和集成指南。

## ✅ 已完成功能

### 1. 前端服务层增强 (`src/services/money/family.ts`)

#### 新增方法：

```typescript
// FamilyLedgerTransactionMapper 类新增方法：

// 根据账本ID查询所有关联的交易
async listByLedger(ledgerSerialNum: string): Promise<FamilyLedgerTransaction[]>

// 根据交易ID查询所有关联的账本
async listByTransaction(transactionSerialNum: string): Promise<FamilyLedgerTransaction[]>

// 批量创建交易与账本的关联
async batchCreate(associations: FamilyLedgerTransactionCreate[]): Promise<FamilyLedgerTransaction[]>

// 批量删除交易与账本的关联
async batchDelete(serialNums: string[]): Promise<void>

// 更新交易的账本关联（智能差异更新）
async updateTransactionLedgers(
  transactionSerialNum: string,
  ledgerSerialNums: string[]
): Promise<FamilyLedgerTransaction[]>
```

### 2. MoneyDb 统一接口 (`src/services/money/money.ts`)

#### 新增静态方法：

```typescript
// 根据账本查询关联的交易
static async listFamilyLedgerTransactionsByLedger(ledgerSerialNum: string)

// 根据交易查询关联的账本
static async listFamilyLedgerTransactionsByTransaction(transactionSerialNum: string)

// 批量创建交易与账本的关联
static async batchCreateFamilyLedgerTransactions(associations: FamilyLedgerTransactionCreate[])

// 批量删除交易与账本的关联
static async batchDeleteFamilyLedgerTransactions(serialNums: string[])

// 更新交易的账本关联
static async updateTransactionLedgers(transactionSerialNum: string, ledgerSerialNums: string[])
```

### 3. UI 组件 (`src/features/money/components/FamilyLedgerTransactionList.vue`)

#### 组件功能：
- ✅ 显示账本关联的所有交易记录
- ✅ 支持加载状态和空状态展示
- ✅ 交易列表项包含：
  - 交易描述
  - 交易类型（支出/收入/转账）
  - 分类和子分类
  - 交易日期
  - 交易金额（带货币格式化）
  - 备注信息
- ✅ 点击交易项触发事件
- ✅ 刷新功能
- ✅ 响应式设计

#### 使用方式：

```vue
<template>
  <FamilyLedgerTransactionList
    :ledger-serial-num="currentLedger.serialNum"
    @transaction-click="handleTransactionClick"
    @refresh="handleRefresh"
  />
</template>

<script setup>
import FamilyLedgerTransactionList from '@/features/money/components/FamilyLedgerTransactionList.vue';

function handleTransactionClick(transaction) {
  // 处理交易点击事件
  console.log('Transaction clicked:', transaction);
}

function handleRefresh() {
  // 处理刷新事件
  console.log('List refreshed');
}
</script>
```

## 📝 待完成功能

### 1. 在账本详情页集成交易列表

**文件**: `src/features/money/views/FamilyLedgerDetailView.vue`

**任务**:
- [ ] 导入 `FamilyLedgerTransactionList` 组件
- [ ] 在账本详情页添加交易列表标签页
- [ ] 处理交易点击事件（打开交易详情/编辑）

**示例代码**:
```vue
<template>
  <div class="ledger-detail">
    <!-- 现有的账本信息 -->
    
    <!-- 新增：交易列表标签页 -->
    <div class="ledger-tabs">
      <button @click="activeTab = 'transactions'">交易记录</button>
      <button @click="activeTab = 'members'">成员</button>
      <button @click="activeTab = 'stats'">统计</button>
    </div>
    
    <div v-if="activeTab === 'transactions'" class="tab-content">
      <FamilyLedgerTransactionList
        :ledger-serial-num="ledger.serialNum"
        @transaction-click="openTransactionDetail"
      />
    </div>
  </div>
</template>
```

### 2. 在交易创建/编辑时支持选择关联账本

**文件**: `src/features/money/components/TransactionModal.vue`

**任务**:
- [ ] 添加账本选择器（多选）
- [ ] 在创建交易时同时创建关联
- [ ] 在编辑交易时支持修改关联的账本
- [ ] 显示当前交易已关联的账本列表

**示例代码**:
```vue
<template>
  <div class="transaction-form">
    <!-- 现有的交易表单字段 -->
    
    <!-- 新增：账本关联选择 -->
    <div class="form-field">
      <label>关联账本</label>
      <select multiple v-model="selectedLedgers">
        <option
          v-for="ledger in availableLedgers"
          :key="ledger.serialNum"
          :value="ledger.serialNum"
        >
          {{ ledger.name }}
        </option>
      </select>
    </div>
  </div>
</template>

<script setup>
const selectedLedgers = ref<string[]>([]);

async function saveTransaction() {
  // 1. 创建/更新交易
  const transaction = await MoneyDb.createTransaction(transactionData);
  
  // 2. 更新账本关联
  if (selectedLedgers.value.length > 0) {
    await MoneyDb.updateTransactionLedgers(
      transaction.serialNum,
      selectedLedgers.value
    );
  }
}
</script>
```

### 3. 智能关联建议功能

**任务**:
- [ ] 根据交易的账户自动推荐关联账本
- [ ] 根据交易分类推荐关联账本
- [ ] 根据历史关联模式推荐
- [ ] 提供"一键关联"功能

**示例逻辑**:
```typescript
async function getSuggestedLedgers(transaction: Transaction): Promise<FamilyLedger[]> {
  const suggestions: FamilyLedger[] = [];
  
  // 1. 根据账户查找账本
  const accountLedgers = await findLedgersByAccount(transaction.accountSerialNum);
  suggestions.push(...accountLedgers);
  
  // 2. 根据分类查找账本
  const categoryLedgers = await findLedgersByCategory(transaction.category);
  suggestions.push(...categoryLedgers);
  
  // 3. 去重并返回
  return Array.from(new Set(suggestions));
}
```

### 4. 账本交易统计功能

**任务**:
- [ ] 计算账本的总收入/支出
- [ ] 按分类统计账本交易
- [ ] 按成员统计账本交易
- [ ] 生成账本财务报表

### 5. 批量操作功能

**任务**:
- [ ] 批量导入交易并关联到账本
- [ ] 批量修改交易的账本关联
- [ ] 批量删除账本的交易关联

## 🔧 技术架构

### 数据流向

```
用户操作
  ↓
Vue组件 (FamilyLedgerTransactionList)
  ↓
服务层 (MoneyDb.listFamilyLedgerTransactionsByLedger)
  ↓
映射器 (FamilyLedgerTransactionMapper.listByLedger)
  ↓
Tauri命令 (family_ledger_transaction_list)
  ↓
后端服务 (FamilyLedgerTransactionService)
  ↓
数据库 (family_ledger_transaction表)
```

### 关键设计模式

1. **映射器模式**: 使用 Mapper 类封装数据访问逻辑
2. **统一接口**: MoneyDb 提供统一的静态方法接口
3. **组件化**: UI 组件独立封装，可复用
4. **事件驱动**: 组件通过 emit 触发父组件事件

## 📚 相关文件

### 前端
- `src/services/money/family.ts` - 服务层
- `src/services/money/money.ts` - 统一接口
- `src/features/money/components/FamilyLedgerTransactionList.vue` - UI组件
- `src/schema/money/family.ts` - 类型定义

### 后端
- `src-tauri/crates/money/src/services/family_ledger_transaction.rs` - 服务
- `src-tauri/crates/money/src/dto/family_ledger_transaction.rs` - DTO
- `src-tauri/entity/src/family_ledger_transaction.rs` - 实体
- `src-tauri/migration/src/m20250803_132301_create_family_ledger_transaction.rs` - 迁移

## 🎯 下一步行动

1. **立即可做**:
   - 在 `FamilyLedgerDetailView.vue` 中集成 `FamilyLedgerTransactionList` 组件
   - 测试交易列表的加载和显示

2. **短期目标**:
   - 在 `TransactionModal.vue` 中添加账本选择功能
   - 实现交易创建时的账本关联

3. **中期目标**:
   - 实现智能关联建议
   - 添加批量操作功能

4. **长期目标**:
   - 完善账本财务统计
   - 优化用户体验和性能

## 💡 使用建议

1. **性能优化**: 对于大量交易的账本，考虑使用分页加载
2. **缓存策略**: 缓存账本的交易列表，减少重复请求
3. **错误处理**: 完善错误提示和重试机制
4. **用户体验**: 添加加载动画和骨架屏

## 🐛 已知问题

暂无

## 📝 更新日志

### 2025-11-15
- ✅ 完成前端服务层增强
- ✅ 创建 FamilyLedgerTransactionList 组件
- ✅ 编写集成文档
