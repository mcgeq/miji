# Modal 表单样式规范

## 📋 目的

统一所有 Modal 组件的表单样式，提高代码可维护性和用户体验一致性。

---

## 🎨 统一样式规范

### 1. 表单行间距

**规范**: 所有 Modal 组件的 `.form-row` 使用统一的 `margin-bottom`

```css
.form-row {
  margin-bottom: 0.75rem;  /* 统一间距：12px */
  display: flex;
  align-items: center;
  justify-content: space-between;
}
```

**适用组件**:
- ✅ TransactionModal
- ✅ AccountModal
- ✅ BudgetModal
- ✅ ReminderModal
- ✅ FamilyLedgerModal
- ✅ FamilyMemberModal

**历史变更**:
- 2025-11-21: 统一从 `0.5rem` 改为 `0.75rem`
- TransactionModal 从 `0.05rem` 改为 `0.75rem`（修复间距过小问题）

---

### 2. 标签样式

**规范**: 统一的标签样式

```css
.form-label {
  font-size: 0.875rem;      /* 14px */
  font-weight: 500;
  color: var(--color-base-content);
  margin-bottom: 0;
  flex: 0 0 auto;
  width: 6rem;              /* 固定宽度 */
  min-width: 6rem;
  white-space: nowrap;
}
```

**适用场景**:
- 所有表单标签
- 保持标签宽度一致
- 防止标签换行

---

### 3. 输入控件样式

**规范**: 统一的输入框样式

```css
.form-control,
.modal-input-select {
  width: 66%;                           /* 占据剩余空间的 2/3 */
  padding: 0.5rem 0.75rem;             /* 8px 12px */
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;             /* 6px */
  background-color: var(--color-base-200);
  color: var(--color-base-content);
  font-size: 0.875rem;
  transition: all 0.2s ease;
}

.form-control:focus {
  outline: none;
  border-color: var(--color-primary);
  background-color: var(--color-base-100);
  box-shadow: 0 0 0 3px oklch(from var(--color-primary) l c h / 0.1);
}

.form-control:disabled {
  background-color: var(--color-base-300);
  color: var(--color-neutral);
  cursor: not-allowed;
}
```

---

### 4. BaseModal 尺寸

**规范**: 统一使用 `size="md"`

```vue
<BaseModal
  :title="..."
  size="md"
  :confirm-loading="isSubmitting"
  @close="..."
  @confirm="..."
>
  <!-- 表单内容 -->
</BaseModal>
```

**尺寸说明**:
- `size="sm"`: 小尺寸（简单确认对话框）
- `size="md"`: 中等尺寸（**标准表单，推荐使用**）
- `size="lg"`: 大尺寸（复杂表单，谨慎使用）
- `size="xl"`: 超大尺寸（特殊场景）

**适用组件**:
- ✅ TransactionModal: `size="md"`
- ✅ AccountModal: `size="md"`
- ✅ BudgetModal: `size="md"`
- ✅ ReminderModal: `size="md"`

---

### 5. 响应式布局

**规范**: 移动端自适应

```css
@media (max-width: 768px) {
  .form-row {
    flex-direction: row;      /* 保持水平布局 */
    align-items: center;
    gap: 0.5rem;
  }

  .form-row label {
    flex: 0 0 auto;
    min-width: 4rem;
    width: 4rem;              /* 移动端缩小标签宽度 */
    font-size: 0.8rem;
  }

  .form-control {
    flex: 1;
    min-width: 0;
  }
}
```

---

## 📝 实施清单

### 已完成 ✅

- [x] TransactionModal - 间距从 0.05rem 改为 0.75rem
- [x] AccountModal - 间距从 0.5rem 改为 0.75rem
- [x] BudgetModal - 间距从 0.5rem 改为 0.75rem
- [x] ReminderModal - 间距从 0.5rem 改为 0.75rem
- [x] TransactionModal - 尺寸从 lg 改为 md

### 待优化 ⏳

- [ ] 创建共享的 CSS 变量文件
- [ ] 提取公共样式到 `@/styles/modal-forms.css`
- [ ] 使用 CSS 自定义属性统一管理间距
- [ ] 添加暗色模式支持

---

## 🔧 最佳实践

### 1. 使用共享样式类

**推荐**: 使用统一的类名

```vue
<template>
  <BaseModal size="md" ...>
    <form>
      <!-- 标准表单行 -->
      <div class="form-row">
        <label class="form-label">字段名</label>
        <input class="form-control" />
      </div>
    </form>
  </BaseModal>
</template>
```

### 2. 避免自定义间距

**❌ 不推荐**:
```css
.form-row {
  margin-bottom: 0.3rem;  /* 自定义值 */
}
```

**✅ 推荐**:
```css
.form-row {
  margin-bottom: 0.75rem;  /* 使用统一值 */
}
```

### 3. 使用 CSS 变量

**未来改进**:
```css
:root {
  --form-row-spacing: 0.75rem;
  --form-label-width: 6rem;
  --form-control-width: 66%;
}

.form-row {
  margin-bottom: var(--form-row-spacing);
}
```

---

## 📊 对比效果

### 重构前

| 组件 | margin-bottom | 视觉效果 |
|------|--------------|---------|
| TransactionModal | 0.05rem | ❌ 太紧凑 |
| AccountModal | 0.5rem | ⚠️ 一般 |
| BudgetModal | 0.5rem | ⚠️ 一般 |
| ReminderModal | 0.5rem | ⚠️ 一般 |

### 重构后

| 组件 | margin-bottom | 视觉效果 |
|------|--------------|---------|
| TransactionModal | 0.75rem | ✅ 舒适 |
| AccountModal | 0.75rem | ✅ 舒适 |
| BudgetModal | 0.75rem | ✅ 舒适 |
| ReminderModal | 0.75rem | ✅ 舒适 |

**改进**:
- ✅ 视觉一致性提升
- ✅ 用户体验改善
- ✅ 维护成本降低

---

## 🎯 未来优化方向

### 1. 提取共享样式

创建 `src/styles/modal-forms.css`:

```css
/* Modal 表单共享样式 */
.modal-form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.modal-form-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
  width: 6rem;
  min-width: 6rem;
  white-space: nowrap;
}

.modal-form-control {
  width: 66%;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background-color: var(--color-base-200);
  color: var(--color-base-content);
  font-size: 0.875rem;
  transition: all 0.2s ease;
}
```

### 2. 使用 Tailwind CSS 工具类

如果项目使用 Tailwind CSS:

```vue
<div class="flex items-center justify-between mb-3">
  <label class="text-sm font-medium w-24 min-w-24 whitespace-nowrap">
    字段名
  </label>
  <input class="w-2/3 px-3 py-2 border rounded-md bg-base-200" />
</div>
```

### 3. 组件化表单行

创建 `FormRow.vue` 组件:

```vue
<template>
  <div class="form-row">
    <label class="form-label">{{ label }}</label>
    <slot />
  </div>
</template>

<script setup lang="ts">
defineProps<{
  label: string;
}>();
</script>
```

使用:
```vue
<FormRow label="账户名称">
  <input v-model="form.name" class="form-control" />
</FormRow>
```

---

## 📚 相关文档

- [BaseModal 使用指南](./BASE_MODAL_GUIDE.md)
- [TransactionModal 重构总结](./TRANSACTION_MODAL_REFACTORING_COMPLETE.md)
- [Modal 组件重构总结](./MODAL_COMPONENTS_REFACTORING.md)

---

## 🔄 变更日志

### 2025-11-21

**统一表单间距**:
- TransactionModal: 0.05rem → 0.75rem
- AccountModal: 0.5rem → 0.75rem
- BudgetModal: 0.5rem → 0.75rem
- ReminderModal: 0.5rem → 0.75rem

**统一模态框尺寸**:
- TransactionModal: lg → md

**原因**: 提高视觉一致性和用户体验

---

**创建日期**: 2025-11-21  
**最后更新**: 2025-11-21  
**维护者**: Miji Development Team
