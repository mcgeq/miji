<script setup lang="ts">
import * as _ from 'es-toolkit/compat';
import z from 'zod';
import BaseModal from '@/components/common/BaseModal.vue';
import { useBudgetForm } from '@/composables/useBudgetForm';
import { BudgetCreateSchema, BudgetUpdateSchema } from '@/schema/money';
import { deepDiff } from '@/utils/diffObject';
import BudgetFormFields from './BudgetFormFields.vue';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';

interface Props {
  budget: Budget | null;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [budget: BudgetCreate];
  update: [serialNum: string, budget: BudgetUpdate];
}>();

const { t } = useI18n();

// 使用共享的表单逻辑
const {
  form,
  colorNameMap,
  categoryError,
  accountError,
  isSubmitting,
  validationErrors,
  scopeTypes,
  isFormValid,
  handleCategoryValidation,
  handleAccountValidation,
  handleRepeatPeriodValidation,
  handleRepeatPeriodChange,
  formatFormData,
} = useBudgetForm(props.budget);

// 提交处理
function onSubmit() {
  if (!isFormValid.value) {
    return;
  }

  try {
    isSubmitting.value = true;

    // 使用共享的格式化函数
    const formattedData = formatFormData();

    if (props.budget) {
      // 编辑模式：计算差异
      const changes = _.omitBy(formattedData, (value: unknown, key: string) =>
        _.isEqual(value, _.get(props.budget, key)));

      // 特殊处理需要序列化为JSON的字段
      const jsonFields = [
        'repeatPeriod',
        'alertThreshold',
        'accountScope',
        'categoryScope',
        'advancedRules',
        'reminders',
        'rolloverHistory',
        'sharingSettings',
        'attachments',
        'tags',
      ];

      const serializedChanges = _.mapValues(changes, (value, key) => {
        if (jsonFields.includes(key) && value !== null && value !== undefined) {
          try {
            return JSON.parse(JSON.stringify(value));
          } catch {
            return value;
          }
        }
        return value;
      });

      if (!_.isEmpty(serializedChanges)) {
        const updatePartial = deepDiff(
          props.budget,
          formattedData,
          { ignoreKeys: ['repeatPeriod'] },
        ) as BudgetUpdate;
        const budgetUpdate = BudgetUpdateSchema.parse(updatePartial);
        emit('update', props.budget.serialNum, budgetUpdate);
      }
    } else {
      // 创建模式
      const budgetCreate = BudgetCreateSchema.parse(formattedData);
      emit('save', budgetCreate);
    }

    closeModal();
  } catch (err: unknown) {
    if (err instanceof z.ZodError) {
      console.error('Validation failed:', err.issues);
    } else {
      console.error('Unexpected error:', err);
    }
  } finally {
    isSubmitting.value = false;
  }
}

function closeModal() {
  emit('close');
}

// 编辑模式：监听 props.budget 变化并更新表单
watch(
  () => props.budget,
  newVal => {
    if (newVal) {
      const clonedBudget = JSON.parse(JSON.stringify(newVal));
      // 转换日期格式为 input[type="date"] 所需的格式
      if (clonedBudget.startDate) {
        clonedBudget.startDate = clonedBudget.startDate.split('T')[0];
      }
      if (clonedBudget.endDate) {
        clonedBudget.endDate = clonedBudget.endDate.split('T')[0];
      }
      Object.assign(form, clonedBudget);
    }
  },
  { immediate: true, deep: true },
);
</script>

<template>
  <BaseModal
    :title="props.budget ? t('financial.budget.editBudget') : t('financial.budget.addBudget')"
    size="md"
    :confirm-loading="isSubmitting"
    :confirm-disabled="!isFormValid"
    @close="closeModal"
    @confirm="onSubmit"
  >
    <form @submit.prevent="onSubmit">
      <!-- 使用共享的表单字段组件 -->
      <BudgetFormFields
        :form="form"
        :color-names="colorNameMap"
        :scope-types="scopeTypes"
        :category-error="categoryError"
        :account-error="accountError"
        :repeat-period-error="validationErrors.repeatPeriod"
        :show-account-selector="true"
        :is-family-budget="false"
        @validate-category="handleCategoryValidation"
        @validate-account="handleAccountValidation"
        @validate-repeat-period="handleRepeatPeriodValidation"
        @change-repeat-period="handleRepeatPeriodChange"
      />
    </form>
  </BaseModal>
</template>

<style scoped>
/* 样式已移至 BudgetFormFields.vue */
</style>
