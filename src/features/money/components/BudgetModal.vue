<script setup lang="ts">
import _ from 'lodash';
import { Check, X } from 'lucide-vue-next';
import z from 'zod';
import CategorySelector from '@/components/common/CategorySelector.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import { COLORS_MAP, CURRENCY_CNY } from '@/constants/moneyConst';
import { BudgetTypeSchema } from '@/schema/common';
import { BudgetCreateSchema, BudgetScopeTypeSchema, BudgetUpdateSchema } from '@/schema/money';
import { DateUtils } from '@/utils/date';
import { getLocalCurrencyInfo } from '../utils/money';
import type { RepeatPeriod } from '@/schema/common';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';

interface Props {
  budget: Budget | null;
}

// 定义 props
const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [budget: BudgetCreate];
  update: [serialNum: string, budget: BudgetUpdate];
}>();

const colorNameMap = ref(COLORS_MAP);
const currency = ref(CURRENCY_CNY);

const { t } = useI18n();

// 验证错误
const validationErrors = reactive({
  name: '',
  type: '',
  amount: '',
  remindDate: '',
  repeatPeriod: '',
  priority: '',
});

const budget = props.budget || getDefaultBudget();

const form = reactive<Budget>({
  ...budget,
});
const types = Object.values(BudgetScopeTypeSchema.enum).map(type => ({
  original: type,
  snake: toCamelCase(type),
}));

function onSubmit() {
  try {
    const defaultValues: Record<string, unknown> = {
      accountSerialNum: null,
      currency: null,
      alertThreshold: null,
      budgetType: null,
      accountScope: null,
      advancedRules: null,
      currentPeriodUsed: 0,
      currentPeriodStart: null,
      progress: 0,
      linkedGoal: null,
      reminders: [],
      priority: 0,
      tags: [],
      autoRollover: false,
      rolloverHistory: [],
      sharingSettings: null,
      attachments: [],
    };

    const formattedData = _.mapValues({
      name: form.name,
      description: form.description,
      accountSerialNum: form.accountSerialNum,
      amount: form.amount,
      currency: form.currency?.code,
      repeatPeriod: form.repeatPeriod,
      startDate: form.startDate,
      endDate: form.endDate,
      usedAmount: form.usedAmount,
      isActive: form.isActive,
      alertEnabled: form.alertEnabled,
      alertThreshold: form.alertThreshold,
      color: form.color,
      budgetType: form.budgetType,
      budgetScopeType: form.budgetScopeType,
      categoryScope: form.categoryScope,
      accountScope: form.accountScope,
      advancedRules: form.advancedRules,
      currentPeriodUsed: form.currentPeriodUsed,
      currentPeriodStart: form.currentPeriodStart,
      progress: form.progress,
      linkedGoal: form.linkedGoal,
      reminders: form.reminders,
      priority: form.priority,
      tags: form.tags,
      autoRollover: form.autoRollover,
      rolloverHistory: form.rolloverHistory,
      sharingSettings: form.sharingSettings,
      attachments: form.attachments,
    }, (value: unknown, key: string) => {
      // 特殊处理日期字段 - 确保传入字符串
      if (key.endsWith('Date')) {
        if (value) {
          const dateValue = typeof value === 'string' ?
            value :
            value instanceof Date ?
                value.toISOString() :
                String(value);
          return DateUtils.toLocalISOFromDateInput(dateValue);
        }
        return null;
      }
      // 应用默认值
      return _.defaultTo(value, defaultValues[key] ?? null);
    });

    const createData = _.omit(formattedData, 'serialNum');
    if (createData.amount) createData.amount = Number(createData.amount);
    if (createData.usedAmount) createData.usedAmount = Number(createData.usedAmount);
    if (createData.currentPeriodUsed) createData.currentPeriodUsed = Number(createData.currentPeriodUsed);
    if (createData.progress) createData.progress = Number(createData.progress);
    if (createData.priority) createData.priority = Math.round(Number(createData.priority));
    createData.currentPeriodUsed = createData.currentPeriodUsed || 0;
    createData.progress = createData.progress || 0;
    createData.priority = createData.priority || 0;
    createData.autoRollover = createData.autoRollover || false;
    createData.reminders = createData.reminders || JSON.stringify([]);
    createData.tags = createData.tags || JSON.stringify([]);
    createData.rolloverHistory = createData.rolloverHistory || JSON.stringify([]);
    createData.attachments = createData.attachments || JSON.stringify([]);

    if (props.budget) {
      const changes = _.omitBy(formattedData, (value: unknown, key: string) =>
        _.isEqual(value, _.get(props.budget, key)));
      const safeChanges = _.omit(changes, 'serialNum');
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
      const serializedChanges = _.mapValues(safeChanges, (value, key) => {
        if (jsonFields.includes(key) && value !== null && value !== undefined) {
          try {
            return JSON.stringify(value);
          } catch {
            return value;
          }
        }
        return value;
      });
      if (!_.isEmpty(serializedChanges)) {
        const budgetUpdate = BudgetUpdateSchema.parse(safeChanges);
        emit('update', props.budget.serialNum, budgetUpdate);
      }
    } else {
      const budgetCreate = BudgetCreateSchema.parse(createData);
      emit('save', budgetCreate);
    }
    closeModal();
  } catch (err: unknown) {
    if (err instanceof z.ZodError) {
      console.error('Validation failed:', err.issues);
    } else {
      console.error('Unexpected error:', err);
    }
  }
}

function handleRepeatPeriodChange(_value: RepeatPeriod) {
  validationErrors.repeatPeriod = '';
}

function handleRepeatPeriodValidation(isValid: boolean) {
  if (!isValid) {
    validationErrors.repeatPeriod = t('validation.repeatPeriodIncomplete');
  } else {
    validationErrors.repeatPeriod = '';
  }
}

function getDefaultBudget(): Budget {
  const day = DateUtils.getTodayDate();
  return {
    serialNum: '',
    accountSerialNum: null,
    name: '',
    description: '',
    amount: 0,
    currency: currency.value,
    repeatPeriod: { type: 'None' },
    startDate: day,
    endDate: DateUtils.addDays(day, 30),
    usedAmount: 0,
    isActive: true,
    alertEnabled: false,
    alertThreshold: null,
    color: COLORS_MAP[0].code,
    account: null,
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: null,
    currentPeriodUsed: 0,
    currentPeriodStart: DateUtils.getTodayDate(),
    budgetType: BudgetTypeSchema.enum.Standard,
    progress: 0,
    linkedGoal: null,
    reminders: [],
    priority: 0,
    tags: [],
    autoRollover: false,
    rolloverHistory: [],
    sharingSettings: { sharedWith: [], permissionLevel: 'ViewOnly' },
    attachments: [],
    budgetScopeType: BudgetScopeTypeSchema.enum.Category,
    accountScope: null,
    categoryScope: [],
    advancedRules: null,
  };
}

const categoryError = ref('');

function handleCategoryValidation(isValid: boolean) {
  if (!isValid) {
    categoryError.value = '请至少选择一个分类';
  } else {
    categoryError.value = '';
  }
}

function toCamelCase(str: string) {
  return str.charAt(0).toLowerCase() + str.slice(1);
}

function closeModal() {
  emit('close');
}

watch(
  () => props.budget,
  newVal => {
    if (newVal) {
      const clonedAccount = JSON.parse(JSON.stringify(newVal));
      Object.assign(form, clonedAccount);
    }
  },
  { immediate: true, deep: true },
);

onMounted(async () => {
  const cny = await getLocalCurrencyInfo();
  currency.value = cny;
});
</script>

<template>
  <div class="modal-mask">
    <div class="modal-mask-window-money">
      <div class="mb-4 flex items-center justify-between">
        <h3 class="text-lg font-semibold">
          {{ props.budget ? t('financial.budget.editBudget') : t('financial.budget.addBudget') }}
        </h3>
        <button class="text-gray-500 hover:text-gray-700" @click="closeModal">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <form @submit.prevent="onSubmit">
        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">
            {{ t('financial.budget.budgetName') }}
          </label>
          <input
            v-model="form.name" type="text" required class="w-2/3 modal-input-select"
            :placeholder="t('validation.budgetName')"
          >
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">
            {{ t('financial.budget.budgetScopeType') }}
          </label>
          <select v-model="form.budgetScopeType" required class="w-2/3 modal-input-select">
            <option
              v-for="ty in types"
              :key="ty.original"
              :value="ty.original"
            >
              {{ t(`financial.budgetScopeTypes.${ty.snake}`) }}
            </option>
          </select>
        </div>

        <div
          v-if="form.budgetScopeType === 'Category' || form.budgetScopeType === 'Hybrid'"
        >
          <CategorySelector
            v-model="form.categoryScope"
            :required="true"
            label="预算类别"
            placeholder="请选择分类"
            help-text="选择适用于此预算的分类"
            :error-message="categoryError"
            @validate="handleCategoryValidation"
          />
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">
            {{ t('financial.budget.budgetAmount') }}
          </label>
          <input
            v-model.number="form.amount" type="number" step="0.01" required class="w-2/3 modal-input-select"
            placeholder="0.00"
          >
        </div>

        <!-- 重复频率  -->
        <RepeatPeriodSelector
          v-model="form.repeatPeriod" :label="t('date.repeat.frequency')"
          :error-message="validationErrors.repeatPeriod" :help-text="t('helpTexts.repeatPeriod')"
          @change="handleRepeatPeriodChange" @validate="handleRepeatPeriodValidation"
        />

        <div class="mb-2 mt-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">
            {{ t('date.startDate') }}
          </label>
          <input v-model="form.startDate" type="date" required class="w-2/3 modal-input-select">
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">
            {{ t('date.endDate') }}
          </label>
          <input v-model="form.endDate" type="date" class="w-2/3 modal-input-select">
        </div>

        <div class="mb-2 flex items-center justify-between">
          <label class="mb-2 text-sm text-gray-700 font-medium">
            {{ t('common.misc.color') }}
          </label>
          <ColorSelector v-model="form.color" :color-names="colorNameMap" />
        </div>

        <div class="mb-4 h-8 flex items-center justify-between">
          <div class="w-1/3">
            <label class="flex items-center">
              <input v-model="form.alertEnabled" type="checkbox" class="mr-2 modal-input-select">
              <span class="text-sm text-gray-700 font-medium">
                {{ t('financial.budget.overBudgetAlert') }}
              </span>
            </label>
          </div>

          <div v-if="form.alertEnabled" class="w-2/3">
            <input
              v-model.number="form.alertThreshold" type="number" min="1" max="100"
              class="w-full modal-input-select" placeholder="80"
            >
          </div>
        </div>

        <div class="mb-2">
          <textarea
            v-model="form.description" rows="3" class="w-full modal-input-select"
            :placeholder="t('placeholders.budgetDescription')"
          />
        </div>

        <div class="flex justify-center space-x-3">
          <button type="button" class="modal-btn-x" @click="closeModal">
            <X class="wh-5" />
          </button>
          <button type="submit" class="modal-btn-check">
            <Check class="wh-5" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped>
/* 自定义样式 */
</style>
