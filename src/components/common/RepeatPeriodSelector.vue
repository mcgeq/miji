<script setup lang="ts">
import Input from '@/components/ui/Input.vue';
import Select from '@/components/ui/Select.vue';
import Textarea from '@/components/ui/Textarea.vue';
import type { SelectOption } from '@/components/ui/Select.vue';
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

// 重复类型选项
const repeatTypeOptions = computed<SelectOption[]>(() => [
  { value: 'None', label: '不重复' },
  { value: 'Daily', label: '日' },
  { value: 'Weekly', label: '周' },
  { value: 'Monthly', label: '月' },
  { value: 'Yearly', label: '年' },
  { value: 'Custom', label: '自定义' },
]);

// 每月日期选项
const monthlyDayOptions = computed<SelectOption[]>(() => [
  ...Array.from({ length: 31 }, (_, i) => ({
    value: i + 1,
    label: String(i + 1),
  })),
  { value: 'last', label: '每月最后一天' },
]);

// 每年月份选项
const yearlyMonthOptions = computed<SelectOption[]>(() =>
  monthOptions.map((month, index) => ({
    value: index + 1,
    label: month,
  })),
);

// 每年日期选项（动态）
const yearlyDayOptions = computed<SelectOption[]>(() =>
  Array.from({ length: getMaxDaysInMonth() }, (_, i) => ({
    value: i + 1,
    label: String(i + 1),
  })),
);

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
  <div class="flex flex-col gap-2">
    <!-- 通用输入行 - 有标签时显示完整布局 -->
    <div v-if="label" class="flex justify-between items-center mb-2 max-sm:flex-wrap">
      <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">
        {{ label }}
        <span v-if="required" class="text-[var(--color-primary)] ml-1">*</span>
      </label>
      <div class="w-2/3 max-sm:flex-1 max-sm:w-full">
        <Select
          :model-value="modelValue.type"
          :options="repeatTypeOptions"
          size="sm"
          :error="errorMessage"
          full-width
          @update:model-value="(val) => handleTypeChange({ target: { value: val } } as any)"
        />
      </div>
    </div>

    <!-- 无标签时只显示 Select - 用于 FormRow 场景 -->
    <Select
      v-else
      :model-value="modelValue.type"
      :options="repeatTypeOptions"
      size="md"
      :error="errorMessage"
      full-width
      @update:model-value="(val) => handleTypeChange({ target: { value: val } } as any)"
    />

    <div v-if="errorMessage && label" class="text-sm text-[#dc2626] text-right">
      {{ errorMessage }}
    </div>

    <!-- 重复类型分区 -->
    <div v-if="modelValue.type !== 'None'" class="flex flex-col gap-3">
      <!-- Daily -->
      <div v-if="modelValue.type === 'Daily'" class="flex justify-between items-center mb-2 max-sm:flex-wrap">
        <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">间隔天数</label>
        <div class="flex items-center gap-1 flex-1 max-sm:w-full">
          <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">每</span>
          <Input
            type="number"
            :model-value="getDailyInterval()"
            size="sm"
            class="flex-1"
            @update:model-value="(val) => handleDailyIntervalChange({ target: { value: val } } as any)"
          />
          <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">天</span>
        </div>
      </div>

      <!-- Weekly -->
      <div v-if="modelValue.type === 'Weekly'" class="flex flex-col gap-3">
        <div class="flex justify-between items-center mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">间隔周数</label>
          <div class="flex items-center gap-1 flex-1 max-sm:w-full">
            <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">每</span>
            <Input
              type="number"
              :model-value="getWeeklyInterval()"
              size="sm"
              class="flex-1"
              @update:model-value="(val) => handleWeeklyIntervalChange({ target: { value: val } } as any)"
            />
            <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">周</span>
          </div>
        </div>
        <div class="flex justify-between items-center mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">重复星期</label>
          <div class="grid grid-cols-7 gap-1">
            <button
              v-for="day in weekdayOptions"
              :key="day.value"
              type="button"
              class="min-w-10 min-h-10 flex justify-center items-center text-xs font-medium rounded-full transition-all duration-200" :class="[
                isWeekdaySelected(day.value)
                  ? 'bg-[#3b82f6] text-white'
                  : 'bg-[light-dark(#f3f4f6,#374151)] text-[light-dark(#374151,#d1d5db)] hover:bg-[light-dark(#e5e7eb,#4b5563)]',
              ]"
              @click="toggleWeekday(day.value)"
            >
              {{ day.label }}
            </button>
          </div>
        </div>
      </div>

      <!-- Monthly -->
      <div v-if="modelValue.type === 'Monthly'" class="flex flex-col gap-3">
        <div class="flex justify-between items-center mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">间隔月数</label>
          <div class="flex items-center gap-1 flex-1 max-sm:w-full">
            <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">每</span>
            <Input
              type="number"
              :model-value="getMonthlyInterval()"
              size="sm"
              class="flex-1"
              @update:model-value="(val) => handleMonthlyIntervalChange({ target: { value: val } } as any)"
            />
            <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">月</span>
          </div>
        </div>
        <div class="flex justify-between items-center mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">日期</label>
          <div class="w-2/3 max-sm:flex-1 max-sm:w-full">
            <Select
              :model-value="getMonthlyDay()"
              :options="monthlyDayOptions"
              size="sm"
              full-width
              @update:model-value="(val) => handleMonthlyDayChange({ target: { value: val } } as any)"
            />
          </div>
        </div>
      </div>

      <!-- Yearly -->
      <div v-if="modelValue.type === 'Yearly'" class="flex flex-col gap-3">
        <div class="flex justify-between items-center mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">间隔年数</label>
          <div class="flex items-center gap-1 flex-1 max-sm:w-full">
            <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">每</span>
            <Input
              type="number"
              :model-value="getYearlyInterval()"
              size="sm"
              class="flex-1"
              @update:model-value="(val) => handleYearlyIntervalChange({ target: { value: val } } as any)"
            />
            <span class="text-sm text-[light-dark(#6b7280,#9ca3af)]">年</span>
          </div>
        </div>
        <div class="flex justify-between items-center mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">月份</label>
          <div class="w-2/3 max-sm:flex-1 max-sm:w-full">
            <Select
              :model-value="getYearlyMonth()"
              :options="yearlyMonthOptions"
              size="sm"
              full-width
              @update:model-value="(val) => handleYearlyMonthChange({ target: { value: val } } as any)"
            />
          </div>
        </div>
        <div class="flex justify-between items-center mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">日期</label>
          <div class="w-2/3 max-sm:flex-1 max-sm:w-full">
            <Select
              :model-value="getYearlyDay()"
              :options="yearlyDayOptions"
              size="sm"
              full-width
              @update:model-value="(val) => handleYearlyDayChange({ target: { value: val } } as any)"
            />
          </div>
        </div>
      </div>

      <!-- Custom -->
      <div v-if="modelValue.type === 'Custom'" class="flex flex-col gap-3">
        <div class="flex justify-between items-start mb-2 max-sm:flex-wrap">
          <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0 pt-2">自定义描述</label>
          <div class="w-2/3 max-sm:flex-1 max-sm:w-full">
            <Textarea
              :model-value="getCustomDescription()"
              :rows="2"
              :max-length="100"
              placeholder="请描述重复规则，如：每月第二个周一、每季度末等"
              show-count
              full-width
              @update:model-value="(val) => handleCustomDescriptionChange({ target: { value: val } } as any)"
            />
          </div>
        </div>
      </div>
    </div>

    <div v-if="helpText" class="text-xs text-[light-dark(#6b7280,#9ca3af)] text-right mt-1">
      {{ helpText }}
    </div>
  </div>
</template>
