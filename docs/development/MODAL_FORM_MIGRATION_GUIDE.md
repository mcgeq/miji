# Modal 表单迁移指南

## 📋 目的

指导开发者如何使用新的共享样式和 FormRow 组件来优化现有的 Modal 表单。

---

## 🎯 迁移收益

### 代码简化

**迁移前**:
```vue
<template>
  <div class="form-row">
    <label class="form-label">
      账户名称
      <span class="required-asterisk">*</span>
    </label>
    <input v-model="form.name" class="form-control" />
  </div>
  <div v-if="errors.name" class="form-error">{{ errors.name }}</div>
</template>

<style scoped>
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.form-label {
  font-size: 0.875rem;
  font-weight: 500;
  width: 6rem;
  /* ... 更多样式 */
}

.form-control {
  width: 66%;
  padding: 0.5rem 0.75rem;
  /* ... 更多样式 */
}

.form-error {
  color: var(--color-error);
  /* ... 更多样式 */
}
</style>
```

**迁移后**:
```vue
<script setup lang="ts">
import FormRow from '@/components/common/FormRow.vue';
</script>

<template>
  <FormRow label="账户名称" required :error="errors.name">
    <input v-model="form.name" class="modal-form-control" />
  </FormRow>
</template>

<style scoped>
/* 无需自定义样式，使用共享样式 */
@import '@/assets/styles/modal-forms.css';
</style>
```

**减少代码**: 约 70%  
**提升可维护性**: ⭐⭐⭐⭐⭐

---

## 📝 迁移步骤

### 步骤 1: 引入共享样式

在 Modal 组件的 `<style>` 标签中引入共享样式：

```vue
<style scoped>
@import '@/assets/styles/modal-forms.css';

/* 只保留组件特定的样式 */
</style>
```

### 步骤 2: 引入 FormRow 组件

```vue
<script setup lang="ts">
import FormRow from '@/components/common/FormRow.vue';
// ... 其他导入
</script>
```

### 步骤 3: 替换表单行

**原始代码**:
```vue
<div class="form-row">
  <label>字段名</label>
  <input v-model="form.field" class="form-control" />
</div>
```

**替换为**:
```vue
<FormRow label="字段名">
  <input v-model="form.field" class="modal-form-control" />
</FormRow>
```

### 步骤 4: 添加验证和帮助文本

```vue
<FormRow 
  label="账户名称" 
  required 
  :error="errors.name"
  help-text="请输入2-20个字符"
>
  <input v-model="form.name" class="modal-form-control" />
</FormRow>
```

### 步骤 5: 删除重复的样式

删除以下样式（已在共享样式中定义）:
- `.form-row`
- `.form-label`
- `.form-control`
- `.form-error`
- `.required-asterisk`
- `.optional-text`

---

## 📚 使用示例

### 1. 基础输入框

```vue
<FormRow label="账户名称" required>
  <input 
    v-model="form.name" 
    class="modal-form-control"
    placeholder="请输入账户名称"
  />
</FormRow>
```

### 2. 带验证的输入框

```vue
<FormRow 
  label="金额" 
  required 
  :error="errors.amount"
>
  <input 
    v-model.number="form.amount" 
    type="number"
    class="modal-form-control"
    placeholder="0.00"
  />
</FormRow>
```

### 3. 选择框

```vue
<FormRow label="账户类型" required>
  <select v-model="form.type" class="modal-form-control">
    <option value="">请选择</option>
    <option value="BankSavings">银行储蓄</option>
    <option value="Cash">现金</option>
  </select>
</FormRow>
```

### 4. 文本域

```vue
<FormRow label="备注" optional>
  <textarea 
    v-model="form.description" 
    class="modal-form-control"
    rows="3"
    placeholder="请输入备注（可选）"
  />
</FormRow>
```

### 5. 复选框

```vue
<FormRow label="共享账户">
  <div class="modal-form-checkbox">
    <input 
      v-model="form.isShared" 
      type="checkbox"
      id="isShared"
    />
    <label for="isShared">允许其他成员查看</label>
  </div>
</FormRow>
```

### 6. 自定义组件

```vue
<FormRow label="币种" required>
  <CurrencySelector v-model="form.currency" />
</FormRow>
```

### 7. 带帮助文本

```vue
<FormRow 
  label="初始余额" 
  help-text="账户的初始金额"
>
  <input 
    v-model.number="form.initialBalance" 
    type="number"
    class="modal-form-control"
  />
</FormRow>
```

### 8. 全宽布局

```vue
<FormRow label="详细描述" full-width>
  <textarea 
    v-model="form.description" 
    class="modal-form-control modal-form-full-width"
    rows="5"
  />
</FormRow>
```

---

## 🔄 迁移对比

### AccountModal 示例

**迁移前** (约 50 行):
```vue
<template>
  <BaseModal ...>
    <form>
      <div class="form-row">
        <label class="form-label">
          账户名称
          <span class="required-asterisk">*</span>
        </label>
        <input v-model="form.name" class="form-control" />
      </div>
      <span v-if="errors.name" class="form-error">{{ errors.name }}</span>

      <div class="form-row">
        <label class="form-label">账户类型</label>
        <select v-model="form.type" class="form-control">
          <option value="BankSavings">银行储蓄</option>
        </select>
      </div>

      <div class="form-row">
        <label class="form-label">
          初始余额
          <span class="optional-text">(可选)</span>
        </label>
        <input v-model="form.balance" class="form-control" />
      </div>
    </form>
  </BaseModal>
</template>

<style scoped>
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
}

.form-label {
  font-size: 0.875rem;
  font-weight: 500;
  width: 6rem;
  min-width: 6rem;
}

.form-control {
  width: 66%;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  /* ... 更多样式 */
}

.form-error {
  font-size: 0.875rem;
  color: var(--color-error);
  text-align: right;
}

.required-asterisk {
  color: var(--color-error);
}

.optional-text {
  color: var(--color-neutral);
  font-size: 0.75rem;
}
</style>
```

**迁移后** (约 20 行):
```vue
<script setup lang="ts">
import FormRow from '@/components/common/FormRow.vue';
// ... 其他导入
</script>

<template>
  <BaseModal ...>
    <form>
      <FormRow label="账户名称" required :error="errors.name">
        <input v-model="form.name" class="modal-form-control" />
      </FormRow>

      <FormRow label="账户类型">
        <select v-model="form.type" class="modal-form-control">
          <option value="BankSavings">银行储蓄</option>
        </select>
      </FormRow>

      <FormRow label="初始余额" optional>
        <input v-model="form.balance" class="modal-form-control" />
      </FormRow>
    </form>
  </BaseModal>
</template>

<style scoped>
@import '@/assets/styles/modal-forms.css';
/* 无需额外样式 */
</style>
```

**改进**:
- ✅ 代码减少 60%
- ✅ 样式统一
- ✅ 更易维护
- ✅ 更好的可读性

---

## ⚠️ 注意事项

### 1. 类名变更

| 旧类名 | 新类名 |
|--------|--------|
| `.form-row` | `.modal-form-row` |
| `.form-label` | `.modal-form-label` |
| `.form-control` | `.modal-form-control` |
| `.form-error` | `.modal-form-error` |
| `.form-display` | `.modal-form-display` |

### 2. 保留特殊样式

某些组件特定的样式仍需保留，例如：
- 分期付款相关样式
- 费用分摊相关样式
- 特殊布局样式

### 3. 渐进式迁移

不需要一次性迁移所有组件，可以：
1. 先迁移新创建的 Modal
2. 逐步迁移现有 Modal
3. 保持向后兼容

---

## 🎯 迁移优先级

### 高优先级 (建议立即迁移)

- [ ] 新创建的 Modal 组件
- [ ] 频繁修改的 Modal 组件
- [ ] 样式不一致的 Modal 组件

### 中优先级 (逐步迁移)

- [ ] AccountModal
- [ ] BudgetModal
- [ ] ReminderModal
- [ ] TransactionModal (部分已优化)

### 低优先级 (可选迁移)

- [ ] 很少修改的 Modal 组件
- [ ] 有特殊样式需求的 Modal 组件

---

## 📊 迁移检查清单

### 迁移前

- [ ] 备份原始代码
- [ ] 了解组件的特殊需求
- [ ] 检查是否有自定义样式需要保留

### 迁移中

- [ ] 引入共享样式文件
- [ ] 引入 FormRow 组件
- [ ] 替换表单行结构
- [ ] 更新类名
- [ ] 删除重复样式

### 迁移后

- [ ] 测试所有表单功能
- [ ] 检查样式是否正确
- [ ] 验证响应式布局
- [ ] 测试错误提示显示
- [ ] 测试必填/可选标记

---

## 🔧 故障排除

### 问题 1: 样式不生效

**原因**: 未正确引入共享样式

**解决方案**:
```vue
<style scoped>
@import '@/assets/styles/modal-forms.css';
</style>
```

### 问题 2: 布局错乱

**原因**: 旧类名和新类名混用

**解决方案**: 统一使用新类名 `modal-form-*`

### 问题 3: FormRow 不显示

**原因**: 未正确导入组件

**解决方案**:
```typescript
import FormRow from '@/components/common/FormRow.vue';
```

### 问题 4: 自定义样式被覆盖

**原因**: 样式优先级问题

**解决方案**: 使用更具体的选择器或 `!important`

---

## 📚 参考资源

- [Modal 表单样式规范](./MODAL_FORM_STYLE_GUIDE.md)
- [FormRow 组件 API](../components/FORM_ROW_API.md)
- [共享样式文件](../../src/assets/styles/modal-forms.css)

---

**创建日期**: 2025-11-21  
**最后更新**: 2025-11-21  
**维护者**: Miji Development Team
