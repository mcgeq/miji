<script setup lang="ts">
import { Checkbox, Input, Modal, Select } from '@/components/ui';
import { RepeatPeriodSchema, weekdays } from '@/schema/common';
import { buildRepeatPeriod } from '@/utils/business/repeat';
import type { SelectOption } from '@/components/ui';
import type { RepeatPeriod } from '@/schema/common';

const props = defineProps<{ repeat: RepeatPeriod; show: boolean }>();
const emit = defineEmits(['save', 'close']);
const { t } = useI18n();
const repeatObj = computed(() =>
  typeof props.repeat === 'string' ? JSON.parse(props.repeat) : props.repeat,
);

const form = ref<RepeatPeriod>(buildRepeatPeriod(repeatObj.value));

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

function resetForm() {
  form.value = {
    type: form.value.type,
    interval: 1,
    daysOfWeek: [],
    day: 1,
    month: 1,
    description: '',
  };
}

const monthlyDays = computed(() => {
  if (form.value.type === 'Monthly') {
    const year = new Date().getFullYear();
    // 这里按每月的第 interval 个月算可能语义不太对，应该是当月？
    const month = new Date().getMonth() + 1;
    const days = new Date(year, month, 0).getDate();
    return Array.from({ length: days }, (_, i) => i + 1);
  }
  return [];
});

const yearlyMonthDays = computed(() => {
  if (form.value.type === 'Yearly') {
    const year = new Date().getFullYear();
    const month = form.value.month;
    const days = new Date(year, month, 0).getDate();
    return Array.from({ length: days }, (_, i) => i + 1);
  }
  return [];
});

// 重复类型选项
const repeatTypeOptions = computed<SelectOption[]>(() => [
  { value: 'None', label: t('todos.repeat.types.no') },
  { value: 'Daily', label: t('todos.repeat.types.daily') },
  { value: 'Weekly', label: t('todos.repeat.types.weekly') },
  { value: 'Monthly', label: t('todos.repeat.types.monthly') },
  { value: 'Yearly', label: t('todos.repeat.types.yearly') },
  { value: 'Custom', label: t('todos.repeat.types.custom') },
]);

// 月份选项
const monthOptions = computed<SelectOption[]>(() =>
  monthNames.map((name, index) => ({
    value: index + 1,
    label: name,
  })),
);

// 月度日期选项
const monthlyDayOptions = computed<SelectOption[]>(() => [
  ...monthlyDays.value.map(n => ({ value: n, label: String(n) })),
  { value: 'last', label: 'Last day' },
]);

// 年度日期选项
const yearlyDayOptions = computed<SelectOption[]>(() =>
  yearlyMonthDays.value.map(n => ({ value: n, label: String(n) })),
);

function save() {
  try {
    const validatedData = RepeatPeriodSchema.parse(form.value);
    emit('save', validatedData);
    emit('close');
  } catch (error) {
    console.error('Validation failed:', error);
  }
}
</script>

<template>
  <Modal
    :open="show"
    title="设置重复"
    size="lg"
    @close="emit('close')"
    @confirm="save"
  >
    <div class="space-y-4">
      <!-- Repeat Type -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          {{ t('todos.repeat.title') }}
        </label>
        <Select
          v-model="form.type"
          :options="repeatTypeOptions"
          full-width
          @change="resetForm"
        />
      </div>

      <!-- Daily -->
      <div v-if="form.type === 'Daily'" class="space-y-2">
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          {{ t('todos.repeat.labels.daily') }}
        </label>
        <Input
          v-model="form.interval"
          type="number"
          required
          full-width
        />
      </div>

      <!-- Weekly -->
      <div v-if="form.type === 'Weekly'" class="space-y-3">
        <div>
          <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
            {{ t('todos.repeat.labels.weekly') }}
          </label>
          <Input
            v-model="form.interval"
            type="number"
            required
            full-width
          />
        </div>
        <div class="grid grid-cols-4 gap-2">
          <Checkbox
            v-for="day in weekdays"
            :key="day"
            v-model="form.daysOfWeek"
            :label="day"
            :value="day"
          />
        </div>
      </div>

      <!-- Monthly -->
      <div v-if="form.type === 'Monthly'" class="space-y-3">
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          {{ t('todos.repeat.labels.monthly') }}
        </label>
        <Input
          v-model="form.interval"
          type="number"
          required
          full-width
        />
        <Select
          v-model="form.day"
          :options="monthlyDayOptions"
          full-width
        />
      </div>

      <!-- Yearly -->
      <div v-if="form.type === 'Yearly'" class="space-y-3">
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          {{ t('todos.repeat.labels.yearly') }}
        </label>
        <Input
          v-model="form.interval"
          type="number"
          required
          full-width
        />
        <Select
          v-model="form.month"
          :options="monthOptions"
          full-width
        />
        <Select
          v-model="form.day"
          :options="yearlyDayOptions"
          full-width
        />
      </div>

      <!-- Custom -->
      <div v-if="form.type === 'Custom'" class="space-y-2">
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          {{ t('todos.repeat.types.custom') }}
        </label>
        <Input
          v-model="form.description"
          type="text"
          required
          full-width
        />
      </div>
    </div>
  </Modal>
</template>

<style scoped>
/* 所有样式已使用 Tailwind CSS 4 */
</style>
