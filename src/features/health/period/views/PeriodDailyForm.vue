<script setup lang="ts">
import {
  Accessibility,
  Angry,
  Annoyed,
  BedDouble,
  Bike,
  CalendarCheck,
  Check,
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
  Utensils,
  VenusAndMars,
  Waves,
  X,
} from 'lucide-vue-next';
import { usePeriodStore } from '@/stores/periodStore';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { uuid } from '@/utils/uuid';
import { usePeriodValidation } from '../composables/usePeriodValidation';
import type { ExerciseIntensity, FlowLevel } from '@/schema/common';
import type {
  ContraceptionMethod,
  Mood,
  PeriodDailyRecords,
} from '@/schema/health/period';

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
  submit: [record: PeriodDailyRecords];
  cancel: [];
}>();

const { t } = useI18n();

// Store & Composables
const periodStore = usePeriodStore();
const { validateDailyRecord, getFieldErrors, hasErrors, clearValidationErrors }
  = usePeriodValidation();

// Reactive state
const loading = ref(false);
const today = computed(() => new Date().toISOString().split('T')[0]);

const isEditing = computed(() => !!props.record);

// Form data
const formData = ref({
  date: props.date || today.value,
  flowLevel: null as FlowLevel | null,
  mood: null as Mood | null,
  exerciseIntensity: 'None' as ExerciseIntensity,
  diet: '',
  waterIntake: undefined as number | undefined,
  sleepHours: undefined as number | undefined,
  sexualActivity: false,
  contraceptionMethod: 'None' as ContraceptionMethod, // This was missing!
  notes: '',
});

// Options
const flowLevels = [
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

const moods = [
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

const exerciseIntensities = [
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

const contraceptionMethods = [
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

const waterPresets = [1000, 1500, 2000, 2500];
const sleepPresets = [6, 7, 8, 9];

// Methods
async function handleSubmit() {
  clearValidationErrors();

  if (!validateDailyRecord(formData.value)) {
    return;
  }

  loading.value = true;

  try {
    await periodStore.upsertDailyRecord(formData.value);
    const recordDateTime = DateUtils.getLocalISODateTimeWithOffset();
    // 模拟创建完整记录对象用于回调
    const record: PeriodDailyRecords = {
      serialNum: props.record?.serialNum || uuid(38),
      periodSerialNum:
        props.record?.periodSerialNum || 'period_current'.padEnd(38, '0'),
      date: formData.value.date,
      flowLevel: formData.value.flowLevel,
      mood: formData.value.mood,
      exerciseIntensity: formData.value.exerciseIntensity,
      diet: formData.value.diet,
      waterIntake: formData.value.waterIntake,
      sleepHours: formData.value.sleepHours,
      sexualActivity: formData.value.sexualActivity,
      contraceptionMethod: formData.value.contraceptionMethod,
      notes: formData.value.notes || '',
      createdAt: props.record?.createdAt || recordDateTime,
      updatedAt: recordDateTime,
    };

    emit('submit', record);
  } catch (error) {
    Lg.e('Period', 'Failed to save daily record:', error);
  } finally {
    loading.value = false;
  }
}

function resetForm() {
  formData.value = {
    date: props.date || today.value,
    flowLevel: null,
    mood: null,
    exerciseIntensity: 'None',
    diet: '',
    waterIntake: undefined,
    sleepHours: undefined,
    sexualActivity: false,
    contraceptionMethod: 'None',
    notes: '',
  };
  clearValidationErrors();
}

// Initialize form data from existing record
function initializeForm() {
  if (props.record) {
    formData.value = {
      date: props.record.date,
      flowLevel: props.record.flowLevel ?? null,
      mood: props.record.mood ?? null,
      exerciseIntensity: props.record.exerciseIntensity,
      diet: props.record.diet,
      waterIntake: props.record.waterIntake,
      sleepHours: props.record.sleepHours,
      sexualActivity: props.record.sexualActivity,
      contraceptionMethod: props.record.contraceptionMethod ?? 'None', // Add this line
      notes: props.record.notes || '',
    };
  } else if (props.date) {
    // 尝试加载该日期的现有记录
    const existingRecord = periodStore.getDailyRecord(props.date);
    if (existingRecord) {
      // 递归调用，但这次 props.record 会有值
      formData.value = {
        date: existingRecord.date,
        flowLevel: existingRecord.flowLevel ?? null,
        mood: existingRecord.mood ?? null,
        exerciseIntensity: existingRecord.exerciseIntensity,
        diet: existingRecord.diet,
        waterIntake: existingRecord.waterIntake,
        sleepHours: existingRecord.sleepHours,
        sexualActivity: existingRecord.sexualActivity,
        contraceptionMethod: existingRecord.contraceptionMethod ?? 'None',
        notes: existingRecord.notes || '',
      };
    }
  }
}

// Watchers
watch(() => props.record, initializeForm, { immediate: true });
watch(
  () => props.date,
  newDate => {
    if (newDate && !props.record) {
      formData.value.date = newDate;
      const existingRecord = periodStore.getDailyRecord(newDate);
      if (existingRecord) {
        initializeForm();
      }
    }
  },
);

// Lifecycle
onMounted(() => {
  initializeForm();
});

// Expose methods for parent component
defineExpose({
  resetForm,
  validateForm: () => validateDailyRecord(formData.value),
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
          <CalendarCheck class="wh-5" />
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
        <label class="form-label" :title="t('period.fields.flowLevel')">
          <Droplet class="wh-5" />
        </label>
        <div class="flex gap-2 w-3/4">
          <button
            v-for="level in flowLevels" :key="level.value" type="button" class="p-3 border rounded-lg flex-1 transition-all"
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
      <div class="form-group flex justify-center justify-between">
        <label class="form-label" :title="t('period.fields.mood')">
          <Smile class="wh-5" />
        </label>
        <div class="gap-2 grid grid-cols-6">
          <button
            v-for="mood in moods" :key="mood.value" type="button" class="p-1 text-center border rounded-lg transition-all"
            :class="[
              formData.mood === mood.value
                ? 'border-blue-500 bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400'
                : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500',
            ]" @click="formData.mood = mood.value"
          >
            <div class="flex justify-center" :title="mood.label">
              <component :is="mood.icon" class="mb-1 wh-5" />
            </div>
          </button>
        </div>
      </div>

      <!-- 运动强度 -->
      <div class="form-group">
        <div class="flex items-center justify-between">
          <label class="form-label" :title="t('period.fields.exerciseIntensity')">
            <Dumbbell class="wh-5" />
          </label>
          <div class="flex gap-2">
            <button
              v-for="intensity in exerciseIntensities" :key="intensity.value" type="button"
              class="p-1 border rounded-lg flex-1 transition-all justify-center"
              :class="[
                formData.exerciseIntensity === intensity.value
                  ? 'border-green-500 bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                  : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500',
              ]" @click="formData.exerciseIntensity = intensity.value"
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
          <Utensils class="wh-5" />
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
            <Waves class="wh-5" />
          </label>
          <input
            v-model.number="formData.waterIntake" type="number" class="input-base"
            :placeholder="t('period.placeholders.waterIntakeExample')" min="0" max="5000" step="100"
          >
        </div>
        <div class="flex gap-4 items-center">
          <div class="flex gap-1">
            <button
              v-for="preset in waterPresets" :key="preset" type="button" class="text-sm btn-secondary px-2 py-1"
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
          <BedDouble class="wh-5" />
        </label>
        <div class="flex gap-1 items-center">
          <input
            v-model.number="formData.sleepHours" type="number" class="input-base flex-1"
            :placeholder="t('period.placeholders.sleepExample')" min="0" max="24" step="0.5"
          >
          <div class="flex gap-1">
            <button
              v-for="preset in sleepPresets" :key="preset" type="button" class="text-sm btn-secondary px-3 py-1"
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
            <VenusAndMars class="wh-5" />
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
              v-for="method in contraceptionMethods" :key="method.value" :title="method.label"
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
          <X class="wh-5" />
        </button>
        <button type="submit" class="btn-primary" :disabled="loading || hasErrors()">
          <Check class="wh-5" />
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
  @apply space-y-2;
}

.form-label {
  @apply flex items-center text-sm font-medium text-gray-700 dark:text-gray-300;
}

.form-error {
  @apply text-sm text-red-600 dark:text-red-400;
}

.input-base {
  @apply w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:focus:ring-blue-400 dark:focus:border-blue-400 transition-colors;
}

.radio-base {
  @apply w-4 h-4 text-blue-600 border-gray-300 focus:ring-blue-500 focus:ring-2 dark:border-gray-600 dark:bg-gray-800 dark:focus:ring-blue-400;
}

.btn-primary {
  @apply px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center justify-center;
}

.btn-secondary {
  @apply px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 focus:ring-2 focus:ring-gray-500 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600 transition-colors flex items-center justify-center;
}

.card-base {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm;
}

@media (max-width: 640px) {
  .grid-cols-3 {
    @apply grid-cols-2;
  }

  .flex-1 {
    @apply text-sm;
  }
}
</style>
