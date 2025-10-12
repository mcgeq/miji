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
  <div class="period-daily-form">
    <h2 class="form-title">
      {{ isEditing ? t('period.forms.editDaily') : t('period.forms.recordDaily') }}
    </h2>

    <form class="form-container" @submit.prevent="handleSubmit">
      <!-- 日期选择 -->
      <div class="form-group" :title="t('period.fields.date')">
        <div class="form-row">
          <label class="form-label">
            <LucideCalendarCheck class="icon-size" />
          </label>
          <input
            v-model="formData.date" type="date" class="form-input form-input-wide" :max="today" required
            :disabled="isEditing"
          >
        </div>
        <div v-if="getFieldErrors('date').length > 0" class="form-error">
          {{ getFieldErrors('date')[0] }}
        </div>
      </div>

      <!-- 经期流量 -->
      <div class="form-group">
        <div class="form-row">
          <label
            class="form-label"
            :title="t('period.fields.flowLevel')"
          >
            <LucideDroplet class="icon-size" />
          </label>
          <div class="option-buttons option-buttons-wide">
            <button
              v-for="level in FLOW_LEVELS" :key="level.value"
              type="button"
              class="option-button"
              :class="[
                formData.flowLevel === level.value ? 'option-button-active option-button-error' : '',
              ]" @click="formData.flowLevel = level.value"
            >
              <div class="option-button-content" :title="level.label">
                <component :is="level.icon" class="icon-size" />
              </div>
            </button>
          </div>
        </div>
      </div>

      <!-- 心情状态 -->
      <div class="form-group">
        <div class="form-row">
          <label
            class="form-label"
            :title="t('period.fields.mood')"
          >
            <LucideSmile class="icon-size" />
          </label>
          <div class="mood-grid">
            <button
              v-for="mood in MOODS" :key="mood.value"
              type="button"
              class="option-button option-button-small"
              :class="[
                formData.mood === mood.value ? 'option-button-active option-button-info' : '',
              ]"
              @click="formData.mood = mood.value"
            >
              <div class="option-button-content" :title="mood.label">
                <component :is="mood.icon" class="icon-size" />
              </div>
            </button>
          </div>
        </div>
      </div>

      <!-- 运动强度 -->
      <div class="form-group">
        <div class="form-row">
          <label class="form-label" :title="t('period.fields.exerciseIntensity')">
            <LucideDumbbell class="icon-size" />
          </label>
          <div class="option-buttons option-buttons-wide">
            <button
              v-for="intensity in EXERCISE_INTENSITIES" :key="intensity.value" type="button"
              class="option-button option-button-small"
              :class="[
                formData.exerciseIntensity === intensity.value ? 'option-button-active option-button-success' : '',
              ]"
              @click="formData.exerciseIntensity = intensity.value"
            >
              <div class="option-button-content" :title="intensity.label">
                <component :is="intensity.icon" class="icon-size" />
              </div>
            </button>
          </div>
        </div>
      </div>

      <!-- 饮食记录 -->
      <div class="form-group">
        <label class="form-label" :title="t('period.fields.diet')">
          <LucideUtensils class="icon-size" />
        </label>
        <textarea
          v-model="formData.diet" class="form-textarea"
          :placeholder="t('period.placeholders.dietRecord')" required
        />
        <div v-if="getFieldErrors('diet').length > 0" class="form-error">
          {{ getFieldErrors('diet')[0] }}
        </div>
      </div>

      <!-- 饮水量 -->
      <div class="form-group">
        <div class="form-row">
          <label class="form-label form-label-narrow" :title="t('period.fields.waterIntake')">
            <LucideWaves class="icon-size" />
          </label>
          <input
            v-model.number="formData.waterIntake"
            type="number"
            class="form-input"
            :placeholder="t('period.placeholders.waterIntakeExample')"
            min="0"
            max="5000"
            step="100"
          >
        </div>
        <div class="preset-buttons-container">
          <div class="preset-buttons">
            <button
              v-for="preset in WATER_PRESETS"
              :key="preset"
              type="button"
              class="preset-button"
              :class="[
                formData.waterIntake === preset ? 'preset-button-active' : '',
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
      <div class="form-group">
        <div class="form-row">
          <label class="form-label form-label-narrow" :title="t('period.fields.sleepHours')">
            <LucideBedDouble class="icon-size" />
          </label>
          <div class="sleep-input-group">
            <input
              v-model.number="formData.sleepHours"
              type="number"
              class="form-input form-input-flex"
              :placeholder="t('period.placeholders.sleepExample')"
              min="0"
              max="24"
              step="0.5"
            >
            <div class="preset-buttons">
              <button
                v-for="preset in SLEEP_PRESETS"
                :key="preset"
                type="button"
                class="preset-button"
                :class="[
                  formData.sleepHours === preset ? 'preset-button-active' : '',
                ]"
                @click="formData.sleepHours = preset"
              >
                {{ preset }}h
              </button>
            </div>
          </div>
        </div>
        <div v-if="getFieldErrors('sleepHours').length > 0" class="form-error">
          {{ getFieldErrors('sleepHours')[0] }}
        </div>
      </div>

      <!-- 性生活 -->
      <div class="form-group">
        <div class="sexual-activity-header">
          <label class="form-label" :title="t('period.fields.sexualActivity')">
            <LucideVenusAndMars class="icon-size" />
          </label>
          <div class="radio-group">
            <label class="radio-label">
              <input v-model="formData.sexualActivity" type="radio" :value="true" class="radio-input">
              <span class="radio-text">{{ t('common.misc.yes') }}</span>
            </label>
            <label class="radio-label">
              <input v-model="formData.sexualActivity" type="radio" :value="false" class="radio-input">
              <span class="radio-text">{{ t('common.misc.no') }}</span>
            </label>
          </div>
        </div>

        <!-- 避孕措施选项 - 仅在有性生活时显示 -->
        <div v-if="formData.sexualActivity" class="contraception-section">
          <div class="contraception-title">
            {{ t('period.fields.contraceptionMethod') }}
          </div>
          <div class="contraception-grid">
            <label
              v-for="method in CONTRACEPTION_METHODS" :key="method.value" :title="method.label"
              class="contraception-option"
              :class="[
                formData.contraceptionMethod === method.value ? 'contraception-option-active' : '',
              ]"
            >
              <input v-model="formData.contraceptionMethod" type="radio" :value="method.value" class="visually-hidden">
              <div class="contraception-icon">
                <component :is="method.icon" class="icon-size-small" />
              </div>
            </label>
          </div>
        </div>
      </div>

      <!-- 备注 -->
      <div class="form-group">
        <textarea
          v-model="formData.notes" class="form-textarea"
          :placeholder="t('period.placeholders.notesPlaceholder')" maxlength="500"
        />
        <div class="notes-footer">
          <div v-if="getFieldErrors('notes').length > 0" class="form-error">
            {{ getFieldErrors('notes')[0] }}
          </div>
          <div class="character-count">
            {{ (formData.notes || '').length }}/500
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div class="form-actions">
        <button type="button" class="action-button action-button-secondary" :disabled="loading" @click="$emit('cancel')">
          <LucideX class="icon-size" />
        </button>
        <button type="submit" class="action-button action-button-primary" :disabled="loading || hasErrors()">
          <LucideCheck class="icon-size" />
        </button>
      </div>
    </form>
  </div>
</template>

<style scoped lang="postcss">
/* 容器样式 */
.period-daily-form {
  max-height: 80vh;
  overflow-y: scroll;
  -ms-overflow-style: none;
  scrollbar-width: none;
  padding: 1.5rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.period-daily-form::-webkit-scrollbar {
  display: none;
}

.dark .period-daily-form {
  background-color: var(--color-base-200);
  border-color: var(--color-base-300);
}

/* 标题 */
.form-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 1.5rem;
}

.dark .form-title {
  color: var(--color-base-content);
}

/* 表单容器 */
.form-container {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 表单组 */
.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* 标签 */
.form-label {
  display: flex;
  align-items: center;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.form-label-narrow {
  width: 33.333%;
}

.dark .form-label {
  color: var(--color-base-content);
}

/* 图标尺寸 */
.icon-size {
  width: 1.25rem;
  height: 1.25rem;
}

.icon-size-small {
  width: 0.875rem;
  height: 0.875rem;
}

/* 错误提示 */
.form-error {
  font-size: 0.875rem;
  color: var(--color-error);
}

.dark .form-error {
  color: var(--color-error-content);
}

/* 输入框 */
.form-input {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  transition: all 0.2s ease-in-out;
}

.form-input-wide {
  width: 75%;
}

.form-input-flex {
  flex: 1;
}

.form-input:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary);
  border-color: var(--color-primary);
}

.dark .form-input {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.dark .form-input:focus {
  box-shadow: 0 0 0 2px var(--color-primary);
  border-color: var(--color-primary);
}

/* 文本域 */
.form-textarea {
  width: 100%;
  height: 5rem;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  resize: none;
  transition: all 0.2s ease-in-out;
}

.form-textarea:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary);
  border-color: var(--color-primary);
}

.dark .form-textarea {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.dark .form-textarea:focus {
  box-shadow: 0 0 0 2px var(--color-primary);
  border-color: var(--color-primary);
}

/* 选项按钮组 */
.option-buttons {
  display: flex;
  gap: 0.5rem;
}

.option-buttons-wide {
  width: 75%;
  display: flex;
  gap: 0.5rem;
}

.option-button {
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  flex: 1;
  background-color: var(--color-base-100);
  transition: all 0.2s ease-in-out;
  cursor: pointer;
}

.option-button-small {
  padding: 0.25rem;
}

.option-button:hover {
  border-color: var(--color-neutral);
}

.dark .option-button {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
}

.dark .option-button:hover {
  border-color: var(--color-neutral-content);
}

.option-button-active {
  font-weight: 600;
}

.option-button-error.option-button-active {
  border-color: var(--color-error);
  background-color: var(--color-error);
  color: var(--color-error-content);
}

.dark .option-button-error.option-button-active {
  background-color: color-mix(in oklch, var(--color-error) 30%, transparent);
  color: var(--color-error-content);
}

.option-button-info.option-button-active {
  border-color: var(--color-info);
  background-color: var(--color-info);
  color: var(--color-info-content);
}

.dark .option-button-info.option-button-active {
  background-color: color-mix(in oklch, var(--color-info) 30%, transparent);
  color: var(--color-info-content);
}

.option-button-success.option-button-active {
  border-color: var(--color-success);
  background-color: var(--color-success);
  color: var(--color-success-content);
}

.dark .option-button-success.option-button-active {
  background-color: color-mix(in oklch, var(--color-success) 30%, transparent);
  color: var(--color-success-content);
}

.option-button-content {
  display: flex;
  justify-content: center;
}

/* 心情网格 */
.mood-grid {
  width: 66.666%;
  display: grid;
  grid-template-columns: repeat(6, 1fr);
  gap: 0.5rem;
}

/* 预设按钮 */
.preset-buttons-container {
  display: flex;
  gap: 1rem;
  align-items: center;
}

.preset-buttons {
  display: flex;
  gap: 0.25rem;
}

.preset-button {
  padding: 0.25rem 0.5rem;
  font-size: 0.875rem;
  background-color: var(--color-secondary);
  color: var(--color-secondary-content);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
  transition: all 0.2s ease-in-out;
  cursor: pointer;
}

.preset-button:hover {
  background-color: color-mix(in oklch, var(--color-secondary) 80%, black);
}

.dark .preset-button {
  background-color: var(--color-secondary);
  color: var(--color-secondary-content);
}

.dark .preset-button:hover {
  background-color: color-mix(in oklch, var(--color-secondary) 70%, white);
}

.preset-button-active {
  background-color: var(--color-info) !important;
  color: var(--color-info-content) !important;
  border-color: var(--color-info) !important;
}

.dark .preset-button-active {
  background-color: color-mix(in oklch, var(--color-info) 30%, transparent) !important;
  color: var(--color-info-content) !important;
}

/* 睡眠输入组 */
.sleep-input-group {
  display: flex;
  gap: 0.25rem;
  align-items: center;
  flex: 1;
}

/* 单选按钮 */
.radio-group {
  display: flex;
  gap: 1rem;
}

.radio-label {
  display: flex;
  gap: 0.5rem;
  align-items: center;
  cursor: pointer;
}

.radio-input {
  width: 1rem;
  height: 1rem;
  color: var(--color-primary);
  border: 1px solid var(--color-base-300);
  transition: all 0.2s ease-in-out;
}

.radio-input:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary);
}

.dark .radio-input {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
}

.dark .radio-input:focus {
  box-shadow: 0 0 0 2px var(--color-primary);
}

.radio-text {
  font-size: 0.875rem;
  color: var(--color-base-content);
}

.dark .radio-text {
  color: var(--color-base-content);
}

/* 性活动头部 */
.sexual-activity-header {
  margin-bottom: 0.75rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* 避孕措施部分 */
.contraception-section {
  margin-left: 1.5rem;
  padding-left: 1rem;
  border-left: 2px solid var(--color-base-300);
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.dark .contraception-section {
  border-color: var(--color-base-300);
}

.contraception-title {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-neutral);
  margin-bottom: 0.25rem;
}

.dark .contraception-title {
  color: var(--color-neutral-content);
}

.contraception-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 0.25rem;
}

.contraception-option {
  padding: 0.375rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.contraception-option:hover {
  border-color: var(--color-neutral);
}

.dark .contraception-option {
  border-color: var(--color-base-300);
}

.dark .contraception-option:hover {
  border-color: var(--color-neutral-content);
}

.contraception-option-active {
  border-color: var(--color-accent);
  background-color: var(--color-accent);
  color: var(--color-accent-content);
}

.dark .contraception-option-active {
  background-color: color-mix(in oklch, var(--color-accent) 30%, transparent);
  color: var(--color-accent-content);
}

.contraception-icon {
  display: flex;
  align-items: center;
}

.visually-hidden {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

/* 备注底部 */
.notes-footer {
  display: flex;
  justify-content: space-between;
  font-size: 0.875rem;
  color: var(--color-neutral);
  margin-top: 0.25rem;
}

.dark .notes-footer {
  color: var(--color-neutral-content);
}

.character-count {
  margin-left: auto;
}

/* 操作按钮 */
.form-actions {
  padding-top: 0.5rem;
  display: flex;
  justify-content: center;
  gap: 1.5rem;
}

.action-button {
  padding: 0.5rem 1rem;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  cursor: pointer;
}

.action-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-button-primary {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

.action-button-primary:hover {
  background-color: color-mix(in oklch, var(--color-primary) 85%, black);
}

.action-button-primary:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary);
}

.dark .action-button-primary {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

.action-button-secondary {
  background-color: var(--color-secondary);
  color: var(--color-secondary-content);
}

.action-button-secondary:hover {
  background-color: color-mix(in oklch, var(--color-secondary) 80%, black);
}

.action-button-secondary:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-secondary);
}

.dark .action-button-secondary {
  background-color: var(--color-secondary);
  color: var(--color-secondary-content);
}

.dark .action-button-secondary:hover {
  background-color: color-mix(in oklch, var(--color-secondary) 70%, white);
}

/* 响应式设计 */
@media (max-width: 640px) {
  .contraception-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .mood-grid {
    grid-template-columns: repeat(3, 1fr);
  }

  .form-input-wide {
    width: 100%;
  }

  .option-buttons-wide {
    width: 100%;
  }

  .mood-grid {
    width: 100%;
  }
}
</style>
