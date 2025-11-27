<script setup lang="ts">
/* eslint-disable vue/no-mutating-props */
import CategorySelector from '@/components/common/CategorySelector.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import AccountSelector from '@/components/common/money/AccountSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import { Checkbox, FormRow, Input, Select, Textarea } from '@/components/ui';
import type { SelectOption } from '@/components/ui';
import type { RepeatPeriod } from '@/schema/common';

interface Props {
  /** 表单数据 */
  form: any; // 使用 any 以支持不同的表单类型
  /** 颜色选项 */
  colorNames: any[];
  /** 范围类型选项 */
  scopeTypes: Array<{ original: string; snake: string }>;
  /** 分类错误信息 */
  categoryError?: string;
  /** 账户错误信息 */
  accountError?: string;
  /** 重复周期错误信息 */
  repeatPeriodError?: string;
  /** 是否显示账户选择器 */
  showAccountSelector?: boolean;
  /** 是否为家庭预算（隐藏账户选择） */
  isFamilyBudget?: boolean;
}

interface Emits {
  (e: 'validateCategory', isValid: boolean): void;
  (e: 'validateAccount', isValid: boolean): void;
  (e: 'validateRepeatPeriod', isValid: boolean): void;
  (e: 'changeRepeatPeriod', value: RepeatPeriod): void;
  (e: 'update:modelValue', value: any): void;
}

const props = withDefaults(defineProps<Props>(), {
  categoryError: '',
  accountError: '',
  repeatPeriodError: '',
  showAccountSelector: true,
  isFamilyBudget: false,
});

const emit = defineEmits<Emits>();

const { t } = useI18n();

// 预算范围类型选项
const scopeTypeOptions = computed<SelectOption[]>(() =>
  props.scopeTypes.map(ty => ({
    value: ty.original,
    label: t(`financial.budgetScopeTypes.${ty.snake}`),
  })),
);

// 预警阈值类型选项
const alertTypeOptions = computed<SelectOption[]>(() => [
  { value: 'Percentage', label: t('financial.budget.threshold.percentage') },
  { value: 'FixedAmount', label: t('financial.budget.threshold.fixedAmount') },
]);
</script>

<template>
  <div class="budget-form-fields">
    <!-- 预算名称 -->
    <FormRow :label="t('financial.budget.budgetName')" required>
      <Input
        v-model="form.name"
        type="text"
        required
        full-width
        :placeholder="t('validation.budgetName')"
      />
    </FormRow>

    <!-- 预算金额 -->
    <FormRow :label="t('financial.budget.budgetAmount')" required>
      <Input
        v-model="form.amount"
        type="number"
        required
        full-width
        placeholder="0.00"
      />
    </FormRow>

    <!-- 预算范围类型 -->
    <FormRow :label="t('financial.budget.budgetScopeType')" required>
      <Select
        v-model="form.budgetScopeType"
        :options="scopeTypeOptions"
        required
        full-width
      />
    </FormRow>

    <!-- 分类选择器 -->
    <div v-if="form.budgetScopeType === 'Category' || form.budgetScopeType === 'Hybrid'">
      <CategorySelector
        v-model="form.categoryScope"
        :required="true"
        label="预算类别"
        placeholder="请选择分类"
        help-text="选择适用于此预算的分类"
        :error-message="categoryError"
        @validate="emit('validateCategory', $event)"
      />
    </div>

    <!-- 账户选择器（仅个人预算） -->
    <div v-if="!isFamilyBudget && showAccountSelector && form.budgetScopeType === 'Account'">
      <AccountSelector
        v-model="form.accountSerialNum"
        :required="true"
        label="账户选择"
        placeholder="请选择账户"
        help-text="选择适用于此预算的账户"
        @validate="emit('validateAccount', $event)"
      />
    </div>

    <!-- 重复周期 -->
    <RepeatPeriodSelector
      v-model="form.repeatPeriod"
      :label="t('date.repeat.frequency')"
      :error-message="repeatPeriodError"
      :help-text="t('helpTexts.repeatPeriod')"
      @change="emit('changeRepeatPeriod', $event)"
      @validate="emit('validateRepeatPeriod', $event)"
    />

    <!-- 起止日期 -->
    <FormRow :label="t('date.startDate')" required>
      <Input v-model="form.startDate" type="date" required full-width />
    </FormRow>

    <FormRow :label="t('date.endDate')" optional>
      <Input v-model="form.endDate" type="date" full-width />
    </FormRow>

    <!-- 颜色选择器 -->
    <FormRow :label="t('common.misc.color')" optional>
      <ColorSelector
        v-model="form.color"
        width="full"
        :color-names="colorNames"
        :extended="true"
        :show-categories="true"
        :show-custom-color="true"
        :show-random-button="true"
      />
    </FormRow>

    <!-- 预警设置 -->
    <div class="alert-section">
      <div class="alert-checkbox">
        <Checkbox
          v-model="form.alertEnabled"
          :label="t('financial.budget.overBudgetAlert')"
        />
      </div>

      <div v-if="form.alertEnabled && form.alertThreshold" class="threshold-settings">
        <Select
          v-model="form.alertThreshold.type"
          :options="alertTypeOptions"
          class="w-2/3"
        />

        <Input
          v-model="form.alertThreshold.value"
          type="number"
          class="w-1/3"
          :placeholder="form.alertThreshold.type === 'Percentage' ? '80%' : '100.00'"
        />
      </div>
    </div>

    <!-- 描述 -->
    <div class="form-textarea">
      <Textarea
        v-model="form.description"
        :rows="3"
        :placeholder="t('placeholders.budgetDescription')"
      />
    </div>
  </div>
</template>

<style scoped>
.budget-form-fields {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

/* Alert Section */
.alert-section {
  margin-bottom: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.alert-checkbox {
  width: 33.333333%;
}

.threshold-settings {
  display: flex;
  gap: 0.5rem;
  flex: 1;
  align-items: center;
}

.form-textarea {
  margin-bottom: 0.5rem;
}

/* RepeatPeriodSelector 样式统一 */
:deep(.repeat-period-selector .field-row) {
  gap: 1rem !important;
  margin-bottom: 0.5rem !important;
}

:deep(.repeat-period-selector .label) {
  flex: 0 0 6rem !important;
  width: 6rem !important;
  min-width: 6rem !important;
  max-width: 6rem !important;
}

:deep(.repeat-period-selector .input-field) {
  flex: 1 !important;
  width: 100% !important;
}
</style>
