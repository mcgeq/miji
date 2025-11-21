<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import type { SplitRuleType } from '@/schema/money';

interface Props {
  template?: any;
  mode?: 'create' | 'edit';
}

const props = withDefaults(defineProps<Props>(), {
  mode: 'create',
});

const emit = defineEmits<{
  close: [];
  save: [template: any];
}>();

const isSubmitting = ref(false);

// 表单数据
const form = reactive({
  name: '',
  description: '',
  ruleType: 'EQUAL' as SplitRuleType,
  isDefault: false,
});

// 验证错误
const errors = reactive({
  name: '',
});

// 初始化
onMounted(() => {
  if (props.template) {
    Object.assign(form, {
      name: props.template.name || '',
      description: props.template.description || '',
      ruleType: props.template.ruleType || 'EQUAL',
      isDefault: props.template.isDefault || false,
    });
  }
});

// 验证表单
function validateForm(): boolean {
  errors.name = '';

  if (!form.name.trim()) {
    errors.name = '请输入模板名称';
    return false;
  }

  if (form.name.length > 50) {
    errors.name = '模板名称不能超过50个字符';
    return false;
  }

  return true;
}

// 保存
function save() {
  if (!validateForm()) {
    return;
  }

  emit('save', {
    ...form,
    serialNum: props.template?.serialNum,
  });
}

// 关闭
function close() {
  emit('close');
}

// 获取类型名称
function getTypeName(type: SplitRuleType): string {
  const typeMap: Record<SplitRuleType, string> = {
    EQUAL: '均摊',
    PERCENTAGE: '按比例',
    FIXED_AMOUNT: '固定金额',
    WEIGHTED: '按权重',
  };
  return typeMap[type] || type;
}
</script>

<template>
  <BaseModal
    :title="mode === 'create' ? '创建模板' : '编辑模板'"
    size="md"
    :confirm-loading="isSubmitting"
    @close="close"
    @confirm="save"
  >
    <form @submit.prevent="save">
      <!-- 模板名称 -->
      <div class="form-group">
        <label class="form-label required">模板名称</label>
        <input
          v-model="form.name"
          type="text"
          class="form-input"
          :class="{ error: errors.name }"
          placeholder="例如：家庭日常开销"
          maxlength="50"
        >
        <span v-if="errors.name" class="error-message">{{ errors.name }}</span>
        <span class="form-hint">{{ form.name.length }}/50</span>
      </div>

      <!-- 模板描述 -->
      <div class="form-group">
        <label class="form-label">模板描述</label>
        <textarea
          v-model="form.description"
          class="form-textarea"
          placeholder="描述此模板的使用场景（可选）"
          rows="3"
          maxlength="200"
        />
        <span class="form-hint">{{ form.description.length }}/200</span>
      </div>

      <!-- 分摊类型 -->
      <div class="form-group">
        <label class="form-label required">分摊类型</label>
        <div class="type-selector">
          <label
            v-for="type in ['EQUAL', 'PERCENTAGE', 'FIXED_AMOUNT', 'WEIGHTED'] as SplitRuleType[]"
            :key="type"
            class="type-option"
            :class="{ selected: form.ruleType === type }"
          >
            <input
              v-model="form.ruleType"
              type="radio"
              :value="type"
              hidden
            >
            <span>{{ getTypeName(type) }}</span>
          </label>
        </div>
      </div>

      <!-- 设为默认 -->
      <div class="form-group">
        <label class="checkbox-label">
          <input
            v-model="form.isDefault"
            type="checkbox"
          >
          <span>设为默认模板</span>
          <span class="checkbox-hint">新建交易时自动应用此模板</span>
        </label>
      </div>
    </form>
  </BaseModal>
</template>

<style scoped>
.split-template-modal {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
}

.modal-container {
  position: relative;
  width: 90%;
  max-width: 500px;
  background: white;
  border-radius: 16px;
  box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1);
  display: flex;
  flex-direction: column;
  max-height: 90vh;
}

/* Header */
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem;
  border-bottom: 1px solid var(--color-base-200);
}

.modal-header h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.btn-close {
  padding: 0.5rem;
  background: transparent;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-close:hover {
  background: var(--color-base-200);
}

.btn-close .icon {
  width: 20px;
  height: 20px;
}

/* Content */
.modal-content {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

/* Form */
.form-group {
  margin-bottom: 1.5rem;
}

.form-label {
  display: block;
  margin-bottom: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-700);
}

.form-label.required::after {
  content: '*';
  color: #dc2626;
  margin-left: 0.25rem;
}

.form-input,
.form-textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
  transition: all 0.2s;
}

.form-input:focus,
.form-textarea:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px oklch(from var(--color-primary) l c h / 0.1);
}

.form-input.error {
  border-color: #dc2626;
}

.form-textarea {
  resize: vertical;
  font-family: inherit;
}

.form-hint {
  display: block;
  margin-top: 0.5rem;
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

.error-message {
  display: block;
  margin-top: 0.5rem;
  font-size: 0.75rem;
  color: #dc2626;
}

/* Type Selector */
.type-selector {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 0.75rem;
}

.type-option {
  padding: 0.75rem;
  border: 2px solid var(--color-base-300);
  border-radius: 8px;
  text-align: center;
  cursor: pointer;
  transition: all 0.2s;
}

.type-option:hover {
  border-color: var(--color-primary);
  background: oklch(from var(--color-primary) l c h / 0.05);
}

.type-option.selected {
  border-color: var(--color-primary);
  background: var(--color-primary);
  color: white;
}

.type-option span {
  font-size: 0.875rem;
  font-weight: 500;
}

/* Checkbox */
.checkbox-label {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  cursor: pointer;
}

.checkbox-label input[type="checkbox"] {
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.checkbox-label > span:first-of-type {
  font-size: 0.875rem;
  font-weight: 500;
}

.checkbox-hint {
  font-size: 0.75rem;
  color: var(--color-gray-500);
  margin-left: 1.5rem;
}

/* Footer */
.modal-footer {
  display: flex;
  gap: 1rem;
  padding: 1.5rem;
  border-top: 1px solid var(--color-base-200);
  background: var(--color-base-100);
}

.btn-secondary,
.btn-primary {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-secondary {
  background: white;
  border: 1px solid var(--color-base-300);
  color: var(--color-gray-700);
}

.btn-secondary:hover {
  background: var(--color-base-200);
}

.btn-primary {
  background: var(--color-primary);
  color: white;
}

.btn-primary:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
}

.btn-primary .icon {
  width: 18px;
  height: 18px;
}

/* Responsive */
@media (max-width: 768px) {
  .modal-container {
    width: 100%;
    max-width: 100%;
    height: 100vh;
    max-height: 100vh;
    border-radius: 0;
  }

  .type-selector {
    grid-template-columns: 1fr;
  }
}
</style>
