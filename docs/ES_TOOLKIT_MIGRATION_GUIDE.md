# ES-Toolkit 迁移指南

> 从自定义实现迁移到 ES-Toolkit 的完整指南  
> 适用于：Miji 项目所有开发者  
> 版本：1.0.0

---

## 📋 目录

1. [迁移概述](#迁移概述)
2. [迁移步骤](#迁移步骤)
3. [常见模式替换](#常见模式替换)
4. [Modal 组件迁移](#modal-组件迁移)
5. [测试验证](#测试验证)
6. [FAQ](#faq)

---

## 迁移概述

### 目标

将项目中的自定义工具函数迁移到 ES-Toolkit，提升：
- ✅ 代码质量和可维护性
- ✅ 类型安全
- ✅ 性能
- ✅ 团队协作效率

### 范围

| 类别 | 当前状态 | 迁移状态 |
|-----|---------|---------|
| 防抖/节流 | ✅ 已迁移 | 完成 |
| 对象工具 | ✅ 已创建 | 完成 |
| 数组工具 | ✅ 已创建 | 完成 |
| 缓存工具 | ✅ 已创建 | 完成 |
| Modal 深拷贝 | ⏳ 待迁移 | 8 处 |

### 预期时间

- **单个文件**: 5-10 分钟
- **全部 8 个文件**: 1-1.5 小时
- **测试验证**: 30 分钟
- **总计**: 2 小时

---

## 迁移步骤

### 步骤 1: 准备工作

#### 1.1 确认依赖已安装

```bash
# 检查 package.json
cat package.json | grep es-toolkit

# 应该看到:
# "es-toolkit": "^1.39.10"
```

#### 1.2 了解工具函数位置

```
src/utils/
├── objectUtils.ts   # 对象操作
├── arrayUtils.ts    # 数组操作
├── cacheUtils.ts    # 缓存工具
├── common.ts        # 通用工具（已优化）
└── README.md        # 使用文档
```

### 步骤 2: 识别需要迁移的代码

#### 2.1 搜索关键模式

```bash
# 搜索 JSON 深拷贝
grep -r "JSON.parse(JSON.stringify" src/

# 搜索手写防抖
grep -r "let timeout" src/ | grep setTimeout

# 搜索手写 reduce 分组
grep -r "reduce((acc" src/
```

#### 2.2 记录待迁移位置

创建一个清单：
```markdown
## 待迁移文件
- [ ] ReminderModal.vue (2 处)
- [ ] FamilyLedgerModal.vue (2 处)
- [ ] BudgetModal.vue (2 处)
- [ ] AccountModal.vue (2 处)
```

### 步骤 3: 逐个文件迁移

对每个文件执行以下步骤...

---

## 常见模式替换

### 模式 1: JSON 深拷贝

#### 替换前
```typescript
const copy = JSON.parse(JSON.stringify(original));
```

#### 替换后
```typescript
import { deepClone } from '@/utils/objectUtils';
const copy = deepClone(original);
```

#### 完整示例

```typescript
// 替换前
const form = reactive({
  ...defaultData,
  ...(props.data ? JSON.parse(JSON.stringify(props.data)) : {})
});

// 替换后
import { deepClone } from '@/utils/objectUtils';
const form = reactive({
  ...defaultData,
  ...(props.data ? deepClone(props.data) : {})
});
```

### 模式 2: 对象合并

#### 替换前
```typescript
const config = { ...defaults, ...user };
```

#### 替换后 (深度合并)
```typescript
import { deepMerge } from '@/utils/objectUtils';
const config = deepMerge(defaults, user);
```

### 模式 3: 数组去重

#### 替换前
```typescript
const unique = Array.from(new Map(users.map(u => [u.id, u])).values());
```

#### 替换后
```typescript
import { uniqueArrayBy } from '@/utils/arrayUtils';
const unique = uniqueArrayBy(users, 'id');
```

### 模式 4: 数组分组

#### 替换前
```typescript
const grouped = transactions.reduce((acc, t) => {
  if (!acc[t.category]) acc[t.category] = [];
  acc[t.category].push(t);
  return acc;
}, {});
```

#### 替换后
```typescript
import { groupArrayBy } from '@/utils/arrayUtils';
const grouped = groupArrayBy(transactions, 'category');
```

### 模式 5: 数组统计

#### 替换前
```typescript
const total = transactions.reduce((sum, t) => sum + t.amount, 0);
```

#### 替换后
```typescript
import { sumBy } from '@/utils/arrayUtils';
const total = sumBy(transactions, 'amount');
```

---

## Modal 组件迁移

### 案例 1: ReminderModal.vue

#### 📍 位置
- `src/features/money/components/ReminderModal.vue:539`
- `src/features/money/components/ReminderModal.vue:652`

#### 🔧 迁移步骤

**步骤 1**: 添加导入
```typescript
// 在文件顶部添加
import { deepClone } from '@/utils/objectUtils';
```

**步骤 2**: 替换第一处 (行 539)
```typescript
// 替换前
watch(
  () => props.reminder,
  newVal => {
    if (newVal) {
      const clonedReminder = JSON.parse(JSON.stringify(newVal));
      clonedReminder.advanceValue = clonedReminder.advanceValue ?? 0;
      // ...
    }
  }
);

// 替换后
watch(
  () => props.reminder,
  newVal => {
    if (newVal) {
      const clonedReminder = deepClone(newVal);
      clonedReminder.advanceValue = clonedReminder.advanceValue ?? 0;
      // ...
    }
  }
);
```

**步骤 3**: 替换第二处 (行 652)
```typescript
// 替换前
watch(
  () => props.reminder,
  newVal => {
    if (newVal) {
      const clonedReminder = JSON.parse(JSON.stringify(newVal));
      // ...
    }
  }
);

// 替换后
watch(
  () => props.reminder,
  newVal => {
    if (newVal) {
      const clonedReminder = deepClone(newVal);
      // ...
    }
  }
);
```

**步骤 4**: 测试
```bash
# 启动开发服务器
npm run tauri:dev

# 测试提醒功能
# 1. 打开提醒列表
# 2. 编辑一个提醒
# 3. 验证数据正确显示
# 4. 保存并验证
```

### 案例 2: FamilyLedgerModal.vue

#### 📍 位置
- `src/features/money/components/FamilyLedgerModal.vue:125`
- `src/features/money/components/FamilyLedgerModal.vue:348`

#### 🔧 迁移步骤

**步骤 1**: 添加导入
```typescript
import { deepClone } from '@/utils/objectUtils';
```

**步骤 2**: 替换初始化 (行 125)
```typescript
// 替换前
const form = reactive<FamilyLedger>(JSON.parse(JSON.stringify(defaultLedger)));

// 替换后
const form = reactive<FamilyLedger>(deepClone(defaultLedger));
```

**步骤 3**: 替换重置函数 (行 348)
```typescript
// 替换前
function resetForm(source?: FamilyLedger): FamilyLedger {
  if (!source) {
    memberList.value = [];
    return JSON.parse(JSON.stringify(defaultLedger));
  }
  // ...
}

// 替换后
function resetForm(source?: FamilyLedger): FamilyLedger {
  if (!source) {
    memberList.value = [];
    return deepClone(defaultLedger);
  }
  // ...
}
```

### 案例 3: BudgetModal.vue

#### 📍 位置
- `src/features/money/components/BudgetModal.vue:75`
- `src/features/money/components/BudgetModal.vue:119`

#### 🔧 迁移步骤

**步骤 1**: 添加导入
```typescript
import { deepClone } from '@/utils/objectUtils';
```

**步骤 2**: 替换序列化 (行 75)
```typescript
// 替换前
const serializedChanges = _.mapValues(changes, (value, key) => {
  if (jsonFields.includes(key) && value !== null && value !== undefined) {
    try {
      return JSON.parse(JSON.stringify(value));
    } catch {
      return value;
    }
  }
  return value;
});

// 替换后
const serializedChanges = _.mapValues(changes, (value, key) => {
  if (jsonFields.includes(key) && value !== null && value !== undefined) {
    try {
      return deepClone(value);
    } catch {
      return value;
    }
  }
  return value;
});
```

**步骤 3**: 替换 watch (行 119)
```typescript
// 替换前
watch(
  () => props.budget,
  newVal => {
    if (newVal) {
      const clonedBudget = JSON.parse(JSON.stringify(newVal));
      // ...
    }
  }
);

// 替换后
watch(
  () => props.budget,
  newVal => {
    if (newVal) {
      const clonedBudget = deepClone(newVal);
      // ...
    }
  }
);
```

### 案例 4: AccountModal.vue

#### 📍 位置
- `src/features/money/components/AccountModal.vue:142`
- `src/features/money/components/AccountModal.vue:248`

#### 🔧 迁移步骤

**步骤 1**: 添加导入
```typescript
import { deepClone } from '@/utils/objectUtils';
```

**步骤 2**: 替换表单初始化 (行 142)
```typescript
// 替换前
const form = reactive<Account>({
  ...defaultAccount,
  ...(props.account ? JSON.parse(JSON.stringify(props.account)) : {}),
  color: (props.account?.color || defaultAccount.color) ?? COLORS_MAP[0].code,
});

// 替换后
const form = reactive<Account>({
  ...defaultAccount,
  ...(props.account ? deepClone(props.account) : {}),
  color: (props.account?.color || defaultAccount.color) ?? COLORS_MAP[0].code,
});
```

**步骤 3**: 替换 watch (行 248)
```typescript
// 替换前
watch(
  () => props.account,
  newVal => {
    if (newVal) {
      Object.assign(form, JSON.parse(JSON.stringify(newVal)));
      syncCurrency(form.currency.code);
    }
  }
);

// 替换后
watch(
  () => props.account,
  newVal => {
    if (newVal) {
      Object.assign(form, deepClone(newVal));
      syncCurrency(form.currency.code);
    }
  }
);
```

---

## 测试验证

### 自动化测试

#### 单元测试
```bash
# 运行所有测试
npm run test

# 运行特定测试
npm run test -- ReminderModal
```

#### E2E 测试
```bash
# 运行端到端测试
npm run test:e2e
```

### 手动测试清单

#### Modal 组件测试

对每个迁移的 Modal 执行：

- [ ] **打开 Modal**
  - 验证初始数据正确显示
  - 验证所有字段正确填充

- [ ] **编辑数据**
  - 修改各个字段
  - 验证实时验证正常
  - 验证错误提示正常

- [ ] **保存数据**
  - 点击保存按钮
  - 验证数据正确保存
  - 验证列表更新

- [ ] **取消操作**
  - 修改数据后取消
  - 验证数据未保存
  - 验证原数据不变

- [ ] **特殊情况**
  - 测试 Date 对象
  - 测试嵌套对象
  - 测试数组字段

### 性能测试

#### 测试代码
```typescript
// 性能对比测试
console.time('JSON.parse');
for (let i = 0; i < 1000; i++) {
  const copy = JSON.parse(JSON.stringify(testData));
}
console.timeEnd('JSON.parse');

console.time('deepClone');
for (let i = 0; i < 1000; i++) {
  const copy = deepClone(testData);
}
console.timeEnd('deepClone');
```

#### 预期结果
- deepClone 应该比 JSON.parse 快 10-20%
- 内存使用应该相似或更低

---

## FAQ

### Q1: 为什么要迁移？

**A**: 
1. **类型安全** - `JSON.parse(JSON.stringify())` 会丢失类型信息
2. **功能完整** - 无法处理 Date、RegExp、Function 等
3. **性能更好** - deepClone 经过优化，更快
4. **代码规范** - 统一使用工具函数

### Q2: 迁移会影响现有功能吗？

**A**: 不会。`deepClone` 是 `JSON.parse(JSON.stringify())` 的超集，功能更强大，完全兼容。

### Q3: 如何处理迁移中的错误？

**A**: 
1. 仔细阅读错误信息
2. 检查是否正确导入
3. 验证数据结构
4. 查看文档和示例
5. 向团队求助

### Q4: 需要更新测试吗？

**A**: 通常不需要。如果有针对 `JSON.parse` 的 mock，需要更新为 `deepClone`。

### Q5: 迁移后性能会提升吗？

**A**: 是的，预期性能提升 10-20%，且内存使用更优化。

### Q6: 可以部分迁移吗？

**A**: 可以。建议按文件逐个迁移，每次迁移后测试验证。

### Q7: 如何回滚？

**A**: 使用 Git 回滚到之前的提交：
```bash
git revert <commit-hash>
```

### Q8: 迁移后如何确保代码质量？

**A**: 
1. Code Review
2. 单元测试
3. E2E 测试
4. 性能测试
5. 用户验收测试

---

## 📝 迁移检查清单

### 迁移前

- [ ] 阅读迁移指南
- [ ] 了解工具函数位置
- [ ] 准备测试环境
- [ ] 备份代码（Git）

### 迁移中

- [ ] 添加正确的导入
- [ ] 替换所有出现的位置
- [ ] 检查语法错误
- [ ] 提交代码到分支

### 迁移后

- [ ] 运行单元测试
- [ ] 执行手动测试
- [ ] 性能对比
- [ ] Code Review
- [ ] 合并到主分支

---

## 🎯 快速参考

### 常用导入

```typescript
// 对象操作
import { deepClone, deepMerge, omitFields, pickFields } from '@/utils/objectUtils';

// 数组操作
import { uniqueArrayBy, groupArrayBy, sumBy, sortArray } from '@/utils/arrayUtils';

// 缓存
import { memoizeFunction, createTTLCache } from '@/utils/cacheUtils';

// 字符串
import { toCamelCase, toSnakeCase } from '@/utils/common';
import { camelCase, snakeCase } from 'es-toolkit';
```

### 常用替换

| 旧代码 | 新代码 |
|--------|--------|
| `JSON.parse(JSON.stringify(obj))` | `deepClone(obj)` |
| `{ ...obj1, ...obj2 }` | `deepMerge(obj1, obj2)` |
| `arr.reduce(...)` | `groupArrayBy(...)` 或 `sumBy(...)` |
| 手写 debounce | `debounce(fn, ms)` |

---

## 📚 相关文档

- [代码规范](./ES_TOOLKIT_CODING_STANDARDS.md)
- [优化建议](./ES_TOOLKIT_OPTIMIZATION_SUGGESTIONS.md)
- [工具函数文档](../src/utils/README.md)
- [快速参考](./ES_TOOLKIT_QUICK_REFERENCE.md)

---

## 📧 联系支持

如果在迁移过程中遇到问题：

1. 查看 [FAQ](#faq)
2. 阅读相关文档
3. 向团队求助
4. 提交 Issue

---

**版本**: 1.0.0  
**最后更新**: 2025-11-30  
**维护者**: 开发团队
