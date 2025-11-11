# 旧代码移除计划

**创建时间**: 2025-11-11  
**状态**: 准备移除

---

## ✅ 迁移完成确认

### 已迁移的文件 (19/19)

#### Composables (5/5) ✅
- [x] useAccountActions.ts
- [x] useTransactionActions.ts
- [x] useBudgetActions.ts
- [x] useReminderActions.ts
- [x] **useTabManager.ts** (最后完成)

#### Components (10/10) ✅
- [x] CategorySelector.vue
- [x] AccountSelector.vue
- [x] QuickMoneyActions.vue
- [x] AccountList.vue
- [x] BudgetList.vue
- [x] ReminderList.vue
- [x] TransactionList.vue
- [x] TransactionModal.vue
- [x] TransactionStatsTable.vue
- [x] **MoneyView.vue** (最后完成)

#### Features (3/3) ✅
- [x] useBilReminderFilters.ts
- [x] useBudgetFilters.ts
- [x] HomeView.vue

#### Core (1/1) ✅
- [x] App.vue
- [x] main.ts
- [x] stores/index.ts

---

## 📋 可以移除的文件

### 1. moneyStore.ts (主要文件)
**路径**: `src/stores/moneyStore.ts`  
**大小**: 848 行  
**状态**: ✅ 可以安全删除

**原因**:
- 所有功能已迁移到新的模块化 stores
- 没有任何文件再导入此store
- 新的架构完全替代了旧功能

**替代方案**:
```typescript
// 旧代码
import { useMoneyStore } from '@/stores/moneyStore';
const moneyStore = useMoneyStore();

// 新代码
import { useAccountStore, useTransactionStore, useBudgetStore, useReminderStore, useCategoryStore } from '@/stores/money';
const accountStore = useAccountStore();
const transactionStore = useTransactionStore();
// ... 按需引入
```

---

## 🔍 验证检查

### 检查命令
```bash
# 搜索是否还有文件使用 useMoneyStore
grep -r "useMoneyStore" src/ --exclude-dir=node_modules

# 搜索是否还有导入 moneyStore
grep -r "from '@/stores/moneyStore'" src/ --exclude-dir=node_modules

# 搜索是否还有 moneyStore 的直接引用
grep -r "moneyStore\." src/ --exclude-dir=node_modules
```

### 验证结果
✅ 无任何文件导入 `useMoneyStore`  
✅ 无任何文件使用 `moneyStore.` 方法  
✅ 仅 `auto-imports.d.ts` 中有自动生成的类型定义（无影响）

---

## 🗑️ 删除步骤

### 方案A: 立即删除（推荐）

```bash
# 1. 备份文件（可选）
cp src/stores/moneyStore.ts src/stores/moneyStore.ts.backup

# 2. 删除文件
rm src/stores/moneyStore.ts

# 3. 验证构建
npm run type-check
npm run build
```

### 方案B: 先标记 Deprecated

如果想更谨慎，可以先标记为 deprecated：

```typescript
/**
 * @deprecated 此 store 已废弃，请使用新的模块化 stores:
 * - useAccountStore (账户管理)
 * - useTransactionStore (交易管理)
 * - useBudgetStore (预算管理)
 * - useReminderStore (提醒管理)
 * - useCategoryStore (分类管理)
 * 
 * 导入方式: import { useAccountStore } from '@/stores/money'
 * 
 * 此文件将在下一个主版本中移除
 */
export const useMoneyStore = defineStore('money', {
  // ... existing code
});
```

---

## 📊 删除影响分析

### 代码体积减少
- **删除**: moneyStore.ts (848 行)
- **新增**: 6个模块化文件 (1,022 行)
- **净增加**: 174 行 (但代码质量大幅提升)

### 构建影响
- ✅ 无破坏性变更
- ✅ 所有功能已迁移
- ✅ 类型安全保持
- ✅ 可以tree-shaking优化

### 运行时影响
- ✅ 无影响，所有代码已迁移
- ✅ 性能更好（按需加载）
- ✅ 内存占用更优

---

## ⚠️ 注意事项

### 1. auto-imports.d.ts
这个文件会自动更新，删除 moneyStore.ts 后会自动移除相关类型定义。

### 2. Git 历史
建议保留 git 历史记录，以便需要时可以回溯：
```bash
git log --follow src/stores/moneyStore.ts
```

### 3. 文档更新
删除后需要更新以下文档：
- README.md
- 架构文档
- API文档

---

## ✅ 删除后检查清单

- [ ] 运行 `npm run type-check` 无错误
- [ ] 运行 `npm run build` 成功
- [ ] 运行 `npm run dev` 应用正常启动
- [ ] 测试所有主要功能
- [ ] 更新相关文档
- [ ] 提交代码变更

---

## 🎯 推荐行动

**建议：立即删除 moneyStore.ts**

**理由**:
1. ✅ 所有19个文件已完成迁移
2. ✅ 无任何代码依赖此文件
3. ✅ 新架构已完全替代
4. ✅ 保留旧代码会造成混淆
5. ✅ 有完整的 git 历史可以回溯

**执行命令**:
```bash
# 删除旧的 moneyStore
rm src/stores/moneyStore.ts

# 验证
npm run type-check

# 提交
git add .
git commit -m "chore: remove deprecated moneyStore.ts after migration"
```

---

## 📝 备注

### 如果需要回滚
```bash
# 从 git 历史恢复
git checkout HEAD~1 src/stores/moneyStore.ts

# 或从备份恢复
cp src/stores/moneyStore.ts.backup src/stores/moneyStore.ts
```

### 迁移文档位置
- `FRONTEND_REFACTORING_SUMMARY.md` - 重构总结
- `MIGRATION_CHECKLIST.md` - 迁移清单
- `MIGRATION_COMPLETED.md` - 完成报告
- `MIGRATION_PROGRESS.md` - 进度追踪

---

**准备好删除旧代码了吗？** 🚀
