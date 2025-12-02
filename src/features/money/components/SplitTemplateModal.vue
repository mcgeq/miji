<script setup lang="ts">
import { Checkbox, FormRow, Input, Modal, Textarea } from '@/components/ui';
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
  <Modal
    :open="true"
    :title="mode === 'create' ? '创建模板' : '编辑模板'"
    size="md"
    :confirm-loading="isSubmitting"
    @close="close"
    @confirm="save"
  >
    <form @submit.prevent="save">
      <!-- 模板名称 -->
      <FormRow label="模板名称" required :error="errors.name">
        <Input
          v-model="form.name"
          type="text"
          placeholder="例如：家庭日常开销"
        />
        <span class="block mt-1 text-xs text-gray-500 dark:text-gray-400">{{ form.name.length }}/50</span>
      </FormRow>

      <!-- 模板描述 -->
      <FormRow full-width>
        <Textarea
          v-model="form.description"
          placeholder="描述此模板的使用场景（可选）"
          :rows="3"
          :max-length="200"
        />
        <span class="block mt-1 text-xs text-gray-500 dark:text-gray-400">{{ form.description.length }}/200</span>
      </FormRow>

      <!-- 分摊类型 -->
      <FormRow label="分摊类型" required>
        <div class="grid grid-cols-2 md:grid-cols-2 gap-3">
          <label
            v-for="type in ['EQUAL', 'PERCENTAGE', 'FIXED_AMOUNT', 'WEIGHTED'] as SplitRuleType[]"
            :key="type"
            class="px-3 py-2 border-2 rounded-lg text-center cursor-pointer transition-all" :class="[
              form.ruleType === type
                ? 'border-blue-600 dark:border-blue-500 bg-blue-600 dark:bg-blue-500 text-white'
                : 'border-gray-200 dark:border-gray-600 hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/10 text-gray-900 dark:text-white',
            ]"
          >
            <input
              v-model="form.ruleType"
              type="radio"
              :value="type"
              hidden
            >
            <span class="text-sm font-medium">{{ getTypeName(type) }}</span>
          </label>
        </div>
      </FormRow>

      <!-- 设为默认 -->
      <div class="mb-3">
        <Checkbox
          v-model="form.isDefault"
          label="设为默认模板"
        />
        <p class="text-xs text-gray-500 dark:text-gray-400 mt-1 ml-6">
          新建交易时自动应用此模板
        </p>
      </div>
    </form>
  </Modal>
</template>
