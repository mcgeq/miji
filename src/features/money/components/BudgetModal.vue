<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import CategorySelector from '@/components/common/CategorySelector.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import { COLORS_MAP, CURRENCY_CNY } from '@/constants/moneyConst';
import { BudgetTypeSchema } from '@/schema/common';
import { BudgetScopeTypeSchema } from '@/schema/money';
import { DateUtils } from '@/utils/date';
import { uuid } from '@/utils/uuid';
import { getLocalCurrencyInfo } from '../utils/money';
import type { RepeatPeriod } from '@/schema/common';
import type { Budget } from '@/schema/money';

interface Props {
  budget: Budget | null;
}

// 定义 props
const props = defineProps<Props>();

// 定义 emits
const emit = defineEmits(['close', 'save', 'update']);

const colorNameMap = ref(COLORS_MAP);
const currency = ref(CURRENCY_CNY);

// 假设已注入 t 函数
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

// 响应式数据
const form = reactive<Budget>({
  ...budget,
});
const types = Object.values(BudgetScopeTypeSchema.enum).map(type => ({
  original: type,
  snake: toCamelCase(type),
}));

function saveBudget() {
  const budgetData: Budget = {
    ...form,
    serialNum: props.budget?.serialNum || uuid(38),
    createdAt: props.budget?.createdAt || DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: DateUtils.getLocalISODateTimeWithOffset(),
  };
  emit('save', budgetData);
  closeModal();
}

function handleRepeatPeriodChange(_value: RepeatPeriod) {
  // 清除验证错误
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
    accountSerialNum: '',
    name: '',
    description: '',
    amount: 0, // 修正为数字类型
    currency: currency.value,
    repeatPeriod: { type: 'None' },
    startDate: day, // 使用日期专用函数
    endDate: DateUtils.addDays(day, 30), // 默认1个月后
    usedAmount: 0, // 修正为数字类型
    isActive: true,
    alertEnabled: false,
    alertThreshold: undefined, // 修正为数字类型
    color: COLORS_MAP[0].code,
    account: null, // 添加必需字段
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: null,
    // 可选字段提供合理默认值
    currentPeriodUsed: 0,
    currentPeriodStart: DateUtils.getLocalISODateTimeWithOffset(),
    budgetType: BudgetTypeSchema.enum.Standard,
    progress: 0,
    linkedGoal: '',
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

// 分类错误信息
const categoryError = ref('');

// 处理分类验证
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
      <form @submit.prevent="saveBudget">
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
            label="预算分类"
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
