<script setup lang="ts">
import {
  Accessibility,
  Angry,
  Annoyed,
  BedDouble,
  Bike,
  Cross,
  Droplet,
  DropletOff,
  Droplets,
  Dumbbell,
  Frown,
  Ghost,
  Laugh,
  Pill,
  Shield,
  ShieldX,
  Smile,
} from 'lucide-vue-next';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { deepDiff } from '@/utils/diff';
import { usePeriodValidation } from '../composables/usePeriodValidation';
import type {
  PeriodDailyRecordCreate,
  PeriodDailyRecords,
  PeriodDailyRecordUpdate,
} from '@/schema/health/period';
import type { Component } from 'vue';

interface PeriodOption<T extends string | number> {
  value: T;
  label: string;
  icon: Component;
}
// Props
interface Props {
  date?: string;
  record?: PeriodDailyRecords;
}

const props = withDefaults(defineProps<Props>(), {
  date: '',
  record: undefined,
});

// Emits
const emit = defineEmits<{
  create: [record: PeriodDailyRecordCreate];
  update: [serialNum: string, record: PeriodDailyRecordUpdate];
  cancel: [];
}>();

const { t } = useI18n();

// Store & Composables
const { validateDailyRecord, getFieldErrors, hasErrors, clearValidationErrors }
  = usePeriodValidation();

// Reactive state
const loading = ref(false);
const today = computed(() => DateUtils.getTodayDate());

const isEditing = computed(() => !!props.record);

// Form data
const formData = reactive<PeriodDailyRecords>({
  ...getPeriodDailyRecordDefault(),
  ...(props.record ? { ...toRaw(props.record) } : {}),
});

// Options
const FLOW_LEVELS: PeriodOption<'Light' | 'Medium' | 'Heavy'>[] = [
  {
    value: 'Light' as const,
    label: t('period.flowLevels.light'),
    icon: DropletOff,
  },
  {
    value: 'Medium' as const,
    label: t('period.flowLevels.medium'),
    icon: Droplet,
  },
  {
    value: 'Heavy' as const,
    label: t('period.flowLevels.heavy'),
    icon: Droplets,
  },
];

const MOODS: PeriodOption<'Happy' | 'Calm' | 'Sad' | 'Angry' | 'Anxious' | 'Irritable'>[] = [
  {
    value: 'Happy' as const,
    label: t('period.moods.happy'),
    icon: Laugh,
  },
  {
    value: 'Calm' as const,
    label: t('period.moods.calm'),
    icon: Smile,
  },
  {
    value: 'Sad' as const,
    label: t('period.moods.sad'),
    icon: Frown,
  },
  {
    value: 'Angry' as const,
    label: t('period.moods.angry'),
    icon: Angry,
  },
  {
    value: 'Anxious' as const,
    label: t('period.moods.anxious'),
    icon: Ghost,
  },
  {
    value: 'Irritable' as const,
    label: t('period.moods.irritable'),
    icon: Annoyed,
  },
];

const EXERCISE_INTENSITIES: PeriodOption<'None' | 'Light' | 'Medium' | 'Heavy'>[] = [
  {
    value: 'None' as const,
    label: t('period.exerciseIntensities.none'),
    icon: BedDouble,
  },
  {
    value: 'Light' as const,
    label: t('period.exerciseIntensities.light'),
    icon: Accessibility,
  },
  {
    value: 'Medium' as const,
    label: t('period.exerciseIntensities.medium'),
    icon: Bike,
  },
  {
    value: 'Heavy' as const,
    label: t('period.exerciseIntensities.heavy'),
    icon: Dumbbell,
  },
];

const CONTRACEPTION_METHODS: PeriodOption<'None' | 'Condom' | 'Pill' | 'Iud' | 'Other'>[] = [
  {
    value: 'None' as const,
    label: t('period.contraceptionMethods.none'),
    icon: ShieldX,
  },
  {
    value: 'Condom' as const,
    label: t('period.contraceptionMethods.condom'),
    icon: Shield,
  },
  {
    value: 'Pill' as const,
    label: t('period.contraceptionMethods.pill'),
    icon: Pill,
  },
  {
    value: 'Iud' as const,
    label: t('period.contraceptionMethods.iud'),
    icon: Cross,
  },
  {
    value: 'Other' as const,
    label: t('period.contraceptionMethods.other'),
    icon: Shield,
  },
];

const WATER_PRESETS = [1000, 1500, 2000, 2500] as const;
const SLEEP_PRESETS = [6, 7, 8, 9] as const;

// Methods
async function handleSubmit() {
  clearValidationErrors();

  if (!validateDailyRecord(formData)) {
    return;
  }

  loading.value = true;

  try {
    // 模拟创建完整记录对象用于回调
    const record: PeriodDailyRecordCreate = {
      periodSerialNum:
        props.record?.periodSerialNum || '',
      date: formData.date,
      flowLevel: formData.flowLevel,
      mood: formData.mood,
      exerciseIntensity: formData.exerciseIntensity,
      diet: formData.diet,
      waterIntake: formData.waterIntake,
      sleepHours: formData.sleepHours,
      sexualActivity: formData.sexualActivity,
      contraceptionMethod: formData.contraceptionMethod,
      notes: formData.notes || '',
    };
    record.date = DateUtils.toBackendDateTimeFromDateOnly(record.date);
    if (props.record) {
      const updatePeriodDailyRecord = deepDiff(props.record, record);
      if (Object.keys(updatePeriodDailyRecord).length > 0) {
        emit('update', props.record.serialNum, record);
      }
    } else {
      emit('create', record);
    }
    emit('cancel');
  } catch (error) {
    Lg.e('Period', 'Failed to save daily record:', error);
  } finally {
    loading.value = false;
  }
}

function getPeriodDailyRecordDefault(): PeriodDailyRecords {
  return {
    serialNum: '',
    periodSerialNum: '',
    date: DateUtils.getTodayDate(),
    flowLevel: null,
    sexualActivity: false,
    contraceptionMethod: 'None',
    exerciseIntensity: 'None',
    diet: '',
    mood: 'Happy',
    waterIntake: 0,
    sleepHours: 0,
    notes: null,
    createdAt: '',
    updatedAt: null,
  };
}

// Watchers
watch(
  () => props.record,
  record => {
    if (record?.date) {
      formData.date = record.date.split('T')[0];
    }
  },
  { deep: true, immediate: true },
);

// Expose methods for parent component
defineExpose({
  validateForm: () => validateDailyRecord(formData),
});
</script>

<template>
  <div class="period-daily-form p-6 card-base">
    <h2 class="text-lg text-gray-900 font-semibold mb-6 dark:text-white">
      {{ isEditing ? t('period.forms.editDaily') : t('period.forms.recordDaily') }}
    </h2>

    <form class="space-y-6" @submit.prevent="handleSubmit">
      <!-- 日期选择 -->
      <div class="form-group flex items-center justify-between" :title="t('period.fields.date')">
        <label class="form-label">
          <LucideCalendarCheck class="wh-5" />
        </label>
        <input
          v-model="formData.date" type="date" class="modal-input-select w-3/4" :max="today" required
          :disabled="isEditing"
        >
        <div v-if="getFieldErrors('date').length > 0" class="form-error">
          {{ getFieldErrors('date')[0] }}
        </div>
      </div>

      <!-- 经期流量 -->
      <div class="form-group flex items-center justify-between">
        <label
          class="form-label"
          :title="t('period.fields.flowLevel')"
        >
          <LucideDroplet class="wh-5" />
        </label>
        <div class="flex gap-2 w-3/4">
          <button
            v-for="level in FLOW_LEVELS" :key="level.value"
            type="button"
            class="p-3 border rounded-lg flex-1 transition-all"
            :class="[
              formData.flowLevel === level.value
                ? 'border-red-500 bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-400'
                : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500',
            ]" @click="formData.flowLevel = level.value"
          >
            <div class="flex justify-center" :title="level.label">
              <component :is="level.icon" class="wh-5" />
            </div>
          </button>
        </div>
      </div>

      <!-- 心情状态 -->
      <div class="form-group">
        <div class="flex justify-center justify-between">
          <label
            class="form-label"
            :title="t('period.fields.mood')"
          >
            <LucideSmile class="wh-5" />
          </label>
          <div class="gap-2 grid grid-cols-6 w-2/3">
            <button
              v-for="mood in MOODS" :key="mood.value"
              type="button"
              class="p-1 text-center border rounded-lg transition-all"
              :class="[
                formData.mood === mood.value
                  ? 'border-blue-500 bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400'
                  : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500',
              ]"
              @click="formData.mood = mood.value"
            >
              <div class="flex justify-center" :title="mood.label">
                <component :is="mood.icon" class="wh-5" />
              </div>
            </button>
          </div>
        </div>
      </div>

      <!-- 运动强度 -->
      <div class="form-group">
        <div class="flex items-center justify-between">
          <label class="form-label" :title="t('period.fields.exerciseIntensity')">
            <LucideDumbbell class="wh-5" />
          </label>
          <div class="flex gap-2">
            <button
              v-for="intensity in EXERCISE_INTENSITIES" :key="intensity.value" type="button"
              class="p-1 border rounded-lg flex-1 transition-all justify-center"
              :class="[
                formData.exerciseIntensity === intensity.value
                  ? 'border-green-500 bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                  : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500',
              ]"
              @click="formData.exerciseIntensity = intensity.value"
            >
              <div class="flex justify-center" :title="intensity.label">
                <component :is="intensity.icon" class="wh-5" />
              </div>
            </button>
          </div>
        </div>
      </div>

      <!-- 饮食记录 -->
      <div class="form-group">
        <label class="form-label" :title="t('period.fields.diet')">
          <LucideUtensils class="wh-5" />
        </label>
        <textarea
          v-model="formData.diet" class="input-base h-20 w-full resize-none"
          :placeholder="t('period.placeholders.dietRecord')" required
        />
        <div v-if="getFieldErrors('diet').length > 0" class="form-error">
          {{ getFieldErrors('diet')[0] }}
        </div>
      </div>

      <!-- 饮水量 -->
      <div class="form-group">
        <div class="flex items-center justify-between">
          <label class="form-label w-1/3" :title="t('period.fields.waterIntake')">
            <LucideWaves class="wh-5" />
          </label>
          <input
            v-model.number="formData.waterIntake"
            type="number"
            class="input-base"
            :placeholder="t('period.placeholders.waterIntakeExample')"
            min="0"
            max="5000"
            step="100"
          >
        </div>
        <div class="flex gap-4 items-center">
          <div class="flex gap-1">
            <button
              v-for="preset in WATER_PRESETS"
              :key="preset"
              type="button"
              class="text-sm btn-secondary px-2 py-1"
              :class="[
                formData.waterIntake === preset
                  ? '!bg-blue-100 !text-blue-700 !border-blue-500 !dark:bg-blue-900/30 !dark:text-blue-400'
                  : '',
              ]"

              @click="formData.waterIntake = preset"
            >
              {{ preset }}ml
            </button>
          </div>
        </div>
        <div v-if="getFieldErrors('waterIntake').length > 0" class="form-error">
          {{ getFieldErrors('waterIntake')[0] }}
        </div>
      </div>

      <!-- 睡眠时间 -->
      <div class="form-group flex items-center justify-between">
        <label class="form-label w-1/8" :title="t('period.fields.sleepHours')">
          <LucideBedDouble class="wh-5" />
        </label>
        <div class="flex gap-1 items-center">
          <input
            v-model.number="formData.sleepHours"
            type="number"
            class="input-base flex-1"
            :placeholder="t('period.placeholders.sleepExample')"
            min="0"
            max="24"
            step="0.5"
          >
          <div class="flex gap-1">
            <button
              v-for="preset in SLEEP_PRESETS"
              :key="preset"
              type="button"
              class="text-sm btn-secondary px-3 py-1"
              :class="[
                formData.sleepHours === preset
                  ? '!bg-blue-100 !text-blue-700 !border-blue-500 !dark:bg-blue-900/30 !dark:text-blue-400'
                  : '',
              ]"
              @click="formData.sleepHours = preset"
            >
              {{ preset }}h
            </button>
          </div>
        </div>
        <div v-if="getFieldErrors('sleepHours').length > 0" class="form-error">
          {{ getFieldErrors('sleepHours')[0] }}
        </div>
      </div>

      <!-- 性生活 -->
      <div class="form-group">
        <div class="mb-3 flex items-center justify-between">
          <label class="form-label" :title="t('period.fields.sexualActivity')">
            <LucideVenusAndMars class="wh-5" />
          </label>
          <div class="flex gap-4">
            <label class="flex gap-2 cursor-pointer items-center">
              <input v-model="formData.sexualActivity" type="radio" :value="true" class="radio-base">
              <span class="text-sm">{{ t('common.misc.yes') }}</span>
            </label>
            <label class="flex gap-2 cursor-pointer items-center">
              <input v-model="formData.sexualActivity" type="radio" :value="false" class="radio-base">
              <span class="text-sm">{{ t('common.misc.no') }}</span>
            </label>
          </div>
        </div>

        <!-- 避孕措施选项 - 仅在有性生活时显示 -->
        <div v-if="formData.sexualActivity" class="ml-6 pl-4 border-l-2 border-gray-200 space-y-2 dark:border-gray-600">
          <div class="text-xs text-gray-600 font-medium mb-1 dark:text-gray-400">
            {{ t('period.fields.contraceptionMethod') }}
          </div>
          <div class="gap-1 grid grid-cols-3">
            <label
              v-for="method in CONTRACEPTION_METHODS" :key="method.value" :title="method.label"
              class="p-1.5 border rounded flex cursor-pointer transition-colors items-center justify-center" :class="[
                formData.contraceptionMethod === method.value
                  ? 'border-purple-500 bg-purple-50 text-purple-700 dark:bg-purple-900/30 dark:text-purple-400'
                  : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500',
              ]"
            >
              <input v-model="formData.contraceptionMethod" type="radio" :value="method.value" class="sr-only">
              <div class="flex items-center">
                <component :is="method.icon" class="wh-3.5" />
              </div>
            </label>
          </div>
        </div>
      </div>

      <!-- 备注 -->
      <div class="form-group">
        <textarea
          v-model="formData.notes" class="input-base h-20 w-full resize-none"
          :placeholder="t('period.placeholders.notesPlaceholder')" maxlength="500"
        />
        <div class="text-sm text-gray-500 mt-1 flex justify-between">
          <div v-if="getFieldErrors('notes').length > 0" class="form-error">
            {{ getFieldErrors('notes')[0] }}
          </div>
          <div class="ml-auto">
            {{ (formData.notes || '').length }}/500
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="pt-2 flex justify-center space-x-6">
        <button type="button" class="btn-secondary" :disabled="loading" @click="$emit('cancel')">
          <LucideX class="wh-5" />
        </button>
        <button type="submit" class="btn-primary" :disabled="loading || hasErrors()">
          <LucideCheck class="wh-5" />
        </button>
      </div>
    </form>
  </div>
</template>

<style scoped lang="postcss">
.period-daily-form {
  max-height: 80vh;
  /* 根据需要调整高度 */
  overflow-y: scroll;
  -ms-overflow-style: none;
  /* IE 10+ */
  scrollbar-width: none;
  /* Firefox */
}

.period-daily-form::-webkit-scrollbar {
  display: none;
  /* Chrome, Safari, Edge */
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-label {
  display: flex;
  align-items: center;
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
}

.dark .form-label {
  color: #d1d5db;
}

.form-error {
  font-size: 0.875rem;
  color: #dc2626;
}

.dark .form-error {
  color: #f87171;
}

.input-base {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
}

.input-base:focus {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6;
  border-color: #3b82f6;
}

.dark .input-base {
  border-color: #4b5563;
  background-color: #1f2937;
  color: white;
}

.dark .input-base:focus {
  box-shadow: 0 0 0 2px #60a5fa;
  border-color: #60a5fa;
}

.radio-base {
  width: 1rem;
  height: 1rem;
  color: #2563eb;
  border: 1px solid #d1d5db;
  transition: all 0.2s ease-in-out;
}

.radio-base:focus {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6;
}

.dark .radio-base {
  border-color: #4b5563;
  background-color: #1f2937;
}

.dark .radio-base:focus {
  box-shadow: 0 0 0 2px #60a5fa;
}

.btn-primary {
  padding: 0.5rem 1rem;
  background-color: #2563eb;
  color: white;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-primary:hover {
  background-color: #1d4ed8;
}

.btn-primary:focus {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  padding: 0.5rem 1rem;
  background-color: #e5e7eb;
  color: #374151;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
  justify-content: center;
}

.btn-secondary:hover {
  background-color: #d1d5db;
}

.btn-secondary:focus {
  outline: none;
  box-shadow: 0 0 0 2px #6b7280;
}

.btn-secondary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.dark .btn-secondary {
  background-color: #374151;
  color: #d1d5db;
}

.dark .btn-secondary:hover {
  background-color: #4b5563;
}

.card-base {
  background-color: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.dark .card-base {
  background-color: #1f2937;
  border-color: #374151;
}

@media (max-width: 640px) {
  .grid-cols-3 {
    grid-template-columns: repeat(2, 1fr);
  }

  .flex-1 {
    font-size: 0.875rem;
  }
}
</style>
