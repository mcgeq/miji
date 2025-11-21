# 📘 BaseModal 使用指南

## 简介

`BaseModal` 是一个统一的模态框基础组件，提供了一致的结构、样式和交互体验。

## 特性

✅ 统一的模态框结构  
✅ 多种尺寸支持 (sm, md, lg, xl, full)  
✅ 灵活的插槽系统  
✅ 可配置的按钮和行为  
✅ 优雅的动画效果  
✅ 移动端响应式适配  
✅ 完整的 TypeScript 支持  

---

## 基础用法

### 1. 简单模态框

```vue
<script setup lang="ts">
const showModal = ref(false);

function handleConfirm() {
  console.log('确认');
  showModal.value = false;
}
</script>

<template>
  <BaseModal
    v-if="showModal"
    title="提示"
    @close="showModal = false"
    @confirm="handleConfirm"
  >
    <p>这是模态框内容</p>
  </BaseModal>
</template>
```

### 2. 自定义尺寸

```vue
<BaseModal
  title="大型模态框"
  size="lg"
  @close="handleClose"
>
  <!-- 内容 -->
</BaseModal>
```

**可用尺寸**:
- `sm`: 400px
- `md`: 600px (默认)
- `lg`: 800px
- `xl`: 1200px
- `full`: 全屏

### 3. 自定义按钮文本

```vue
<BaseModal
  title="创建账户"
  confirm-text="创建"
  cancel-text="取消"
  @close="handleClose"
  @confirm="handleCreate"
>
  <!-- 表单 -->
</BaseModal>
```

### 4. 禁用确认按钮

```vue
<script setup lang="ts">
const isFormValid = ref(false);
</script>

<template>
  <BaseModal
    title="编辑"
    :confirm-disabled="!isFormValid"
    @confirm="handleSave"
  >
    <!-- 表单 -->
  </BaseModal>
</template>
```

### 5. 加载状态

```vue
<script setup lang="ts">
const loading = ref(false);

async function handleSave() {
  loading.value = true;
  try {
    await saveData();
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <BaseModal
    title="保存"
    :confirm-loading="loading"
    @confirm="handleSave"
  >
    <!-- 内容 -->
  </BaseModal>
</template>
```

---

## 高级用法

### 1. 自定义头部

```vue
<BaseModal @close="handleClose">
  <template #header>
    <div class="custom-header">
      <LucideUser class="icon" />
      <h2>自定义标题</h2>
      <span class="badge">新</span>
    </div>
  </template>
  
  <!-- 内容 -->
</BaseModal>
```

### 2. 自定义底部

```vue
<BaseModal title="操作" @close="handleClose">
  <!-- 内容 -->
  
  <template #footer>
    <button class="btn-secondary" @click="handleClose">
      取消
    </button>
    <button class="btn-danger" @click="handleDelete">
      删除
    </button>
    <button class="btn-primary" @click="handleSave">
      保存
    </button>
  </template>
</BaseModal>
```

### 3. 无底部操作栏

```vue
<BaseModal
  title="查看详情"
  :show-footer="false"
  @close="handleClose"
>
  <!-- 只读内容 -->
</BaseModal>
```

### 4. 禁用遮罩层关闭

```vue
<BaseModal
  title="重要操作"
  :close-on-overlay="false"
  @close="handleClose"
>
  <p>点击遮罩层不会关闭此模态框</p>
</BaseModal>
```

### 5. 隐藏关闭按钮

```vue
<BaseModal
  title="强制操作"
  :show-close-button="false"
  @close="handleClose"
>
  <p>必须点击底部按钮才能关闭</p>
</BaseModal>
```

---

## Props API

| 属性 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `title` | `string` | - | 模态框标题 |
| `size` | `'sm' \| 'md' \| 'lg' \| 'xl' \| 'full'` | `'md'` | 模态框尺寸 |
| `showFooter` | `boolean` | `true` | 是否显示底部操作栏 |
| `closeOnOverlay` | `boolean` | `true` | 点击遮罩层是否关闭 |
| `showCloseButton` | `boolean` | `true` | 是否显示关闭按钮 |
| `confirmText` | `string` | `'确认'` | 确认按钮文本 |
| `cancelText` | `string` | `'取消'` | 取消按钮文本 |
| `showConfirm` | `boolean` | `true` | 是否显示确认按钮 |
| `showCancel` | `boolean` | `true` | 是否显示取消按钮 |
| `confirmLoading` | `boolean` | `false` | 确认按钮加载状态 |
| `confirmDisabled` | `boolean` | `false` | 确认按钮禁用状态 |

---

## Events API

| 事件 | 参数 | 说明 |
|------|------|------|
| `close` | - | 关闭模态框时触发 |
| `confirm` | - | 点击确认按钮时触发 |
| `cancel` | - | 点击取消按钮时触发 |

---

## Slots API

| 插槽 | 说明 |
|------|------|
| `default` | 模态框内容 |
| `header` | 自定义头部 |
| `footer` | 自定义底部 |

---

## 完整示例

### 表单模态框

```vue
<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import { useFormValidation } from '@/composables/useFormValidation';

const showModal = ref(false);
const form = ref({
  name: '',
  email: '',
});

const validation = useFormValidation(FormSchema);
const loading = ref(false);

const isValid = computed(() => !validation.hasAnyError.value);

async function handleSave() {
  if (!validation.validateAll(form.value)) {
    return;
  }

  loading.value = true;
  try {
    await saveData(form.value);
    showModal.value = false;
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <button @click="showModal = true">
    打开模态框
  </button>

  <BaseModal
    v-if="showModal"
    title="创建用户"
    size="md"
    confirm-text="创建"
    :confirm-disabled="!isValid"
    :confirm-loading="loading"
    @close="showModal = false"
    @confirm="handleSave"
  >
    <form class="form" @submit.prevent="handleSave">
      <div class="form-group">
        <label>姓名</label>
        <input
          v-model="form.name"
          type="text"
          class="form-input"
          :class="{ 'error': validation.shouldShowError('name') }"
        >
        <span v-if="validation.shouldShowError('name')" class="error-text">
          {{ validation.getError('name') }}
        </span>
      </div>

      <div class="form-group">
        <label>邮箱</label>
        <input
          v-model="form.email"
          type="email"
          class="form-input"
          :class="{ 'error': validation.shouldShowError('email') }"
        >
        <span v-if="validation.shouldShowError('email')" class="error-text">
          {{ validation.getError('email') }}
        </span>
      </div>
    </form>
  </BaseModal>
</template>
```

---

## 样式定制

### 1. 使用 CSS 变量

```css
:root {
  --color-base-100: #ffffff;
  --color-base-content: #1f2937;
  --color-primary: #3b82f6;
  --color-primary-content: #ffffff;
  --color-gray-200: #e5e7eb;
  --shadow-2xl: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}
```

### 2. 覆盖样式

```vue
<style scoped>
:deep(.base-modal-container) {
  border-radius: 1.5rem;
}

:deep(.base-modal-header) {
  background: linear-gradient(to right, #3b82f6, #8b5cf6);
  color: white;
}
</style>
```

---

## 最佳实践

### 1. 使用 v-if 控制显示

```vue
<!-- ✅ 推荐 -->
<BaseModal v-if="showModal" @close="showModal = false">
  <!-- 内容 -->
</BaseModal>

<!-- ❌ 不推荐 -->
<BaseModal v-show="showModal" @close="showModal = false">
  <!-- 内容 -->
</BaseModal>
```

### 2. 结合表单验证

```vue
<script setup lang="ts">
const validation = useFormValidation(schema);
const isValid = computed(() => !validation.hasAnyError.value);
</script>

<template>
  <BaseModal
    :confirm-disabled="!isValid"
    @confirm="handleSubmit"
  >
    <!-- 表单 -->
  </BaseModal>
</template>
```

### 3. 处理异步操作

```vue
<script setup lang="ts">
const loading = ref(false);

async function handleSave() {
  loading.value = true;
  try {
    await api.save();
    emit('close');
  } catch (error) {
    toast.error(error.message);
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <BaseModal
    :confirm-loading="loading"
    @confirm="handleSave"
  >
    <!-- 内容 -->
  </BaseModal>
</template>
```

---

## 迁移指南

### 从旧模态框迁移

**旧代码**:
```vue
<div class="modal-mask" @click="handleClose">
  <div class="modal-window" @click.stop>
    <div class="modal-header">
      <h2>标题</h2>
      <button @click="handleClose">×</button>
    </div>
    <div class="modal-content">
      <!-- 内容 -->
    </div>
    <div class="modal-footer">
      <button @click="handleClose">取消</button>
      <button @click="handleSave">确认</button>
    </div>
  </div>
</div>
```

**新代码**:
```vue
<BaseModal
  title="标题"
  @close="handleClose"
  @confirm="handleSave"
>
  <!-- 内容 -->
</BaseModal>
```

**收益**:
- 减少 ~50 行代码
- 统一样式和交互
- 更好的可维护性

---

## 常见问题

### Q: 如何在模态框内使用表单提交？

A: 使用 `@submit.prevent` 阻止默认提交，然后在 `@confirm` 事件中处理：

```vue
<BaseModal @confirm="handleSubmit">
  <form @submit.prevent="handleSubmit">
    <!-- 表单字段 -->
  </form>
</BaseModal>
```

### Q: 如何实现嵌套模态框？

A: 使用不同的 `z-index` 或 Teleport：

```vue
<BaseModal title="第一层">
  <BaseModal title="第二层" style="z-index: 1001">
    <!-- 内容 -->
  </BaseModal>
</BaseModal>
```

### Q: 如何禁用 ESC 键关闭？

A: 目前不支持，可以通过 `closeOnOverlay` 和 `showCloseButton` 控制关闭方式。

---

## 相关资源

- [useFormValidation 使用指南](./FORM_VALIDATION_GUIDE.md)
- [useCrudActions 使用指南](./CRUD_ACTIONS_GUIDE.md)
- [重构进度](./REFACTORING_PROGRESS.md)
