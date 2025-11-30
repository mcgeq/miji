# 批量移除 Lucide 导入脚本

> 用于批量优化项目中不必要的 Lucide 图标导入  
> 创建时间：2025-11-30

---

## 🎯 目标

移除 Vue 文件中仅在模板使用的 Lucide 图标导入（约 30-40 个文件）

---

## ✅ 已完成（第一批）

### Commit: eba399c
**移除的文件**（3 个）：
- `src/components/ui/Checkbox.vue`
- `src/components/ui/Avatar.vue`
- `src/components/common/ColorSelector.vue`

**之前的提交**：
- `src/components/common/CloseDialog.vue`

---

## 📋 待优化文件清单

### 高优先级（简单组件 - 仅模板使用）

#### UI 组件
- [ ] `src/components/ui/Radio.vue` - Check
- [ ] `src/components/ui/Dropdown.vue` - Check, ChevronDown  
- [ ] `src/components/ui/Select.vue` - Check, ChevronDown, Search, X
- [ ] `src/components/ui/Modal.vue` - Check, Trash2, X

⚠️ **不能优化**（在 script 中作为值使用）：
- ❌ `src/components/ui/Alert.vue` - 图标作为 typeConfig.icon
- ❌ `src/components/ui/ConfirmDialog.vue` - 图标作为配置值

#### Common 组件
- [ ] `src/components/common/FilterBar.vue`
- [ ] `src/components/common/Sidebar.vue`  
- [ ] `src/components/common/NumpadKeyboard.vue`
- [ ] `src/components/common/GenericItem.vue`
- [ ] `src/components/common/datetime/DateInput.vue`
- [ ] `src/components/common/datetime/DateTimePanel.vue`

#### Quick Money 组件
- [ ] `src/components/common/QuickMoneyHeader.vue`
- [ ] `src/components/common/QuickMoneyActionButtons.vue`
- [ ] `src/components/common/QuickMoneyAccountList.vue`
- [ ] `src/components/common/QuickMoneyBudgetList.vue`
- [ ] `src/components/common/QuickMoneyReminderList.vue`
- [ ] `src/components/common/QuickMoneyTransactionList.vue`

### 中优先级（Feature 组件）

#### Money Features
- [ ] `src/features/money/components/BudgetList.vue`
- [ ] `src/features/money/components/ReminderList.vue`
- [ ] `src/features/money/components/TransactionTable.vue`
- [ ] `src/features/money/components/FamilyMemberList.vue`
- [ ] `src/features/money/components/FamilyLedgerList.vue`
- [ ] `src/features/money/views/MoneyView.vue`
- [ ] `src/features/money/views/FamilyLedgerView.vue`

#### Health/Period Features
- [ ] `src/features/health/period/components/PeriodCalendar.vue`
- [ ] `src/features/health/period/components/PeriodHealthTip.vue`
- [ ] `src/features/health/period/components/PeriodRecentRecord.vue`
- [ ] `src/features/health/period/views/PeriodListView.vue`
- [ ] `src/features/health/period/views/PeriodManagement.vue`

#### Settings Features
- [ ] `src/features/settings/components/AvatarEditModal.vue`
- [ ] `src/features/settings/components/ProfileEditModal.vue`
- [ ] `src/features/settings/views/GeneralSettings.vue`

### 低优先级（复杂组件 - 需仔细检查）

⚠️ 这些组件可能在 script 中引用图标，需要逐个检查：
- `src/features/money/components/DebtRelationChart.vue`
- `src/features/money/components/FamilyFinancialStats.vue`
- `src/features/money/components/StackedStatCards.vue`
- `src/features/money/components/charts/*.vue`

---

## 🔧 手动优化步骤

### 对每个文件：

1. **打开文件**
2. **检查导入**：`import { Icon1, Icon2 } from 'lucide-vue-next';`
3. **搜索 script 中的引用**：
   ```bash
   # 检查是否在 script 中引用（作为值）
   # 如果有类似 icon: Icon1 的代码，则不能移除
   ```
4. **如果仅在模板中使用**：
   - 删除整行导入
   - 保存文件
5. **测试**：确保组件正常显示

### 示例

```vue
<!-- ❌ 移除前 -->
<script setup>
import { Check, X } from 'lucide-vue-next';
</script>

<template>
  <LucideCheck />
  <LucideX />
</template>

<!-- ✅ 移除后 -->
<script setup>
</script>

<template>
  <LucideCheck />
  <LucideX />
</template>
```

---

## 🚀 批量优化脚本（可选）

### 方案 A：使用 VSCode 批量查找替换

1. **打开 VSCode 全局搜索**（Ctrl/Cmd + Shift + F）
2. **搜索模式**：
   ```regex
   ^import .* from 'lucide-vue-next';$
   ```
3. **逐个文件检查**是否在 script 中引用
4. **手动删除**不需要的导入

### 方案 B：使用 Node.js 脚本（半自动）

创建 `scripts/remove-lucide-imports.js`：

```javascript
const fs = require('fs');
const path = require('path');
const glob = require('glob');

// 找到所有 Vue 文件
const files = glob.sync('src/**/*.vue');

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf-8');
  
  // 提取 <script> 部分
  const scriptMatch = content.match(/<script[^>]*>([\s\S]*?)<\/script>/);
  if (!scriptMatch) return;
  
  const scriptContent = scriptMatch[1];
  
  // 检查是否导入了 lucide-vue-next
  const importMatch = scriptContent.match(/import\s+{([^}]+)}\s+from\s+['"]lucide-vue-next['"]/);
  if (!importMatch) return;
  
  const imports = importMatch[1].split(',').map(s => s.trim());
  
  // 检查这些导入是否在 script 中作为值使用
  const usedInScript = imports.some(imp => {
    // 简单检查：是否在 script 中有 imp: 或 = imp 等模式
    const regex = new RegExp(`(:\\s*${imp}\\b|=\\s*${imp}\\b|\\[${imp}\\])`, 'g');
    return regex.test(scriptContent);
  });
  
  if (!usedInScript) {
    console.log(`✅ 可以移除: ${file}`);
    console.log(`   导入: ${imports.join(', ')}`);
  } else {
    console.log(`⚠️  需要保留: ${file}`);
    console.log(`   原因: 在 script 中引用`);
  }
});
```

**运行**：
```bash
node scripts/remove-lucide-imports.js
```

---

## 📊 预期收益

| 批次 | 文件数 | 减少代码行 | 状态 |
|-----|--------|-----------|------|
| **第一批** | 4 个 | 4 行 | ✅ 完成 |
| **第二批（UI）** | ~8-10 个 | ~10 行 | 待执行 |
| **第三批（Common）** | ~10-15 个 | ~15 行 | 待执行 |
| **第四批（Feature）** | ~15-20 个 | ~20 行 | 待执行 |
| **总计** | **~40-50 个** | **~50 行** | **进行中** |

---

## ⚠️ 注意事项

### 必须保留导入的情况

1. **图标作为配置值**：
```typescript
const config = {
  icon: Info,  // ❌ 必须保留 import { Info }
};
```

2. **动态组件引用**：
```vue
<component :is="iconComponent" />  // ❌ 必须保留
```

3. **传递给子组件**：
```vue
<MyComponent :icon="Check" />  // ❌ 必须保留
```

4. **TypeScript 文件**：
```typescript
// periodUtils.ts - ❌ 必须保留
import { Activity } from 'lucide-vue-next';
const tips = [{ icon: Activity }];
```

---

## 🎯 执行计划

### 今天（2025-11-30）
- [x] 第一批：UI 组件（4 个）✅

### 明天或下次
- [ ] 第二批：剩余 UI 组件（8-10 个）
- [ ] 第三批：Common 组件（10-15 个）
- [ ] 第四批：Feature 组件（15-20 个）

### 建议每批次
- 一次处理 10-15 个文件
- 提交前测试功能
- 写清晰的提交信息

---

## 📝 提交信息模板

```bash
git commit -m "refactor: remove unnecessary Lucide imports (batch N - category)

- Remove Lucide imports from X files
- Components now use auto-import via LucideResolver
- Affected: component1, component2, component3
"
```

---

**最后更新**：2025-11-30  
**进度**：4/50 文件（8%）  
**下一步**：优化剩余 UI 和 Common 组件
