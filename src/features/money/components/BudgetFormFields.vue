<script setup lang="ts">
  /* eslint-disable vue/no-mutating-props */
  import CategorySelector from '@/components/common/CategorySelector.vue';
  import ColorSelector from '@/components/common/ColorSelector.vue';
  import AccountSelector from '@/components/common/money/AccountSelector.vue';
  import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
  import type { SelectOption } from '@/components/ui';
  import { Checkbox, FormRow, Input, Select, Textarea } from '@/components/ui';
  import type { RepeatPeriod } from '@/schema/common';

  interface AlertThreshold {
    type: 'Percentage' | 'FixedAmount';
    value: number;
  }

  interface BudgetFormData {
    name: string;
    amount: number;
    budgetScopeType: string;
    categoryScope?: string[];
    accountSerialNum?: string | null;
    repeatPeriod: RepeatPeriod;
    startDate: string;
    endDate?: string;
    color: string;
    alertEnabled: boolean;
    alertThreshold?: AlertThreshold | null;
    description?: string;
  }

  interface Props {
    /** 表单数据 */
    form: BudgetFormData;
    /** 颜色选项 */
    colorNames: unknown;
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
    (e: 'update:modelValue', value: BudgetFormData): void;
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
  <div class="flex flex-col gap-0">
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
      <Input v-model="form.amount" type="number" required full-width placeholder="0.00" />
    </FormRow>

    <!-- 预算范围类型 -->
    <FormRow :label="t('financial.budget.budgetScopeType')" required>
      <Select v-model="form.budgetScopeType" :options="scopeTypeOptions" required full-width />
    </FormRow>

    <!-- 分类选择器 -->
    <FormRow
      v-if="form.budgetScopeType === 'Category' || form.budgetScopeType === 'Hybrid'"
      label="预算类别"
      required
      :error="categoryError"
      help-text="选择适用于此预算的分类"
    >
      <CategorySelector
        v-model="form.categoryScope"
        :required="false"
        label=""
        placeholder="请选择分类"
        help-text=""
        error-message=""
        width="full"
        @validate="emit('validateCategory', $event)"
      />
    </FormRow>

    <!-- 账户选择器（仅个人预算） -->
    <FormRow
      v-if="!isFamilyBudget && showAccountSelector && form.budgetScopeType === 'Account'"
      label="账户选择"
      required
      :error="accountError"
    >
      <AccountSelector
        v-model="form.accountSerialNum"
        :required="false"
        label=""
        placeholder="请选择账户"
        help-text=""
        :show-quick-select="false"
        width="full"
        @validate="emit('validateAccount', $event)"
      />
    </FormRow>

    <!-- 重复周期 -->
    <FormRow
      :label="t('date.repeat.frequency')"
      :error="repeatPeriodError"
      :help-text="t('helpTexts.repeatPeriod')"
    >
      <RepeatPeriodSelector
        v-model="form.repeatPeriod"
        label=""
        :required="false"
        error-message=""
        help-text=""
        @change="emit('changeRepeatPeriod', $event)"
        @validate="emit('validateRepeatPeriod', $event)"
      />
    </FormRow>

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
        :color-names="(colorNames as any)"
        :extended="true"
        :show-categories="true"
        :show-custom-color="true"
        :show-random-button="true"
      />
    </FormRow>

    <!-- 预警设置 - 第一行：标签和复选框 -->
    <FormRow :label="t('financial.budget.overBudgetAlert')" optional>
      <Checkbox v-model="form.alertEnabled" />
    </FormRow>

    <!-- 预警设置 - 第二行：下拉框和输入框 -->
    <FormRow v-if="form.alertEnabled && form.alertThreshold">
      <div class="flex gap-2">
        <div class="flex-1">
          <Select v-model="form.alertThreshold.type" :options="alertTypeOptions" />
        </div>

        <div class="flex-1">
          <input
            v-model="form.alertThreshold.value"
            type="number"
            class="w-full px-4 py-2 text-base transition-colors focus:outline-none focus:ring-2 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 border border-gray-300 dark:border-gray-600 focus:ring-blue-500 focus:border-blue-500 rounded-lg"
            :placeholder="form.alertThreshold.type === 'Percentage' ? '80' : '100.00'"
          />
        </div>
      </div>
    </FormRow>

    <!-- 描述 -->
    <FormRow full-width>
      <Textarea
        v-model="form.description"
        :rows="3"
        :max-length="200"
        :show-count="true"
        :placeholder="t('placeholders.budgetDescription')"
      />
    </FormRow>
  </div>
</template>
