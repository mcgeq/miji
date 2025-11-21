# AccountModal 迁移指南

## 📋 迁移概述

将 `AccountModal.vue` 从自定义模态框迁移到使用 `BaseModal` 和 `useFormValidation`。

---

## 🔄 主要变更

### 1. 导入变更

**旧代码**:
```typescript
import { useI18n } from 'vue-i18n';
import ColorSelector from '@/components/common/ColorSelector.vue';
```

**新代码**:
```typescript
import BaseModal from '@/components/common/BaseModal.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import { useFormValidation } from '@/composables/useFormValidation';
```

### 2. 移除 formErrors，使用 validation

**旧代码**:
```typescript
const formErrors = ref<Record<string, string>>({});
```

**新代码**:
```typescript
const validation = useFormValidation(
  props.account ? UpdateAccountRequestSchema : CreateAccountRequestSchema
);
```

### 3. 更新验证逻辑

**旧代码**:
```typescript
const schemaToUse = isUpdate ? UpdateAccountRequestSchema : CreateAccountRequestSchema;
const validationRequest = schemaToUse.safeParse(requestData);

if (!validationRequest.success) {
  toast.error('数据校验失败');
  Lg.e('AccountModal', validationRequest.error);
  isSubmitting.value = false;
  return;
}
```

**新代码**:
```typescript
// 使用 useFormValidation 验证
if (!validation.validateAll(requestData as any)) {
  toast.error(t('financial.account.validationFailed'));
  return;
}
```

### 4. 模板结构变更

**旧代码**:
```vue
<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="mb-4 flex items-center justify-between">
        <h3>{{ props.account ? '编辑账户' : '添加账户' }}</h3>
        <button @click="closeModal">×</button>
      </div>
      <form @submit.prevent="saveAccount">
        <!-- 表单内容 -->
        <div class="modal-actions">
          <button type="button" @click="closeModal">取消</button>
          <button type="submit">保存</button>
        </div>
      </form>
    </div>
  </div>
</template>
```

**新代码**:
```vue
<template>
  <BaseModal
    :title="props.account ? t('financial.account.editAccount') : t('financial.account.addAccount')"
    size="lg"
    :confirm-text="props.account ? t('common.actions.update') : t('common.actions.create')"
    :confirm-loading="isSubmitting"
    :confirm-disabled="validation.hasAnyError"
    @close="closeModal"
    @confirm="saveAccount"
  >
    <form @submit.prevent="saveAccount">
      <!-- 表单内容 -->
    </form>
  </BaseModal>
</template>
```

### 5. 错误显示变更

**旧代码**:
```vue
<span v-if="formErrors.name" class="form-error">
  {{ formErrors.name }}
</span>
```

**新代码**:
```vue
<span v-if="validation.shouldShowError('name')" class="form-error">
  {{ validation.getError('name') }}
</span>
```

---

## 📝 完整迁移步骤

### 步骤 1: 更新 Script 部分

1. 添加 BaseModal 和 useFormValidation 导入
2. 移除 formErrors
3. 添加 validation 实例
4. 更新 saveAccount 函数

### 步骤 2: 更新 Template 部分

1. 替换 `<div class="modal-mask">` 为 `<BaseModal>`
2. 移除自定义的头部和关闭按钮
3. 移除自定义的底部按钮
4. 更新所有 `formErrors.xxx` 为 `validation.shouldShowError('xxx')`
5. 更新所有错误消息显示为 `validation.getError('xxx')`

### 步骤 3: 添加字段验证

为每个输入字段添加 `@blur` 事件：

```vue
<input
  v-model="form.name"
  @blur="validation.touchField('name'); validation.validateField('name', form.name)"
/>
```

### 步骤 4: 测试

- [ ] 创建账户功能正常
- [ ] 编辑账户功能正常
- [ ] 表单验证正常
- [ ] 错误提示正常显示
- [ ] 关闭模态框正常
- [ ] 提交按钮状态正确

---

## 🎯 预期收益

| 指标 | 改进 |
|------|------|
| 代码行数 | -80 行 |
| 模板复杂度 | -40% |
| 验证逻辑 | 统一 |
| 错误处理 | 改善 |
| 可维护性 | +60% |

---

## ⚠️ 注意事项

### 1. Currency 类型问题

原代码中 currency 缺少 `isDefault` 和 `isActive` 字段，需要修复：

```typescript
// 旧代码
form.currency = {
  locale: 'zh-CN',
  code: 'CNY',
  symbol: '¥',
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
};

// 新代码
form.currency = {
  locale: 'zh-CN',
  code: 'CNY',
  symbol: '¥',
  isDefault: true,
  isActive: true,
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
};
```

### 2. 验证 Schema 选择

根据是否为编辑模式选择不同的 Schema：

```typescript
const validation = useFormValidation(
  props.account ? UpdateAccountRequestSchema : CreateAccountRequestSchema
);
```

### 3. 字段触摸状态

确保在用户交互后标记字段为已触摸：

```typescript
@blur="validation.touchField('name')"
```

---

## 🔗 相关资源

- [BaseModal 使用指南](./BASE_MODAL_GUIDE.md)
- [useFormValidation 文档](./FORM_VALIDATION_GUIDE.md)
- [重构进度](./REFACTORING_PROGRESS.md)

---

## 📞 需要帮助？

如有问题，请参考：
1. AccountModalRefactored.vue (示例实现)
2. BaseModal 使用指南
3. 联系开发团队
