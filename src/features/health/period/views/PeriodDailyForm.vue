<template>
  <div class="period-daily-form card-base p-6">
    <h2 class="text-lg font-semibold text-gray-900 dark:text-white mb-6">
      {{ isEditing ? '编辑' : '记录' }}日常状况
    </h2>

    <form @submit.prevent="handleSubmit" class="space-y-6">
      <!-- 日期选择 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-calendar wh-4 mr-2" />
          日期
        </label>
        <input v-model="formData.date" type="date" class="input-base w-full" :max="today" required />
        <div v-if="getFieldErrors('date').length > 0" class="form-error">
          {{ getFieldErrors('date')[0] }}
        </div>
      </div>

      <!-- 经期流量 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-droplet wh-4 mr-2" />
          经期流量
        </label>
        <div class="flex gap-2">
          <button v-for="level in flowLevels" :key="level.value" type="button" @click="formData.flowLevel = level.value"
            class="flex-1 p-3 rounded-lg border transition-all" :class="[
              formData.flowLevel === level.value
                ? 'border-red-500 bg-red-50 text-red-700 dark:bg-red-900/30 dark:text-red-400'
                : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500'
            ]">
            <i :class="level.icon" class="wh-5 mx-auto mb-1" />
            <div class="text-sm font-medium">{{ level.label }}</div>
          </button>
        </div>
      </div>

      <!-- 心情状态 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-mood-smile wh-4 mr-2" />
          心情状态
        </label>
        <div class="grid grid-cols-3 gap-2">
          <button v-for="mood in moods" :key="mood.value" type="button" @click="formData.mood = mood.value"
            class="p-3 rounded-lg border transition-all text-center" :class="[
              formData.mood === mood.value
                ? 'border-blue-500 bg-blue-50 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400'
                : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500'
            ]">
            <i :class="mood.icon" class="wh-5 mx-auto mb-1" />
            <div class="text-sm font-medium">{{ mood.label }}</div>
          </button>
        </div>
      </div>

      <!-- 运动强度 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-activity wh-4 mr-2" />
          运动强度
        </label>
        <div class="flex gap-2">
          <button v-for="intensity in exerciseIntensities" :key="intensity.value" type="button"
            @click="formData.exerciseIntensity = intensity.value" class="flex-1 p-3 rounded-lg border transition-all"
            :class="[
              formData.exerciseIntensity === intensity.value
                ? 'border-green-500 bg-green-50 text-green-700 dark:bg-green-900/30 dark:text-green-400'
                : 'border-gray-300 hover:border-gray-400 dark:border-gray-600 dark:hover:border-gray-500'
            ]">
            <i :class="intensity.icon" class="wh-5 mx-auto mb-1" />
            <div class="text-sm font-medium">{{ intensity.label }}</div>
          </button>
        </div>
      </div>

      <!-- 饮食记录 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-apple wh-4 mr-2" />
          饮食记录
        </label>
        <textarea v-model="formData.diet" class="input-base w-full h-20 resize-none" placeholder="记录今天的饮食情况..."
          required />
        <div v-if="getFieldErrors('diet').length > 0" class="form-error">
          {{ getFieldErrors('diet')[0] }}
        </div>
      </div>

      <!-- 饮水量 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-glass-water wh-4 mr-2" />
          饮水量 (ml)
        </label>
        <div class="flex items-center gap-4">
          <input v-model.number="formData.waterIntake" type="number" class="input-base flex-1" placeholder="例如: 2000"
            min="0" max="5000" step="100" />
          <div class="flex gap-2">
            <button v-for="preset in waterPresets" :key="preset" type="button" @click="formData.waterIntake = preset"
              class="btn-secondary text-sm px-3 py-1">
              {{ preset }}ml
            </button>
          </div>
        </div>
        <div v-if="getFieldErrors('waterIntake').length > 0" class="form-error">
          {{ getFieldErrors('waterIntake')[0] }}
        </div>
      </div>

      <!-- 睡眠时间 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-moon wh-4 mr-2" />
          睡眠时间 (小时)
        </label>
        <div class="flex items-center gap-4">
          <input v-model.number="formData.sleepHours" type="number" class="input-base flex-1" placeholder="例如: 8"
            min="0" max="24" step="0.5" />
          <div class="flex gap-2">
            <button v-for="preset in sleepPresets" :key="preset" type="button" @click="formData.sleepHours = preset"
              class="btn-secondary text-sm px-3 py-1">
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
        <label class="form-label">
          <i class="i-tabler-heart wh-4 mr-2" />
          性生活
        </label>
        <div class="flex gap-4">
          <label class="flex items-center gap-2 cursor-pointer">
            <input v-model="formData.sexualActivity" type="radio" :value="true" class="radio-base" />
            <span class="text-sm">是</span>
          </label>
          <label class="flex items-center gap-2 cursor-pointer">
            <input v-model="formData.sexualActivity" type="radio" :value="false" class="radio-base" />
            <span class="text-sm">否</span>
          </label>
        </div>
      </div>

      <!-- 备注 -->
      <div class="form-group">
        <label class="form-label">
          <i class="i-tabler-note wh-4 mr-2" />
          备注
        </label>
        <textarea v-model="formData.notes" class="input-base w-full h-20 resize-none" placeholder="记录其他想要记录的内容..."
          maxlength="500" />
        <div class="flex justify-between text-sm text-gray-500 mt-1">
          <div v-if="getFieldErrors('notes').length > 0" class="form-error">
            {{ getFieldErrors('notes')[0] }}
          </div>
          <div class="ml-auto">
            {{ (formData.notes || '').length }}/500
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="flex gap-3 pt-4">
        <button type="button" @click="$emit('cancel')" class="btn-secondary flex-1" :disabled="loading">
          取消
        </button>
        <button type="submit" class="btn-primary flex-1" :disabled="loading || hasErrors()">
          <i v-if="loading" class="i-tabler-loader-2 wh-4 mr-2 animate-spin" />
          {{ isEditing ? '更新' : '保存' }}
        </button>
      </div>
    </form>
  </div>
</template>

<script setup lang="ts">
import { usePeriodStore } from '@/stores/periodStore';
import type { PeriodDailyRecords, Mood } from '@/schema/health/period';
import { usePeriodValidation } from '../composables/usePeriodValidation';
import { ExerciseIntensity, FlowLevel } from '@/schema/common';

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

// Store & Composables
const periodStore = usePeriodStore();
const { validateDailyRecord, getFieldErrors, hasErrors, clearValidationErrors } =
  usePeriodValidation();

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
  notes: '',
});

// Options
const flowLevels = [
  { value: 'Light' as const, label: '轻量', icon: 'i-tabler-droplet' },
  { value: 'Medium' as const, label: '中量', icon: 'i-tabler-droplets' },
  { value: 'Heavy' as const, label: '大量', icon: 'i-tabler-droplets-filled' },
];

const moods = [
  { value: 'Happy' as const, label: '开心', icon: 'i-tabler-mood-happy' },
  { value: 'Calm' as const, label: '平静', icon: 'i-tabler-mood-smile' },
  { value: 'Sad' as const, label: '难过', icon: 'i-tabler-mood-sad' },
  { value: 'Angry' as const, label: '愤怒', icon: 'i-tabler-mood-angry' },
  { value: 'Anxious' as const, label: '焦虑', icon: 'i-tabler-mood-nervous' },
  { value: 'Irritable' as const, label: '易怒', icon: 'i-tabler-mood-annoyed' },
];

const exerciseIntensities = [
  { value: 'None' as const, label: '无', icon: 'i-tabler-sleep' },
  { value: 'Light' as const, label: '轻度', icon: 'i-tabler-walk' },
  { value: 'Medium' as const, label: '中度', icon: 'i-tabler-run' },
  { value: 'Heavy' as const, label: '高强度', icon: 'i-tabler-barbell' },
];

const waterPresets = [1000, 1500, 2000, 2500];
const sleepPresets = [6, 7, 8, 9];

// Methods
const handleSubmit = async () => {
  clearValidationErrors();

  if (!validateDailyRecord(formData.value)) {
    return;
  }

  loading.value = true;

  try {
    await periodStore.upsertDailyRecord(formData.value);

    // 模拟创建完整记录对象用于回调
    const record: PeriodDailyRecords = {
      serialNum:
        props.record?.serialNum || `daily_${Date.now()}`.padEnd(38, '0'),
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
      notes: formData.value.notes || '',
      createdAt: props.record?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    emit('submit', record);
  } catch (error) {
    console.error('Failed to save daily record:', error);
  } finally {
    loading.value = false;
  }
};

const resetForm = () => {
  formData.value = {
    date: props.date || today.value,
    flowLevel: null,
    mood: null,
    exerciseIntensity: 'None',
    diet: '',
    waterIntake: undefined,
    sleepHours: undefined,
    sexualActivity: false,
    notes: '',
  };
  clearValidationErrors();
};

// Initialize form data from existing record
const initializeForm = () => {
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
        notes: existingRecord.notes || '',
      };
    }
  }
};

// Watchers
watch(() => props.record, initializeForm, { immediate: true });
watch(
  () => props.date,
  (newDate) => {
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

<style scoped lang="postcss">
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
