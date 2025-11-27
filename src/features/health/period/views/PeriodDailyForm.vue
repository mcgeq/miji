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
import IconButtonGroup from '@/components/common/IconButtonGroup.vue';
import PresetButtons from '@/components/common/PresetButtons.vue';
import { Modal } from '@/components/ui';
import FormRow from '@/components/ui/FormRow.vue';
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
const { validateDailyRecord, getFieldErrors, hasErrors, clearValidationErrors, clearFieldError }
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

const WATER_PRESETS: number[] = [1000, 1500, 2000, 2500];
const SLEEP_PRESETS: number[] = [6, 7, 8, 9];

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
      } else {
        // 如果没有更改，直接关闭表单
        emit('cancel');
      }
    } else {
      emit('create', record);
    }
    // 移除了 emit('cancel')，让父组件在操作完成后再关闭
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
    waterIntake: 1500,
    sleepHours: 8,
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
  <Modal
    :open="true"
    :title="isEditing ? t('period.forms.editDaily') : t('period.forms.recordDaily')"
    size="md"
    :confirm-loading="loading"
    :confirm-disabled="hasErrors()"
    @confirm="handleSubmit"
    @close="$emit('cancel')"
  >
    <!-- 日期选择 -->
    <FormRow :label="t('period.fields.date')" required :error="getFieldErrors('date')[0]">
      <input
        v-model="formData.date"
        type="date"
        class="modal-input-select w-full"
        :max="today"
        :disabled="isEditing"
        @change="clearFieldError('date')"
      >
    </FormRow>

    <!-- 经期流量 -->
    <FormRow :label="t('period.fields.flowLevel')">
      <IconButtonGroup
        v-model="formData.flowLevel"
        :options="FLOW_LEVELS"
        grid-cols="3"
        theme="error"
        size="medium"
      />
    </FormRow>

    <!-- 心情状态 -->
    <FormRow :label="t('period.fields.mood')">
      <IconButtonGroup
        v-model="formData.mood"
        :options="MOODS"
        grid-cols="6"
        theme="info"
        size="small"
      />
    </FormRow>

    <!-- 运动强度 -->
    <FormRow :label="t('period.fields.exerciseIntensity')">
      <IconButtonGroup
        v-model="formData.exerciseIntensity"
        :options="EXERCISE_INTENSITIES"
        grid-cols="4"
        theme="success"
        size="small"
      />
    </FormRow>

    <!-- 饮食记录 -->
    <FormRow label="" full-width :error="getFieldErrors('diet')[0]">
      <textarea
        v-model="formData.diet"
        class="modal-input-select w-full"
        :placeholder="t('period.placeholders.dietRecord')"
        rows="3"
        @input="clearFieldError('diet')"
      />
    </FormRow>

    <!-- 饮水量 -->
    <FormRow :label="t('period.fields.waterIntake')" :error="getFieldErrors('waterIntake')[0]">
      <div class="form-field-with-presets">
        <input
          v-model.number="formData.waterIntake"
          type="number"
          class="modal-input-select w-full"
          :placeholder="t('period.placeholders.waterIntakeExample')"
          min="0"
          max="5000"
          step="100"
          @input="clearFieldError('waterIntake')"
        >
        <PresetButtons
          v-model="formData.waterIntake"
          :presets="WATER_PRESETS"
          suffix="ml"
        />
      </div>
    </FormRow>

    <!-- 睡眠时间 -->
    <FormRow :label="t('period.fields.sleepHours')" :error="getFieldErrors('sleepHours')[0]">
      <div class="form-field-with-presets">
        <input
          v-model.number="formData.sleepHours"
          type="number"
          class="modal-input-select w-full"
          :placeholder="t('period.placeholders.sleepExample')"
          min="0"
          max="24"
          step="1"
          @input="clearFieldError('sleepHours')"
        >
        <PresetButtons
          v-model="formData.sleepHours"
          :presets="SLEEP_PRESETS"
          suffix="h"
        />
      </div>
    </FormRow>

    <!-- 性生活 -->
    <FormRow :label="t('period.fields.sexualActivity')">
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
    </FormRow>

    <!-- 避孕措施 - 仅在有性生活时显示 -->
    <FormRow v-if="formData.sexualActivity" :label="t('period.fields.contraceptionMethod')">
      <IconButtonGroup
        v-model="formData.contraceptionMethod"
        :options="CONTRACEPTION_METHODS"
        grid-cols="5"
        theme="primary"
        size="small"
      />
    </FormRow>

    <!-- 备注 -->
    <FormRow label="" full-width :error="getFieldErrors('notes')[0]">
      <textarea
        v-model="formData.notes"
        class="modal-input-select w-full"
        :placeholder="t('period.placeholders.notesPlaceholder')"
        maxlength="500"
        rows="3"
        @input="clearFieldError('notes')"
      />
      <div class="character-count">
        {{ (formData.notes || '').length }}/500
      </div>
    </FormRow>
  </Modal>
</template>

<style scoped>
/* 自定义样式 - 大部分样式已由BaseModal和FormRow提供 */

/* 表单字段带预设按钮 */
.form-field-with-presets {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  width: 100%;
}

/* Radio 按钮组 */
.radio-group {
  display: flex;
  gap: 1rem;
}

.radio-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.radio-input {
  width: 1rem;
  height: 1rem;
  cursor: pointer;
}

.radio-text {
  font-size: 0.875rem;
  color: var(--color-base-content);
}

/* 字符计数 */
.character-count {
  font-size: 0.75rem;
  color: var(--color-neutral);
  text-align: right;
  margin-top: 0.25rem;
}

/* 深色模式 */
.dark .radio-text,
.dark .character-count {
  color: var(--color-base-content);
}
</style>
