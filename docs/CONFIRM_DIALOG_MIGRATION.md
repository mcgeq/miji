# ConfirmDialog 组件迁移指南

## 📋 概述

将旧版的 `ConfirmDialog.vue` (Common) 和 `ConfirmModal.vue` (Common) 统一迁移到新版的 `ConfirmDialog.vue` (UI)。

---

## 🔍 API 对比

### Props 映射表

| 旧版 (Common) | 新版 (UI) | 说明 |
|---------------|-----------|------|
| `show` / `visible` | `open` | ✅ 改名 |
| `type: 'danger'` | `type: 'error'` | ✅ 值改变 |
| `title` | `title` | ✅ 相同 |
| `message` | `message` | ✅ 相同 |
| `confirmText` | `confirmText` | ✅ 相同 |
| `cancelText` | `cancelText` | ✅ 相同 |
| `showCancel` | `showCancel` | ✅ 相同 |
| `loading` | `loading` | ✅ 相同 |
| `canConfirm` | `confirmDisabled` | ⚠️ 逻辑相反 |
| `size` | ❌ | ⚠️ 不支持（固定 max-w-md） |
| `closable` | ❌ | ⚠️ 不支持（始终可关闭） |
| `persistent` | ❌ | ⚠️ 不支持 |
| `zIndex` | ❌ | ⚠️ 固定 z-[999999] |
| `confirmIcon` | ❌ | ⚠️ 不支持 |
| `confirmButtonType` | ❌ | ⚠️ 根据 type 自动设置 |

### Events 映射表

| 旧版 (Common) | 新版 (UI) | 说明 |
|---------------|-----------|------|
| `update:show` | ❌ | ⚠️ 需手动在 `@close` 中处理 |
| `update:visible` | ❌ | ⚠️ 需手动在 `@close` 中处理 |
| `confirm` | `confirm` | ✅ 相同 |
| `cancel` | `cancel` | ✅ 相同 |
| `close` | `close` | ✅ 相同 |

---

## 🔧 替换步骤

### 步骤 1: 修改 import

```vue
<!-- 旧版 -->
<script setup lang="ts">
import ConfirmDialog from '@/components/common/ConfirmDialog.vue';
// 或
import ConfirmModal from '@/components/common/ConfirmModal.vue';
</script>

<!-- 新版 -->
<script setup lang="ts">
import { ConfirmDialog } from '@/components/ui';
</script>
```

### 步骤 2: 修改 Props

#### 基础替换

```vue
<!-- 旧版 -->
<ConfirmDialog
  v-model:show="showDialog"
  title="确认删除"
  message="确定要删除这条记录吗？"
  type="danger"
/>

<!-- 新版 -->
<ConfirmDialog
  :open="showDialog"
  title="确认删除"
  message="确定要删除这条记录吗？"
  type="error"
  @close="showDialog = false"
/>
```

#### type 值映射

```typescript
// 旧版 type: 'info' | 'warning' | 'danger' | 'success' | 'error'
// 新版 type: 'info' | 'warning' | 'error' | 'success'

// 替换规则
'danger' → 'error'  // 其他值保持不变
```

#### canConfirm → confirmDisabled

```vue
<!-- 旧版 -->
<ConfirmDialog
  :can-confirm="isFormValid"
/>

<!-- 新版 -->
<ConfirmDialog
  :confirm-disabled="!isFormValid"
/>
```

### 步骤 3: 修改 Events

#### v-model:show / v-model:visible

```vue
<!-- 旧版 - 使用 v-model -->
<ConfirmDialog v-model:show="showDialog" />
<ConfirmModal v-model:visible="showModal" />

<!-- 新版 - 手动处理 -->
<ConfirmDialog
  :open="showDialog"
  @close="showDialog = false"
/>
```

#### 事件处理

```vue
<!-- 旧版 -->
<ConfirmDialog
  v-model:show="showDialog"
  @confirm="handleConfirm"
  @cancel="handleCancel"
/>

<!-- 新版 -->
<ConfirmDialog
  :open="showDialog"
  @close="showDialog = false"
  @confirm="handleConfirm"
  @cancel="handleCancel"
/>
```

---

## 📝 完整示例

### 示例 1: 删除确认

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { ConfirmDialog } from '@/components/ui';

const showDeleteConfirm = ref(false);
const loading = ref(false);

async function handleDelete() {
  loading.value = true;
  try {
    await deleteRecord();
    showDeleteConfirm.value = false;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <!-- 旧版 -->
  <ConfirmDialog
    v-model:show="showDeleteConfirm"
    title="确认删除"
    message="确定要删除这条记录吗？此操作无法撤销。"
    type="danger"
    confirm-text="删除"
    :loading="loading"
    @confirm="handleDelete"
  />

  <!-- 新版 -->
  <ConfirmDialog
    :open="showDeleteConfirm"
    title="确认删除"
    message="确定要删除这条记录吗？此操作无法撤销。"
    type="error"
    confirm-text="删除"
    :loading="loading"
    @close="showDeleteConfirm = false"
    @confirm="handleDelete"
  />
</template>
```

### 示例 2: 带自定义内容

```vue
<script setup lang="ts">
import { ref } from 'vue';
import { ConfirmDialog } from '@/components/ui';

const showWarning = ref(false);
</script>

<template>
  <ConfirmDialog
    :open="showWarning"
    title="警告"
    type="warning"
    confirm-text="继续"
    @close="showWarning = false"
    @confirm="handleContinue"
  >
    <!-- 自定义内容 -->
    <div class="space-y-2">
      <p class="text-sm text-gray-600">检测到以下问题：</p>
      <ul class="list-disc list-inside text-sm text-gray-600">
        <li>数据可能不完整</li>
        <li>操作可能影响其他记录</li>
      </ul>
      <p class="text-sm font-medium text-gray-900">确定要继续吗？</p>
    </div>
  </ConfirmDialog>
</template>
```

---

## 🎯 使用统计

共发现 **6 处**使用旧版组件：

### ConfirmDialog (Common) - 1 处
1. `features/health/period/views/PeriodRecordForm.vue`

### ConfirmModal (Common) - 5 处
1. `components/common/QuickMoneyActions.vue`
2. `features/money/views/FamilyLedgerView.vue`
3. `features/money/views/MoneyView.vue`
4. `features/settings/components/AvatarEditModal.vue`
5. `features/settings/components/ProfileEditModal.vue`

---

## ⚠️ 注意事项

### 1. 不支持的功能

以下功能在新版中不支持：
- ❌ `size` prop - 固定为 `max-w-md`
- ❌ `closable` prop - 始终可关闭
- ❌ `persistent` prop - 不支持
- ❌ `zIndex` prop - 固定 `z-[999999]`
- ❌ `confirmIcon` - 根据 type 自动设置图标

**解决方案**：这些是旧版的高级功能，实际使用中很少用到。如果确实需要，可以：
1. 保留旧版组件用于特殊场景
2. 或者为新版组件添加这些功能

### 2. v-model 改为手动控制

旧版支持 `v-model:show` 或 `v-model:visible`，新版需要手动处理：

```vue
<!-- 必须添加 @close -->
<ConfirmDialog
  :open="show"
  @close="show = false"
/>
```

### 3. canConfirm 逻辑相反

```typescript
// 旧版
:can-confirm="isValid"  // true = 可以确认

// 新版  
:confirm-disabled="!isValid"  // true = 禁用确认
```

---

## ✅ 迁移检查清单

- [ ] 修改 import 路径
- [ ] 替换 `show` / `visible` 为 `open`
- [ ] 添加 `@close` 事件处理
- [ ] 将 `type="danger"` 改为 `type="error"`
- [ ] 将 `canConfirm` 改为 `confirmDisabled`（逻辑取反）
- [ ] 删除不支持的 props（size, closable, etc.）
- [ ] 测试所有确认对话框功能

---

## 🚀 迁移后的优势

1. **更现代**: 基于 Headless UI，无障碍支持更好
2. **更轻量**: 无自定义 CSS，使用 Tailwind 类
3. **更统一**: 与其他 UI 组件保持一致的 API
4. **更简洁**: 移除了不常用的高级功能，API 更清晰
5. **深色模式**: 原生支持深色模式
