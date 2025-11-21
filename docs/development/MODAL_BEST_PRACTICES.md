# Modal 组件开发最佳实践

## 🎯 目标

建立统一的 Modal 组件开发标准，确保代码质量、可维护性和用户体验的一致性。

---

## 📐 架构原则

### 1. 组件化优先

**✅ 推荐**:
```vue
<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import FormRow from '@/components/common/FormRow.vue';
</script>

<template>
  <BaseModal :title="title" size="md" @close="..." @confirm="...">
    <form @submit.prevent="handleSubmit">
      <FormRow label="字段名" required>
        <input v-model="form.field" class="modal-form-control" />
      </FormRow>
    </form>
  </BaseModal>
</template>
```

**❌ 避免**:
```vue
<!-- 自定义模态框结构 -->
<div class="custom-modal">
  <div class="custom-header">...</div>
  <div class="custom-body">...</div>
  <div class="custom-footer">...</div>
</div>
```

### 2. 样式复用

**✅ 推荐**: 使用共享样式
```vue
<style scoped>
@import '@/assets/styles/modal-forms.css';

/* 只添加组件特定样式 */
.special-section {
  background: var(--color-base-100);
}
</style>
```

**❌ 避免**: 重复定义样式
```vue
<style scoped>
.form-row {
  display: flex;
  margin-bottom: 0.75rem;
  /* 重复定义... */
}
</style>
```

### 3. 状态管理

**✅ 推荐**: 使用 composables
```typescript
// useFormState.ts
export function useFormState<T>(initialData: T) {
  const form = ref<T>(initialData);
  const isSubmitting = ref(false);
  const errors = reactive<Record<string, string>>({});

  return {
    form,
    isSubmitting,
    errors,
  };
}

// 在组件中使用
const { form, isSubmitting, errors } = useFormState(initialData);
```

**❌ 避免**: 分散的状态定义
```typescript
const form = ref({...});
const isSubmitting = ref(false);
const error1 = ref('');
const error2 = ref('');
// ...
```

---

## 🎨 样式规范

### 1. 使用 CSS 变量

**✅ 推荐**:
```css
.custom-element {
  margin-bottom: var(--modal-form-row-spacing);
  padding: var(--modal-form-control-padding);
}
```

**❌ 避免**:
```css
.custom-element {
  margin-bottom: 0.75rem;  /* 硬编码值 */
  padding: 0.5rem 0.75rem;
}
```

### 2. 统一的类名前缀

**✅ 推荐**:
```vue
<div class="modal-form-row">
  <label class="modal-form-label">...</label>
  <input class="modal-form-control" />
</div>
```

**❌ 避免**:
```vue
<div class="row">  <!-- 太通用 -->
  <label class="label">...</label>
  <input class="input" />
</div>
```

### 3. 响应式设计

**✅ 推荐**: 使用媒体查询
```css
@media (max-width: 768px) {
  .modal-form-label {
    width: var(--modal-form-label-width-mobile);
  }
}
```

---

## 💻 代码规范

### 1. TypeScript 类型定义

**✅ 推荐**:
```typescript
interface FormData {
  name: string;
  type: AccountType;
  balance: number;
}

interface Props {
  account: Account | null;
  readonly?: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [data: FormData];
}>();
```

**❌ 避免**:
```typescript
const props = defineProps({
  account: Object,  // 缺少类型
  readonly: Boolean,
});
```

### 2. 表单验证

**✅ 推荐**: 使用 Zod Schema
```typescript
import { z } from 'zod';

const FormSchema = z.object({
  name: z.string().min(2).max(20),
  amount: z.number().min(0),
});

function validateForm() {
  try {
    FormSchema.parse(form.value);
    return true;
  } catch (error) {
    if (error instanceof z.ZodError) {
      // 处理验证错误
    }
    return false;
  }
}
```

**❌ 避免**: 手动验证
```typescript
function validateForm() {
  if (form.value.name.length < 2) {
    errors.name = '名称太短';
    return false;
  }
  // ...
}
```

### 3. 异步操作处理

**✅ 推荐**:
```typescript
async function handleSubmit() {
  if (isSubmitting.value) return;  // 防重复提交

  isSubmitting.value = true;
  try {
    await saveData(form.value);
    emit('close');
  } catch (error) {
    handleError(error);
  } finally {
    isSubmitting.value = false;
  }
}
```

**❌ 避免**:
```typescript
function handleSubmit() {
  saveData(form.value);  // 没有错误处理
  emit('close');
}
```

---

## 🔧 功能实现

### 1. 模态框标题

**✅ 推荐**: 使用计算属性
```typescript
const modalTitle = computed(() => {
  return props.data 
    ? t('edit.title') 
    : t('create.title');
});
```

**❌ 避免**: 使用函数
```typescript
function getModalTitle() {
  return props.data ? 'Edit' : 'Create';
}
```

### 2. 表单初始化

**✅ 推荐**: 使用工具函数
```typescript
// utils/formUtils.ts
export function initializeForm<T>(
  data: T | null,
  defaultValues: T
): T {
  return data 
    ? { ...defaultValues, ...data }
    : { ...defaultValues };
}

// 在组件中使用
const form = ref(initializeForm(props.account, defaultAccount));
```

**❌ 避免**: 直接赋值
```typescript
const form = ref(props.account || {
  name: '',
  type: 'BankSavings',
  // ...
});
```

### 3. 数据提交

**✅ 推荐**: 区分创建和更新
```typescript
async function handleSubmit() {
  const data = prepareFormData(form.value);
  
  if (props.account) {
    emit('update', props.account.serialNum, data);
  } else {
    emit('save', data);
  }
}
```

**❌ 避免**: 混合逻辑
```typescript
function handleSubmit() {
  if (props.account) {
    // 更新逻辑
  } else {
    // 创建逻辑
  }
  // 重复代码...
}
```

---

## 🎭 用户体验

### 1. 加载状态

**✅ 推荐**: 显示加载状态
```vue
<BaseModal
  :title="modalTitle"
  :confirm-loading="isSubmitting"
  :confirm-disabled="!isFormValid"
>
  <!-- 内容 -->
</BaseModal>
```

### 2. 错误提示

**✅ 推荐**: 实时验证和友好提示
```vue
<FormRow 
  label="账户名称" 
  required 
  :error="errors.name"
  help-text="2-20个字符"
>
  <input 
    v-model="form.name" 
    class="modal-form-control"
    @blur="validateName"
  />
</FormRow>
```

### 3. 键盘快捷键

**✅ 推荐**: 支持 ESC 关闭
```typescript
// BaseModal 已自动处理
// 无需额外代码
```

### 4. 焦点管理

**✅ 推荐**: 自动聚焦第一个输入框
```vue
<input 
  ref="firstInput"
  v-model="form.name" 
  class="modal-form-control"
  autofocus
/>
```

---

## 📱 响应式设计

### 1. 移动端适配

**✅ 推荐**: 使用响应式布局
```css
@media (max-width: 768px) {
  .modal-form-label {
    width: 4rem;
    font-size: 0.8rem;
  }
  
  .modal-form-control {
    flex: 1;
  }
}
```

### 2. 触摸优化

**✅ 推荐**: 增大触摸区域
```css
@media (max-width: 768px) {
  .modal-form-control {
    min-height: 44px;  /* iOS 推荐最小触摸尺寸 */
  }
  
  button {
    min-height: 44px;
    min-width: 44px;
  }
}
```

---

## 🧪 测试规范

### 1. 单元测试

**✅ 推荐**:
```typescript
describe('AccountModal', () => {
  it('should validate form correctly', () => {
    const { validateForm } = useAccountForm();
    expect(validateForm({ name: 'A' })).toBe(false);
    expect(validateForm({ name: 'Valid Name' })).toBe(true);
  });

  it('should emit save event with correct data', async () => {
    const wrapper = mount(AccountModal);
    await wrapper.vm.handleSubmit();
    expect(wrapper.emitted('save')).toBeTruthy();
  });
});
```

### 2. 集成测试

**✅ 推荐**:
```typescript
describe('AccountModal Integration', () => {
  it('should create account successfully', async () => {
    const wrapper = mount(AccountModal);
    await wrapper.find('input[name="name"]').setValue('Test Account');
    await wrapper.find('form').trigger('submit');
    
    expect(mockApi.createAccount).toHaveBeenCalled();
  });
});
```

---

## 📊 性能优化

### 1. 懒加载

**✅ 推荐**:
```typescript
const HeavyComponent = defineAsyncComponent(() =>
  import('./HeavyComponent.vue')
);
```

### 2. 计算属性缓存

**✅ 推荐**:
```typescript
const filteredOptions = computed(() => {
  return options.value.filter(o => o.isActive);
});
```

**❌ 避免**: 在模板中计算
```vue
<!-- 每次渲染都会重新计算 -->
<div v-for="item in options.filter(o => o.isActive)">
```

### 3. 防抖和节流

**✅ 推荐**:
```typescript
import { useDebounceFn } from '@vueuse/core';

const debouncedSearch = useDebounceFn((query: string) => {
  performSearch(query);
}, 300);
```

---

## 🔒 安全规范

### 1. XSS 防护

**✅ 推荐**: 使用 Vue 的自动转义
```vue
<div>{{ userInput }}</div>  <!-- 自动转义 -->
```

**❌ 避免**: 使用 v-html
```vue
<div v-html="userInput"></div>  <!-- 危险！ -->
```

### 2. 输入验证

**✅ 推荐**: 前后端双重验证
```typescript
// 前端验证
const FormSchema = z.object({
  amount: z.number().min(0).max(999999),
});

// 后端也需要验证
```

---

## 📚 文档规范

### 1. 组件文档

**✅ 推荐**:
```vue
<script setup lang="ts">
/**
 * AccountModal 组件
 * 
 * 用于创建和编辑账户信息
 * 
 * @example
 * <AccountModal 
 *   :account="selectedAccount"
 *   @save="handleSave"
 *   @close="closeModal"
 * />
 */

interface Props {
  /** 账户数据（编辑模式） */
  account: Account | null;
  /** 是否只读 */
  readonly?: boolean;
}
</script>
```

### 2. 函数文档

**✅ 推荐**:
```typescript
/**
 * 验证表单数据
 * 
 * @param data - 表单数据
 * @returns 验证是否通过
 * @throws {ZodError} 验证失败时抛出
 */
function validateForm(data: FormData): boolean {
  // ...
}
```

---

## 🎯 检查清单

### 开发前

- [ ] 了解 BaseModal 的使用方法
- [ ] 了解 FormRow 组件的 API
- [ ] 了解共享样式的类名
- [ ] 准备好类型定义

### 开发中

- [ ] 使用 BaseModal 组件
- [ ] 使用 FormRow 组件
- [ ] 使用共享样式类
- [ ] 添加 TypeScript 类型
- [ ] 实现表单验证
- [ ] 处理加载状态
- [ ] 添加错误提示
- [ ] 支持响应式布局

### 开发后

- [ ] 测试所有功能
- [ ] 测试响应式布局
- [ ] 测试错误处理
- [ ] 检查代码质量
- [ ] 添加组件文档
- [ ] Code Review

---

## 📖 参考资源

- [Modal 表单样式规范](./MODAL_FORM_STYLE_GUIDE.md)
- [Modal 表单迁移指南](./MODAL_FORM_MIGRATION_GUIDE.md)
- [BaseModal API 文档](../components/BASE_MODAL_API.md)
- [FormRow API 文档](../components/FORM_ROW_API.md)

---

**创建日期**: 2025-11-21  
**最后更新**: 2025-11-21  
**维护者**: Miji Development Team
