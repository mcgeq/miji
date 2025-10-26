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
    <!-- 通用输入行 -->
    <div class="field-row">
      <label class="label">
        {{ label }}
        <span v-if="required" class="required">*</span>
      </label>
      <select
        :value="modelValue.type"
        class="input-field"
        :class="{ 'input-error': errorMessage }"
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

    <div v-if="errorMessage" class="error-message">
      {{ errorMessage }}
    </div>

    <!-- 重复类型分区 -->
    <div v-if="modelValue.type !== 'None'" class="field-section">
      <!-- Daily -->
      <div v-if="modelValue.type === 'Daily'" class="field-row">
        <label class="label">间隔天数</label>
        <div class="input-row">
          <span class="input-text">每</span>
          <input
            type="number"
            min="1"
            max="365"
            class="input-field flex"
            :value="getDailyInterval()"
            @input="handleDailyIntervalChange"
          >
          <span class="input-text">天</span>
        </div>
      </div>

      <!-- Weekly -->
      <div v-if="modelValue.type === 'Weekly'" class="field-section">
        <div class="field-row">
          <label class="label">间隔周数</label>
          <div class="input-row">
            <span class="input-text">每</span>
            <input
              type="number"
              min="1"
              max="52"
              class="input-field flex"
              :value="getWeeklyInterval()"
              @input="handleWeeklyIntervalChange"
            >
            <span class="input-text">周</span>
          </div>
        </div>
        <div class="field-row">
          <label class="label">重复星期</label>
          <div class="grid-weekdays">
            <button
              v-for="day in weekdayOptions"
              :key="day.value"
              type="button"
              class="weekday-btn"
              :class="{ selected: isWeekdaySelected(day.value) }"
              @click="toggleWeekday(day.value)"
            >
              {{ day.label }}
            </button>
          </div>
        </div>
      </div>

      <!-- Monthly -->
      <div v-if="modelValue.type === 'Monthly'" class="field-section">
        <div class="field-row">
          <label class="label">间隔月数</label>
          <div class="input-row">
            <span class="input-text">每</span>
            <input
              type="number"
              min="1"
              max="12"
              class="input-field flex"
              :value="getMonthlyInterval()"
              @input="handleMonthlyIntervalChange"
            >
            <span class="input-text">月</span>
          </div>
        </div>
        <div class="field-row">
          <label class="label">日期</label>
          <select
            class="input-field"
            :value="getMonthlyDay()"
            @change="handleMonthlyDayChange"
          >
            <option v-for="day in 31" :key="day" :value="day">
              {{ day }}
            </option>
            <option value="last">
              每月最后一天
            </option>
          </select>
        </div>
      </div>

      <!-- Yearly -->
      <div v-if="modelValue.type === 'Yearly'" class="field-section">
        <div class="field-row">
          <label class="label">间隔年数</label>
          <div class="input-row">
            <span class="input-text">每</span>
            <input
              type="number"
              min="1"
              max="10"
              class="input-field flex"
              :value="getYearlyInterval()"
              @input="handleYearlyIntervalChange"
            >
            <span class="input-text">年</span>
          </div>
        </div>
        <div class="field-row">
          <label class="label">月份</label>
          <select
            class="input-field"
            :value="getYearlyMonth()"
            @change="handleYearlyMonthChange"
          >
            <option v-for="(month, index) in monthOptions" :key="index + 1" :value="index + 1">
              {{ month }}
            </option>
          </select>
        </div>
        <div class="field-row">
          <label class="label">日期</label>
          <select
            class="input-field"
            :value="getYearlyDay()"
            @change="handleYearlyDayChange"
          >
            <option v-for="day in getMaxDaysInMonth()" :key="day" :value="day">
              {{ day }}
            </option>
          </select>
        </div>
      </div>

      <!-- Custom -->
      <div v-if="modelValue.type === 'Custom'" class="field-section">
        <div class="field-row">
          <label class="label">自定义描述</label>
          <textarea
            class="input-field"
            rows="2"
            maxlength="100"
            :value="getCustomDescription()"
            placeholder="请描述重复规则，如：每月第二个周一、每季度末等"
            @input="handleCustomDescriptionChange"
          />
          <div class="text-counter">
            {{ getCustomDescription()?.length || 0 }}/100
          </div>
        </div>
      </div>
    </div>

    <div v-if="helpText" class="help-text">
      {{ helpText }}
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 基础容器 */
.repeat-period-selector {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

/* 通用行 */
.field-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

/* 标签 */
.label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
  margin-bottom: 0;
}
.required {
  color: var(--color-primary);
  margin-left: 0.25rem;
}

/* 输入框/选择框/文本域 */
.input-field {
  width: 66.6667%;
  padding: 0.375rem 0.5rem;
  font-size: 0.875rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  transition: all 0.2s;
  background-color: var(--color-base-100);
  color: #374151;
}
.input-field:focus {
  outline: none;
  border-color: #3b82f6;
  box-shadow: 0 0 0 2px rgba(59,130,246,0.5);
}
.input-error {
  border-color: #ef4444;
  box-shadow: 0 0 0 2px rgba(239,68,68,0.5);
}

/* 输入行内文本 */
.input-row {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}
.input-text { font-size:0.875rem; color:#6b7280; }
.flex { flex: 1; }

/* 分区 */
.field-section { display:flex; flex-direction: column; gap:0.75rem; }

/* 错误提示和帮助文本 */
.error-message { font-size:0.875rem; color:#dc2626; text-align:right; }
.help-text, .text-counter { font-size:0.75rem; color:#6b7280; text-align:right; margin-top:0.25rem; }

/* 星期按钮网格 */
.grid-weekdays {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.25rem;
}
.weekday-btn {
  min-width:2.5rem; min-height:2.5rem;
  display:flex; justify-content:center; align-items:center;
  font-size:0.75rem; font-weight:500;
  color:#374151; background:#f3f4f6; border-radius:9999px;
  transition: background-color 0.2s, color 0.2s;
}
.weekday-btn:hover { background:#e5e7eb; }
.weekday-btn.selected { background:#3b82f6; color:#fff; }

/* 响应式 */
@media (max-width: 640px){
  .field-row {
    flex-wrap: wrap;
  }

  .label {
    flex-shrink: 0;
  }

  .input-field {
    flex: 1;
    min-width: 0;
    width: auto;
  }

  .grid-weekdays { gap:0.25rem; }
  .weekday-btn { min-width:2.5rem; min-height:2.5rem; font-size:0.75rem; }
}

/* 暗黑模式 */
@media (prefers-color-scheme: dark) {
  .label { color:#d1d5db; }
  .input-field { background:#1f2937; color:#d1d5db; border-color:#374151; }
  .input-field:focus { border-color:#3b82f6; box-shadow:0 0 0 2px rgba(59,130,246,0.5);}
  .input-error { border-color:#f87171; box-shadow:0 0 0 2px rgba(248,113,113,0.5);}
  .input-text { color:#9ca3af; }
  .error-message { color:#fca5a5; }
  .help-text, .text-counter { color:#9ca3af; }
  .weekday-btn { background:#374151; color:#d1d5db; }
  .weekday-btn:hover { background:#4b5563; }
  .weekday-btn.selected { background:#3b82f6; color:#fff; }
}
</style>
