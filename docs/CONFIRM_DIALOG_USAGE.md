# ConfirmDialog 替换方案

## 🎯 两种替换方式

### 方案 A: 使用兼容层（推荐，零改动）⭐

**优点**: 现有代码完全不需要改动，立即可用
**缺点**: 多一层包装，性能略有损失（可忽略）

#### 1. 全局替换 import

只需将所有 import 路径改为兼容层组件即可：

```vue
<!-- 之前 -->
<script setup lang="ts">
import ConfirmDialog from '@/components/common/ConfirmDialog.vue';
import ConfirmModal from '@/components/common/ConfirmModal.vue';
</script>

<!-- 之后 -->
<script setup lang="ts">
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
// ConfirmModal 也用 ConfirmDialogCompat 替换
</script>
```

#### 2. 使用保持不变

```vue
<template>
  <!-- 完全不需要改动，API 100% 兼容 -->
  <ConfirmDialog
    v-model:show="showDialog"
    title="确认删除"
    message="确定要删除吗？"
    type="danger"
    :loading="loading"
    @confirm="handleConfirm"
  />
</template>
```

---

### 方案 B: 直接使用新版（推荐，长期）🚀

**优点**: 性能最优，API 最简洁，无中间层
**缺点**: 需要修改代码（但改动量很小）

#### 修改步骤

##### 1. 修改 import

```vue
<script setup lang="ts">
// 之前
import ConfirmDialog from '@/components/common/ConfirmDialog.vue';

// 之后
import { ConfirmDialog } from '@/components/ui';
</script>
```

##### 2. 修改 Props & Events

```vue
<template>
  <!-- 之前 -->
  <ConfirmDialog
    v-model:show="showDialog"
    type="danger"
    :can-confirm="isValid"
  />

  <!-- 之后 -->
  <ConfirmDialog
    :open="showDialog"
    type="error"
    :confirm-disabled="!isValid"
    @close="showDialog = false"
  />
</template>
```

---

## 📝 快速替换对照表

### Import 替换

```typescript
// 方案 A - 兼容层（零改动）
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';

// 方案 B - 新版（最优）
import { ConfirmDialog } from '@/components/ui';
```

### API 替换（仅方案 B 需要）

| 修改项 | 旧版 | 新版 |
|--------|------|------|
| **显示控制** | `v-model:show` | `:open` + `@close` |
| **显示控制** | `v-model:visible` | `:open` + `@close` |
| **类型** | `type="danger"` | `type="error"` |
| **禁用状态** | `:can-confirm="x"` | `:confirm-disabled="!x"` |

---

## 🔧 实际替换示例

### 示例 1: PeriodRecordForm.vue

**使用 ConfirmDialog (Common)**

#### 方案 A - 使用兼容层（只改 1 行）

```vue
<script setup lang="ts">
// 只需改这一行
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
// ✅ 其他代码完全不变
</script>

<template>
  <!-- ✅ 完全不需要改动 -->
  <ConfirmDialog
    v-model:show="showDeleteConfirm"
    title="删除经期记录"
    type="danger"
    :loading="loading"
    @confirm="handleDelete"
  >
    <!-- 内容保持不变 -->
  </ConfirmDialog>
</template>
```

#### 方案 B - 使用新版（改 3-5 行）

```vue
<script setup lang="ts">
// 1. 改 import
import { ConfirmDialog } from '@/components/ui';
</script>

<template>
  <ConfirmDialog
    :open="showDeleteConfirm"  <!-- 2. 改 prop -->
    title="删除经期记录"
    type="error"  <!-- 3. 改 type -->
    :loading="loading"
    @close="showDeleteConfirm = false"  <!-- 4. 加 @close -->
    @confirm="handleDelete"
  >
    <!-- 内容保持不变 -->
  </ConfirmDialog>
</template>
```

---

### 示例 2: QuickMoneyActions.vue

**使用 ConfirmModal (Common)**

#### 方案 A - 使用兼容层

```vue
<script setup lang="ts">
// 只需改 import，组件名用 ConfirmDialog
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
</script>

<template>
  <!-- ConfirmModal 改名为 ConfirmDialog，其他不变 -->
  <ConfirmDialog
    v-model:visible="showConfirm"
    title="确认删除"
    message="确定要删除这条记录吗？"
    type="warning"
    @confirm="handleConfirm"
  />
</template>
```

#### 方案 B - 使用新版

```vue
<script setup lang="ts">
import { ConfirmDialog } from '@/components/ui';
</script>

<template>
  <ConfirmDialog
    :open="showConfirm"
    title="确认删除"
    message="确定要删除这条记录吗？"
    type="warning"
    @close="showConfirm = false"
    @confirm="handleConfirm"
  />
</template>
```

---

## 📋 批量替换检查清单

### 方案 A - 兼容层替换清单

- [ ] 查找所有 `import ConfirmDialog from '@/components/common/ConfirmDialog.vue'`
- [ ] 替换为 `import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue'`
- [ ] 查找所有 `import ConfirmModal from '@/components/common/ConfirmModal.vue'`
- [ ] 替换为 `import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue'`
- [ ] 测试所有对话框功能
- [ ] ✅ 完成！

### 方案 B - 新版替换清单

每个文件都需要：
- [ ] 修改 import 路径
- [ ] `v-model:show` → `:open` + `@close`
- [ ] `v-model:visible` → `:open` + `@close`
- [ ] `type="danger"` → `type="error"`
- [ ] `:can-confirm="x"` → `:confirm-disabled="!x"`
- [ ] 删除不支持的 props（size, closable, etc.）
- [ ] 测试功能
- [ ] ✅ 完成！

---

## 🎯 推荐迁移流程

### 阶段 1: 立即使用兼容层（0 风险）

1. 创建 `ConfirmDialogCompat.vue` 组件
2. 全局搜索替换 import 路径
3. 测试验证
4. 提交代码

**时间**: 10 分钟  
**风险**: 零  
**效果**: 立即使用新版底层实现

### 阶段 2: 逐步迁移到新版（可选）

在后续开发中，新代码直接使用新版 API：

```vue
import { ConfirmDialog } from '@/components/ui';
```

旧代码保持使用兼容层，逐步重构。

**时间**: 按需进行  
**风险**: 低  
**效果**: 最终完全使用新版 API

---

## ⚡ VS Code 批量替换命令

### 方案 A - 快速替换 import

1. 打开 VS Code
2. 按 `Ctrl+Shift+H` 打开全局替换
3. 勾选 "Use Regular Expression"
4. 查找: `from '@/components/common/Confirm(Dialog|Modal)\.vue'`
5. 替换: `from '@/components/common/ConfirmDialogCompat.vue'`
6. 点击 "Replace All"

### 方案 B - 分步替换到新版

**第 1 步: 替换 import**
```
查找: import (ConfirmDialog|ConfirmModal) from '@/components/common/Confirm(Dialog|Modal)\.vue';
替换: import { ConfirmDialog } from '@/components/ui';
```

**第 2 步: 替换 v-model:show**
```
查找: v-model:show="([^"]+)"
替换: :open="$1" @close="$1 = false"
```

**第 3 步: 替换 v-model:visible**
```
查找: v-model:visible="([^"]+)"
替换: :open="$1" @close="$1 = false"
```

**第 4 步: 替换 type**
```
查找: type="danger"
替换: type="error"
```

---

## 📊 影响范围

### 需要替换的文件（共 6 个）

1. ✅ `features/health/period/views/PeriodRecordForm.vue` - ConfirmDialog
2. ✅ `components/common/QuickMoneyActions.vue` - ConfirmModal
3. ✅ `features/money/views/FamilyLedgerView.vue` - ConfirmModal
4. ✅ `features/money/views/MoneyView.vue` - ConfirmModal
5. ✅ `features/settings/components/AvatarEditModal.vue` - ConfirmModal
6. ✅ `features/settings/components/ProfileEditModal.vue` - ConfirmModal

---

## ❓ FAQ

### Q1: 必须迁移吗？
**A**: 不是必须，但强烈推荐。旧版组件将来可能不再维护。

### Q2: 兼容层有性能问题吗？
**A**: 几乎没有，只是多一层 props 转换，性能损失可忽略不计。

### Q3: 可以混用吗？
**A**: 可以！新代码用新版，旧代码用兼容层，完全没问题。

### Q4: 什么时候删除旧版组件？
**A**: 所有代码迁移完成后，确认没有引用再删除。

---

## 🎉 迁移完成后

- ✅ 统一使用现代化的 UI 组件
- ✅ 更好的无障碍支持
- ✅ 更简洁的 API
- ✅ 更好的深色模式支持
- ✅ 减少维护成本
