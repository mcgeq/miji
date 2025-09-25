<script setup lang="ts">
import type { RepeatPeriod, Weekday } from '@/schema/common';

interface Props {
  modelValue: RepeatPeriod;
  label?: string;
  required?: boolean;
  errorMessage?: string;
  helpText?: string;
  disabled?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  label: '重复频率',
  required: false,
  errorMessage: '',
  helpText: '',
  disabled: false,
});

const emit = defineEmits<{
  'update:modelValue': [value: RepeatPeriod];
  'change': [value: RepeatPeriod];
  'validate': [isValid: boolean];
}>();
// 常量定义
const weekdayOptions: Array<{ value: Weekday; label: string }> = [
  { value: 'Mon', label: '一' },
  { value: 'Tue', label: '二' },
  { value: 'Wed', label: '三' },
  { value: 'Thu', label: '四' },
  { value: 'Fri', label: '五' },
  { value: 'Sat', label: '六' },
  { value: 'Sun', label: '日' },
];

const monthOptions = [
  '01',
  '02',
  '03',
  '04',
  '05',
  '06',
  '07',
  '08',
  '09',
  '10',
  '11',
  '12',
];

// 工具函数
function validateValue(value: RepeatPeriod) {
  let isValid = true;

  if (
    value.type === 'Weekly'
    && (!value.daysOfWeek || value.daysOfWeek.length === 0)
  ) {
    isValid = false;
  }
  if (
    value.type === 'Custom'
    && (!value.description || value.description.trim().length === 0)
  ) {
    isValid = false;
  }

  emit('validate', isValid);
}

// 事件处理
function handleTypeChange(event: Event) {
  const target = event.target as HTMLSelectElement;
  const type = target.value as RepeatPeriod['type'];

  let newValue: RepeatPeriod;

  switch (type) {
    case 'None':
      newValue = { type: 'None' };
      break;
    case 'Daily':
      newValue = { type: 'Daily', interval: 1 };
      break;
    case 'Weekly':
      newValue = { type: 'Weekly', interval: 1, daysOfWeek: ['Mon'] };
      break;
    case 'Monthly':
      newValue = { type: 'Monthly', interval: 1, day: 1 };
      break;
    case 'Yearly':
      newValue = { type: 'Yearly', interval: 1, month: 1, day: 1 };
      break;
    case 'Custom':
      newValue = { type: 'Custom', description: '' };
      break;
    default:
      newValue = { type: 'None' };
  }

  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

// 每日重复相关
function getDailyInterval() {
  return props.modelValue.type === 'Daily' ? props.modelValue.interval : 1;
}

function handleDailyIntervalChange(event: Event) {
  if (props.modelValue.type !== 'Daily')
    return;

  const target = event.target as HTMLInputElement;
  const interval = Number.parseInt(target.value) || 1;
  const newValue: RepeatPeriod = { ...props.modelValue, interval };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

// 每周重复相关
function getWeeklyInterval() {
  return props.modelValue.type === 'Weekly' ? props.modelValue.interval : 1;
}

function handleWeeklyIntervalChange(event: Event) {
  if (props.modelValue.type !== 'Weekly')
    return;

  const target = event.target as HTMLInputElement;
  const interval = Number.parseInt(target.value) || 1;
  const newValue: RepeatPeriod = { ...props.modelValue, interval };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

function isWeekdaySelected(day: Weekday) {
  if (props.modelValue.type !== 'Weekly')
    return false;
  return props.modelValue.daysOfWeek.includes(day);
}

function toggleWeekday(day: Weekday) {
  if (props.modelValue.type !== 'Weekly')
    return;

  const currentDays = props.modelValue.daysOfWeek;
  const newDays = currentDays.includes(day)
    ? currentDays.filter(d => d !== day)
    : [...currentDays, day];

  // 至少保留一个选中的日期
  if (newDays.length > 0) {
    const newValue: RepeatPeriod = { ...props.modelValue, daysOfWeek: newDays };
    emit('update:modelValue', newValue);
    emit('change', newValue);
    validateValue(newValue);
  }
}

// 每月重复相关
function getMonthlyInterval() {
  return props.modelValue.type === 'Monthly' ? props.modelValue.interval : 1;
}

function handleMonthlyIntervalChange(event: Event) {
  if (props.modelValue.type !== 'Monthly')
    return;

  const target = event.target as HTMLInputElement;
  const interval = Number.parseInt(target.value) || 1;
  const newValue: RepeatPeriod = { ...props.modelValue, interval };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

function getMonthlyDay() {
  return props.modelValue.type === 'Monthly' ? props.modelValue.day : 1;
}

function handleMonthlyDayChange(event: Event) {
  if (props.modelValue.type !== 'Monthly')
    return;

  const target = event.target as HTMLSelectElement;
  const day
    = target.value === 'Last' ? ('Last' as const) : Number.parseInt(target.value) || 1;
  const newValue: RepeatPeriod = { ...props.modelValue, day };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

// 每年重复相关
function getYearlyInterval() {
  return props.modelValue.type === 'Yearly' ? props.modelValue.interval : 1;
}

function handleYearlyIntervalChange(event: Event) {
  if (props.modelValue.type !== 'Yearly')
    return;

  const target = event.target as HTMLInputElement;
  const interval = Number.parseInt(target.value) || 1;
  const newValue: RepeatPeriod = { ...props.modelValue, interval };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

function getYearlyMonth() {
  return props.modelValue.type === 'Yearly' ? props.modelValue.month : 1;
}

function handleYearlyMonthChange(event: Event) {
  if (props.modelValue.type !== 'Yearly')
    return;

  const target = event.target as HTMLSelectElement;
  const month = Number.parseInt(target.value) || 1;
  const newValue: RepeatPeriod = { ...props.modelValue, month };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

function getYearlyDay() {
  return props.modelValue.type === 'Yearly' ? props.modelValue.day : 1;
}

function handleYearlyDayChange(event: Event) {
  if (props.modelValue.type !== 'Yearly')
    return;

  const target = event.target as HTMLSelectElement;
  const day = Number.parseInt(target.value) || 1;
  const newValue: RepeatPeriod = { ...props.modelValue, day };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

function getMaxDaysInMonth() {
  if (props.modelValue.type !== 'Yearly')
    return 31;

  const month = props.modelValue.month;
  const daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return daysInMonth[month - 1];
}

// 自定义重复相关
function getCustomDescription() {
  return props.modelValue.type === 'Custom' ? props.modelValue.description : '';
}

function handleCustomDescriptionChange(event: Event) {
  if (props.modelValue.type !== 'Custom')
    return;

  const target = event.target as HTMLTextAreaElement;
  const description = target.value;
  const newValue: RepeatPeriod = { ...props.modelValue, description };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  validateValue(newValue);
}

// 监听器
watch(
  () => props.modelValue,
  newValue => {
    validateValue(newValue);
  },
  { immediate: true, deep: true },
);
</script>

<template>
  <div class="repeat-period-selector">
    <div class="mb-2 flex items-center justify-between">
      <label class="text-sm text-gray-700 font-medium mb-2 dark:text-gray-300">
        {{ label }}
        <span v-if="required" class="text-red-500 ml-1" aria-label="必填">*</span>
      </label>
      <select
        :model-value="modelValue.type"
        :value="modelValue.type"
        class="modal-input-select w-2/3"
        :class="{ 'border-red-500': errorMessage }"
        @change="handleTypeChange"
      >
        <option value="None">
          不重复
        </option>
        <option value="Daily">
          日
        </option>
        <option value="Weekly">
          周
        </option>
        <option value="Monthly">
          月
        </option>
        <option value="Yearly">
          年
        </option>
        <option value="Custom">
          自定义
        </option>
      </select>
    </div>

    <div
      v-if="errorMessage"
      class="text-sm text-red-600 mb-2 text-right dark:text-red-400"
      role="alert"
    >
      {{ errorMessage }}
    </div>

    <div v-if="modelValue.type !== 'None'" class="space-y-3">
      <div v-if="modelValue.type === 'Daily'" class="flex items-center justify-between">
        <label class="text-sm text-gray-600 ml-4 dark:text-gray-400">间隔天数</label>
        <div class="flex w-2/3 items-center space-x-1">
          <span class="text-sm text-gray-500">每</span>
          <input
            :value="getDailyInterval()"
            type="number"
            min="1"
            max="365"
            class="modal-input-select flex-1"
            placeholder="1"
            @input="handleDailyIntervalChange"
          >
          <span class="text-sm text-gray-500">天</span>
        </div>
      </div>

      <div v-if="modelValue.type === 'Weekly'" class="space-y-3">
        <div class="flex items-center justify-between">
          <label class="text-sm text-gray-600 ml-4 dark:text-gray-400">间隔周数</label>
          <div class="flex w-2/3 items-center space-x-2">
            <span class="text-sm text-gray-500">每</span>
            <input
              :value="getWeeklyInterval()"
              type="number"
              min="1"
              max="52"
              class="modal-input-select flex-1"
              placeholder="1"
              @input="handleWeeklyIntervalChange"
            >
            <span class="text-sm text-gray-500">周</span>
          </div>
        </div>
        <div class="space-y-2">
          <div class="flex items-start justify-between">
            <label class="text-sm text-gray-600 ml-4 pt-2 dark:text-gray-400">重复星期</label>
            <div class="w-2/3">
              <div class="gap-2 grid grid-cols-7">
                <button
                  v-for="day in weekdayOptions"
                  :key="day.value"
                  type="button"
                  class="text-xs text-gray-700 font-medium rounded-3xl bg-gray-100 flex h-0.25rem w-0.25rem transition-colors items-center justify-center dark:text-gray-300 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600"
                  :class="{
                    '!bg-blue-500 !text-gray-700': isWeekdaySelected(day.value),
                  }"
                  @click="toggleWeekday(day.value)"
                >
                  {{ day.label }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div v-if="modelValue.type === 'Monthly'" class="space-y-3">
        <div class="flex items-center justify-between">
          <label class="text-sm text-gray-600 ml-4 dark:text-gray-400">间隔月数</label>
          <div class="flex w-2/3 items-center space-x-2">
            <span class="text-sm text-gray-500">每</span>
            <input
              :value="getMonthlyInterval()"
              type="number"
              min="1"
              max="12"
              class="modal-input-select flex-1"
              placeholder="1"
              @input="handleMonthlyIntervalChange"
            >
            <span class="text-sm text-gray-500">月</span>
          </div>
        </div>
        <div class="flex items-center justify-between">
          <label class="text-sm text-gray-600 ml-4 dark:text-gray-400">日期</label>
          <div class="w-2/3">
            <select
              :value="getMonthlyDay()"
              class="modal-input-select w-full"
              @change="handleMonthlyDayChange"
            >
              <option
                v-for="day in 31"
                :key="day"
                :value="day"
              >
                {{ day }}
              </option>
              <option value="last">
                每月最后一天
              </option>
            </select>
          </div>
        </div>
      </div>

      <div v-if="modelValue.type === 'Yearly'" class="space-y-3">
        <div class="flex items-center justify-between">
          <label class="text-sm text-gray-600 ml-4 dark:text-gray-400">间隔年数</label>
          <div class="flex w-2/3 items-center space-x-2">
            <span class="text-sm text-gray-500">每</span>
            <input
              :value="getYearlyInterval()"
              type="number"
              min="1"
              max="10"
              class="modal-input-select flex-1"
              placeholder="1"
              @input="handleYearlyIntervalChange"
            >
            <span class="text-sm text-gray-500">年</span>
          </div>
        </div>
        <div class="flex items-center justify-between">
          <label class="text-sm text-gray-600 ml-4 dark:text-gray-400">月份</label>
          <div class="w-2/3">
            <select
              :value="getYearlyMonth()"
              class="modal-input-select w-full"
              @change="handleYearlyMonthChange"
            >
              <option
                v-for="(month, index) in monthOptions"
                :key="index + 1"
                :value="index + 1"
              >
                {{ month }}
              </option>
            </select>
          </div>
        </div>
        <div class="flex items-center justify-between">
          <label class="text-sm text-gray-600 ml-4 dark:text-gray-400">日期</label>
          <div class="w-2/3">
            <select
              :value="getYearlyDay()"
              class="modal-input-select w-full"
              @change="handleYearlyDayChange"
            >
              <option
                v-for="day in getMaxDaysInMonth()"
                :key="day"
                :value="day"
              >
                {{ day }}
              </option>
            </select>
          </div>
        </div>
      </div>

      <!-- 自定义重复配置 -->
      <div v-if="modelValue.type === 'Custom'" class="space-y-3">
        <div class="flex items-start justify-between">
          <label class="text-sm text-gray-600 pt-2 dark:text-gray-400">自定义描述</label>
          <div class="w-2/3">
            <textarea
              :value="getCustomDescription()"
              rows="2"
              class="modal-input-select w-full"
              placeholder="请描述重复规则，如：每月第二个周一、每季度末等"
              maxlength="100"
              @input="handleCustomDescriptionChange"
            />
            <div class="text-xs text-gray-500 mt-1 text-right dark:text-gray-400">
              {{ getCustomDescription()?.length || 0 }}/100
            </div>
          </div>
        </div>
      </div>
    </div>

    <div v-if="helpText" class="text-xs text-gray-500 mt-2 flex justify-end dark:text-gray-400">
      {{ helpText }}
    </div>
  </div>
</template>

<style scoped lang="postcss">
.repeat-period-selector {
  @apply space-y-2;
}

.modal-input-select:focus {
  @apply ring-2 ring-blue-400 ring-opacity-50 border-blue-500;
}

.border-red-500:focus {
  @apply ring-2 ring-red-400 ring-opacity-50 border-red-500;
}

/* 星期按钮的基础样式优化 */
.grid-cols-7 {
  @apply grid-cols-7;
}

.grid-cols-7 button {
  min-width: 2.5rem;
  min-height: 2.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* 确保在小屏幕上布局正常 */
@media (max-width: 640px) {
  .flex.items-center.justify-between,
  .flex.items-start.justify-between {
    @apply flex-col items-stretch space-y-2;
  }

  .w-2\/3 {
    @apply w-full;
  }

  /* 移动端星期按钮优化 */
  .grid-cols-7 {
    @apply gap-1;
  }

  .grid-cols-7 button {
    min-height: 2.5rem;
    min-width: 2.5rem;
    @apply text-sm;
  }

  /* 确保标签在小屏幕下也能正确对齐 */
  .text-sm.text-gray-600 {
    @apply text-left mb-1;
  }
}
</style>
