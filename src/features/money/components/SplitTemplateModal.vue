<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import FormRow from '@/components/common/FormRow.vue';
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
      <FormRow label="模板名称" required :error="errors.name">
        <input
          v-model="form.name"
          v-has-value
          type="text"
          class="modal-input-select w-full"
          :class="{ 'border-red-500': errors.name }"
          placeholder="例如：家庭日常开销"
          maxlength="50"
        >
        <span class="form-hint">{{ form.name.length }}/50</span>
      </FormRow>

      <!-- 模板描述 -->
      <FormRow label="模板描述" optional>
        <textarea
          v-model="form.description"
          class="modal-input-select w-full"
          placeholder="描述此模板的使用场景（可选）"
          rows="3"
          maxlength="200"
        />
        <span class="form-hint">{{ form.description.length }}/200</span>
      </FormRow>

      <!-- 分摇类型 -->
      <FormRow label="分摇类型" required>
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
      </FormRow>

      <!-- 设为默认 -->
      <FormRow label="" optional>
        <label class="checkbox-label">
          <input
            v-model="form.isDefault"
            type="checkbox"
            class="checkbox-input"
          >
          <span class="checkbox-text">设为默认模板</span>
          <span class="checkbox-hint">新建交易时自动应用此模板</span>
        </label>
      </FormRow>
    </form>
  </BaseModal>
</template>

<style scoped>
/* 表单提示文字 */
.form-hint {
  display: block;
  margin-top: 0.25rem;
  font-size: 0.75rem;
  color: var(--color-neutral);
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
  gap: 0.25rem;
  cursor: pointer;
}

.checkbox-input {
  width: 18px;
  height: 18px;
  cursor: pointer;
  margin-right: 0.5rem;
}

.checkbox-text {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.checkbox-hint {
  font-size: 0.75rem;
  color: var(--color-neutral);
  margin-left: 1.5rem;
}

/* Responsive */
@media (max-width: 768px) {
  .type-selector {
    grid-template-columns: 1fr;
  }
}
</style>
