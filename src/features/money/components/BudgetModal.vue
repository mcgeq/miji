<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import ColorSelector from '@/components/common/ColorSelector.vue';
import RepeatPeriodSelector from '@/components/common/RepeatPeriodSelector.vue';
import { COLORS_MAP } from '@/constants/moneyConst';
import { CategorySchema } from '@/schema/common';
import { DateUtils } from '@/utils/date';
import { uuid } from '@/utils/uuid';
import { getLocalCurrencyInfo } from '../utils/money';
import type { RepeatPeriod } from '@/schema/common';
import type { Budget } from '@/schema/money';

// 定义 props
const props = defineProps<Props>();

// 定义 emits
const emit = defineEmits(['close', 'save']);

const colorNameMap = ref(COLORS_MAP);

interface Props {
  budget: Budget | null;
}

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

const budget = props.budget || {
  serialNum: '',
  name: '',
  description: '',
  accountSerialNum: '',
  category: CategorySchema.enum.Others,
  amount: '',
  currency: getLocalCurrencyInfo(),
  repeatPeriod: { type: 'None' },
  startDate: '',
  endDate: '',
  usedAmount: '',
  isActive: true,
  alertEnabled: false,
  alertThreshold: '0',
  color: COLORS_MAP[0].code,
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: '',
};

// 响应式数据
const form = reactive<Budget>({
  serialNum: budget.serialNum,
  accountSerialNum: budget.accountSerialNum,
  name: budget.name,
  description: budget.description,
  category: budget.category,
  amount: budget.amount,
  currency: budget.currency,
  repeatPeriod: budget.repeatPeriod,
  startDate: budget.startDate,
  endDate: budget.endDate,
  usedAmount: budget.usedAmount,
  isActive: budget.isActive,
  alertEnabled: budget.alertEnabled,
  alertThreshold: budget.alertThreshold,
  color: budget.color,
  createdAt: budget.createdAt,
  updatedAt: budget.updatedAt,
});

function closeModal() {
  emit('close');
}

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
  }
  else {
    validationErrors.repeatPeriod = '';
  }
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
            {{ t('financial.budget.budgetCategory') }}
          </label>
          <select v-model="form.category" required class="w-2/3 modal-input-select">
            <option value="">
              {{ t('common.placeholders.selectCategory') }}
            </option>
            <option value="food">
              {{ t('financial.budgetCategories.food') }}
            </option>
            <option value="transport">
              {{ t('financial.budgetCategories.transport') }}
            </option>
            <option value="shopping">
              {{ t('financial.budgetCategories.shopping') }}
            </option>
            <option value="entertainment">
              {{ t('financial.budgetCategories.entertainment') }}
            </option>
            <option value="health">
              {{ t('financial.budgetCategories.health') }}
            </option>
            <option value="education">
              {{ t('financial.budgetCategories.education') }}
            </option>
            <option value="housing">
              {{ t('financial.budgetCategories.housing') }}
            </option>
            <option value="utilities">
              {{ t('financial.budgetCategories.utilities') }}
            </option>
            <option value="insurance">
              {{ t('financial.budgetCategories.insurance') }}
            </option>
            <option value="investment">
              {{ t('financial.budgetCategories.investment') }}
            </option>
            <option value="other">
              {{ t('financial.budgetCategories.other') }}
            </option>
          </select>
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
