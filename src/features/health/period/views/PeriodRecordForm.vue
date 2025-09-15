<script setup lang="ts">
import ConfirmDialog from '@/components/common/ConfirmDialog.vue';
import InputError from '@/components/common/InputError.vue';
import WarningDialog from '@/components/common/WarningDialog.vue';
import { usePeriodStore } from '@/stores/periodStore';
import { DateUtils } from '@/utils/date';
import { deepDiff } from '@/utils/diff';
import { usePeriodValidation } from '../composables/usePeriodValidation';
import { durationPresets, intensityLevels, symptomGroups } from '../constants/periodConstants';
import {
  PeriodCalculator,
  PeriodDateUtils,
  PeriodFormatter,
  PeriodValidator,
} from '../utils/periodUtils';
import type { Intensity, SymptomsType } from '@/schema/common';
import type { PeriodRecordCreate, PeriodRecords, PeriodRecordUpdate } from '@/schema/health/period';

// Props
interface Props {
  record?: PeriodRecords;
  autoFocus?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  record: undefined,
  autoFocus: true,
});

// Emits
const emit = defineEmits<{
  create: [periodRecord: PeriodRecordCreate];
  update: [serialNum: string, periodRecord: PeriodRecordUpdate];
  delete: [serialNum: string];
  cancel: [];
}>();

// Store & Composables
const periodStore = usePeriodStore();
const { validatePeriodRecord, getFieldErrors, hasErrors, clearValidationErrors }
  = usePeriodValidation();

// Reactive state
const loading = ref(false);
const showDeleteConfirm = ref(false);
const showOverlapWarning = ref(false);
const overlapRecord = ref<PeriodRecords | null>(null);

// Form data
const formData = reactive<PeriodRecords>({
  ...getPeriodRecordDefault(),
  ...(props.record ? { ...toRaw(props.record) } : {}),
});

const symptoms = ref<Record<SymptomsType, Intensity | null>>({
  Pain: null,
  Fatigue: null,
  MoodSwing: null,
});

// Computed
const isEditing = computed(() => !!props.record);

const maxDate = computed(() => DateUtils.getTodayDate());

const periodDuration = computed(() => {
  if (!formData.startDate || !formData.endDate)
    return 0;
  return (
    DateUtils.daysBetween(formData.startDate, formData.endDate) + 1
  );
});

const showPeriodInfo = computed(() => {
  return (
    formData.startDate
    && formData.endDate
    && periodDuration.value > 0
  );
});

const cycleLength = computed(() => {
  if (!formData.startDate || periodStore.periodRecords.length === 0)
    return 0;

  const currentStart = new Date(formData.startDate);
  const lastRecord = periodStore.periodRecords
    .filter(record => record.serialNum !== props.record?.serialNum)
    .sort(
      (a, b) =>
        new Date(b.startDate).getTime() - new Date(a.startDate).getTime(),
    )[0];

  if (!lastRecord)
    return 0;

  const lastStart = new Date(lastRecord.startDate);
  return Math.ceil(
    (currentStart.getTime() - lastStart.getTime()) / (1000 * 60 * 60 * 24),
  );
});

const cycleText = computed(() => {
  if (cycleLength.value === 0)
    return '首次记录';
  return PeriodFormatter.formatCycleDescription(cycleLength.value);
});

const cycleColorClass = computed(() => {
  const length = cycleLength.value;
  if (length === 0)
    return 'text-gray-500';
  if (length < 21)
    return 'text-orange-500';
  if (length > 35)
    return 'text-red-500';
  return 'text-green-500';
});

const predictedNext = computed(() => {
  if (!formData.startDate || !periodStore.periodStats.averageCycleLength)
    return '';

  const nextDate = PeriodCalculator.predictNextPeriod(
    {
      ...formData,
      serialNum: '',
      createdAt: '',
      updatedAt: null,
    } as PeriodRecords,
    periodStore.periodStats.averageCycleLength,
  );

  return PeriodDateUtils.formatChineseDate(nextDate);
});

const notesLength = computed(() => (formData.notes || '').length);

const hasFieldError = (field: string) => getFieldErrors(field).length > 0;

const canSubmit = computed(() => {
  return (
    formData.startDate
    && formData.endDate
    && !hasErrors()
    && periodDuration.value > 0
    && periodDuration.value <= 14
  );
});

const deletionInfo = computed(() => {
  if (!props.record)
    return { dateRange: '', duration: '' };

  return {
    dateRange: PeriodDateUtils.formatDateRange(
      props.record.startDate,
      props.record.endDate,
    ),
    duration: PeriodFormatter.formatDuration(
      PeriodCalculator.calculatePeriodLength(props.record),
    ),
  };
});

const overlapInfo = computed(() => {
  if (!overlapRecord.value)
    return { dateRange: '' };

  return {
    dateRange: PeriodDateUtils.formatDateRange(
      overlapRecord.value.startDate,
      overlapRecord.value.endDate,
    ),
  };
});

// Methods
function setDurationPreset(days: number) {
  if (!formData.startDate)
    return;

  const startDate = new Date(formData.startDate);
  const endDate = new Date(startDate);
  endDate.setDate(endDate.getDate() + days - 1);

  const endDateStr = endDate.toISOString().split('T')[0];
  if (endDateStr <= maxDate.value) {
    formData.endDate = endDateStr;
    validateDates();
  }
}

function onStartDateChange() {
  // 如果结束日期早于开始日期，自动调整
  if (
    formData.endDate
    && formData.startDate > formData.endDate
  ) {
    setDurationPreset(5); // 默认设置为5天
  }
  validateDates();
}

function updateSymptom(type: SymptomsType, intensity: Intensity) {
  if (symptoms.value[type] === intensity) {
    symptoms.value[type] = null; // 取消选择
  } else {
    symptoms.value[type] = intensity;
  }
}

async function validateDates() {
  await nextTick();
  clearValidationErrors();

  const validation = PeriodValidator.validatePeriodRecord(formData);
  if (!validation.valid) {
    // 设置验证错误（这里简化处理）
    console.warn('Validation errors:', validation.errors);
  }
}

function checkOverlap(): boolean {
  const existingRecords = periodStore.periodRecords.filter(
    record => record.serialNum !== props.record?.serialNum,
  );

  const overlap = PeriodValidator.hasOverlap(formData, existingRecords);
  if (overlap) {
    overlapRecord.value = PeriodCalculator.getPeriodForDate(
      formData.startDate,
      existingRecords,
    );
    return true;
  }

  return false;
}

async function handleSubmit() {
  clearValidationErrors();

  if (!validatePeriodRecord(formData)) {
    return;
  }

  // 检查日期重叠
  if (checkOverlap()) {
    showOverlapWarning.value = true;
    return;
  }

  await submitForm();
}

async function handleOverlapConfirm() {
  showOverlapWarning.value = false;
  await submitForm();
}

async function submitForm() {
  loading.value = true;

  try {
    const period_record: PeriodRecordCreate = {
      notes: formData.notes,
      startDate: formData.startDate,
      endDate: formData.endDate,
    };
    period_record.startDate = DateUtils.toBackendDateTimeFromDateOnly(period_record.startDate);
    period_record.endDate = DateUtils.toBackendDateTimeFromDateOnly(period_record.endDate);
    if (isEditing.value && props.record) {
      const updatedRecord = deepDiff(props.record, period_record);
      emit('update', props.record.serialNum, updatedRecord as PeriodRecordUpdate);
    } else {
      emit('create', period_record);
    }
    emit('cancel');
  } catch (error) {
    console.error('Failed to save period record:', error);
  } finally {
    loading.value = false;
  }
}

async function handleDelete() {
  if (!props.record)
    return;

  loading.value = true;

  try {
    emit('delete', props.record.serialNum);
    emit('cancel');
  } catch (error) {
    console.error('Failed to delete period record:', error);
  } finally {
    loading.value = false;
    showDeleteConfirm.value = false;
  }
}

function handleCancel() {
  if (hasUnsavedChanges()) {
    emit('cancel');
  } else {
    emit('cancel');
  }
}

function hasUnsavedChanges(): boolean {
  if (!props.record) {
    return !!(
      formData.startDate
      || formData.endDate
      || formData.notes
    );
  }

  return (
    formData.startDate !== props.record.startDate
    || formData.endDate !== props.record.endDate
    || formData.notes !== (props.record.notes || '')
  );
}

function resetForm() {
  Object.assign(formData, getPeriodRecordDefault());
  symptoms.value = {
    Pain: null,
    Fatigue: null,
    MoodSwing: null,
  };
  clearValidationErrors();
}

function initializeForm() {
  if (props.record) {
    Object.assign(formData, {
      ...props.record,
      startDate: props.record.startDate.split('T')[0],
      endDate: props.record.endDate.split('T')[0],
    });
  } else {
    resetForm();
  }
}

function getPeriodRecordDefault() {
  return {
    serialNum: '',
    startDate: '',
    endDate: '',
    notes: '',
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: null,
  };
}

// Watchers
watch(() => props.record, initializeForm, { immediate: true });

watch(
  () => formData.startDate,
  d => {
    formData.endDate = DateUtils.addDays(d, periodStore.settings.averagePeriodLength - 1);
  },
);

watch(
  isEditing,
  editing => {
    if (!editing && !props.record) {
      formData.startDate = DateUtils.getTodayDate();
      formData.endDate = DateUtils.addDays(formData.startDate, periodStore.settings.averagePeriodLength - 1);
    }
  },
  { immediate: true },
);

// Lifecycle
onMounted(() => {
  initializeForm();

  if (props.autoFocus) {
    nextTick(() => {
      const firstInput = document.querySelector(
        '.period-form input[type="date"]',
      ) as HTMLInputElement;
      firstInput?.focus();
    });
  }
});

// Expose methods for parent component
defineExpose({
  resetForm,
  validateForm: () => validatePeriodRecord(formData),
  hasUnsavedChanges,
});
</script>

<template>
  <div class="period-record-form card-base">
    <!-- 表单头部 -->
    <div class="form-header">
      <div class="header-content">
        <div class="title-section">
          <h2 class="form-title">
            <i class="i-tabler-calendar-heart text-red-500 mr-2 wh-5" />
            {{ isEditing ? '编辑经期记录' : '添加经期记录' }}
          </h2>
          <p class="form-subtitle">
            {{ isEditing ? '修改已有的经期信息' : '记录新的经期开始和结束时间' }}
          </p>
        </div>
        <button class="close-btn" type="button" :disabled="loading" @click="handleCancel">
          <i class="i-tabler-x wh-5" />
        </button>
      </div>
    </div>

    <!-- 表单主体 -->
    <div class="form-body">
      <form class="period-form" @submit.prevent="handleSubmit">
        <!-- 日期设置区域 -->
        <div class="section-card">
          <div class="section-header">
            <i class="i-tabler-calendar text-blue-500 wh-4" />
            <h3 class="section-title">
              日期设置
            </h3>
          </div>

          <div class="date-inputs">
            <!-- 开始日期 -->
            <div class="input-group">
              <label class="required input-label">
                开始日期
              </label>
              <div class="input-wrapper">
                <input
                  v-model="formData.startDate" type="date" class="date-input"
                  :class="{ 'input-error': hasFieldError('startDate') }" :max="maxDate" required
                  @change="onStartDateChange"
                >
                <div class="input-icon">
                  <i class="i-tabler-calendar-event text-gray-400 wh-4" />
                </div>
              </div>
              <InputError :errors="getFieldErrors('startDate')" />
            </div>

            <!-- 结束日期 -->
            <div class="input-group">
              <label class="input-label required">
                结束日期
              </label>
              <div class="input-wrapper">
                <input
                  v-model="formData.endDate" type="date" class="date-input"
                  :class="{ 'input-error': hasFieldError('endDate') }" :min="formData.startDate" required
                  @change="validateDates"
                >
                <div class="input-icon">
                  <i class="i-tabler-calendar-check text-gray-400 wh-4" />
                </div>
              </div>
              <InputError :errors="getFieldErrors('endDate')" />
            </div>
          </div>

          <!-- 快速设置按钮 -->
          <div class="quick-actions">
            <span class="quick-label">快速设置:</span>
            <div class="quick-buttons">
              <button
                v-for="preset in durationPresets" :key="preset.days" type="button"
                class="preset-btn" :class="{ 'preset-active': periodDuration === preset.days }"
                :disabled="!formData.startDate" @click="setDurationPreset(preset.days)"
              >
                {{ preset.label }}
              </button>
            </div>
          </div>
        </div>

        <!-- 经期信息显示 -->
        <div v-if="showPeriodInfo" class="info-card">
          <div class="info-header">
            <LucideInfo class="mr-2 wh-5" />
            <span class="info-title">经期信息</span>
          </div>
          <div class="info-grid">
            <div class="info-item">
              <span class="info-label">持续时间</span>
              <span class="info-value duration">{{ periodDuration }} 天</span>
            </div>
            <div class="info-item">
              <span class="info-label">距离上次</span>
              <span class="info-value cycle" :class="cycleColorClass">
                {{ cycleText }}
              </span>
            </div>
            <div v-if="predictedNext" class="info-item">
              <span class="info-label">预测下次</span>
              <span class="info-value">{{ predictedNext }}</span>
            </div>
          </div>
        </div>

        <!-- 症状记录区域 -->
        <div class="section-card">
          <div class="section-header">
            <i class="i-tabler-medical-cross text-green-500 wh-4" />
            <h3 class="section-title">
              症状记录
            </h3>
            <span class="section-subtitle">选择本次经期的症状程度</span>
          </div>

          <div class="symptoms-grid">
            <div v-for="symptomGroup in symptomGroups" :key="symptomGroup.type" class="symptom-card">
              <div class="symptom-header">
                <i :class="[symptomGroup.icon, symptomGroup.color]" class="wh-4" />
                <span class="symptom-label">{{ symptomGroup.label }}</span>
              </div>
              <div class="intensity-selector">
                <button
                  v-for="intensity in intensityLevels" :key="intensity.value" type="button"
                  class="intensity-btn" :class="{
                    'intensity-active': symptoms[symptomGroup.type] === intensity.value,
                    [`intensity-${intensity.value.toLowerCase()}`]: symptoms[symptomGroup.type] === intensity.value,
                  }" @click="updateSymptom(symptomGroup.type, intensity.value)"
                >
                  <span class="intensity-dot" />
                  <span class="intensity-text">{{ intensity.label }}</span>
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 备注区域 -->
        <div class="section-card">
          <div class="input-group">
            <textarea
              v-model="formData.notes" class="notes-textarea" placeholder="记录本次经期的特殊情况、身体感受或其他想要记录的内容..."
              maxlength="500" rows="4"
            />
            <div class="textarea-footer">
              <span class="char-count">{{ notesLength }}/500</span>
            </div>
          </div>
        </div>

        <!-- 表单操作按钮 -->
        <div class="form-actions">
          <div class="actions-left">
            <button
              v-if="isEditing" type="button" class="btn-danger" :disabled="loading"
              @click="showDeleteConfirm = true"
            >
              <LucideTrash class="wh-5" />
            </button>
          </div>
          <div class="actions-right">
            <button type="button" class="btn-secondary" :disabled="loading" @click="handleCancel">
              <LucideX class="wh-5" />
            </button>
            <button type="submit" class="btn-primary" :disabled="!canSubmit || loading">
              <i v-if="loading" class="i-tabler-loader-2 mr-2 wh-4 animate-spin" />
              <LucideCheck class="wh-5" />
            </button>
          </div>
        </div>
      </form>
    </div>

    <!-- 删除确认弹窗 -->
    <ConfirmDialog
      v-model:show="showDeleteConfirm" title="删除经期记录" type="danger" :loading="loading"
      @confirm="handleDelete"
    >
      <p class="confirmation-text">
        确定要删除这条经期记录吗？
      </p>
      <div class="deletion-info">
        <div class="info-row">
          <span class="info-key">记录时间:</span>
          <span class="info-val">{{ deletionInfo.dateRange }}</span>
        </div>
        <div class="info-row">
          <span class="info-key">持续时间:</span>
          <span class="info-val">{{ deletionInfo.duration }}</span>
        </div>
      </div>
      <div class="warning-note">
        <LucideTriangle class="wh-5" />
        <span>此操作无法撤销，请谨慎操作</span>
      </div>
    </ConfirmDialog>

    <!-- 重叠警告弹窗 -->
    <WarningDialog
      v-model:show="showOverlapWarning" title="日期重叠提醒" @confirm="handleOverlapConfirm"
      @cancel="showOverlapWarning = false"
    >
      <p class="warning-text">
        检测到您选择的日期与已有记录存在重叠：
      </p>
      <div class="overlap-details">
        <div class="overlap-record">
          <i class="i-tabler-calendar text-red-500 wh-4" />
          <span>{{ overlapInfo.dateRange }}</span>
        </div>
      </div>
      <p class="warning-question">
        是否继续保存？这可能会影响数据的准确性。
      </p>
    </WarningDialog>
  </div>
</template>

<style scoped lang="postcss">
.period-record-form {
  max-height: 80vh; /* 根据需要调整高度 */
  overflow-y: scroll;
  -ms-overflow-style: none; /* IE 10+ */
  scrollbar-width: none; /* Firefox */
}

.period-record-form::-webkit-scrollbar {
  display: none; /* Chrome, Safari, Edge */
}

/* 表单头部 */
.form-header {
  @apply bg-gradient-to-r from-red-50 to-pink-50 dark:from-red-900/20 dark:to-pink-900/20 border-b border-gray-200 dark:border-gray-700 px-6 py-4;
}

.header-content {
  @apply flex items-start justify-between;
}

.title-section {
  @apply flex-1;
}

.form-title {
  @apply text-xl font-bold text-gray-900 dark:text-white flex items-center mb-1;
}

.form-subtitle {
  @apply text-sm text-gray-600 dark:text-gray-400;
}

.close-btn {
  @apply p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300 transition-colors disabled:opacity-50;
}

/* 表单主体 */
.form-body {
  @apply p-6;
}

.period-form {
  @apply space-y-6;
}

/* 区域卡片 */
.section-card {
  @apply bg-gray-50 dark:bg-gray-900/50 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
}

.section-header {
  @apply flex items-center gap-2 mb-4;
}

.section-title {
  @apply text-lg font-semibold text-gray-900 dark:text-white;
}

.section-subtitle {
  @apply text-sm text-gray-500 dark:text-gray-400 ml-auto;
}

/* 日期输入 */
.date-inputs {
  @apply grid grid-cols-1 sm:grid-cols-2 gap-4 mb-4;
}

.input-group {
  @apply space-y-2;
}

.input-label {
  @apply block text-sm font-medium text-gray-700 dark:text-gray-300;
}

.input-label.required::after {
  @apply content-['*'] text-red-500 ml-1;
}

.input-wrapper {
  @apply relative;
}

.date-input {
  @apply w-full pl-4 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors text-sm;
}

.date-input.input-error {
  @apply border-red-500 focus:ring-red-500 focus:border-red-500;
}

.input-icon {
  @apply absolute left-3 top-1/2 transform -translate-y-1/2 pointer-events-none;
}

/* 快速操作 */
.quick-actions {
  @apply flex flex-wrap items-center gap-3;
}

.quick-label {
  @apply text-sm text-gray-600 dark:text-gray-400 font-medium;
}

.quick-buttons {
  @apply flex flex-wrap gap-2;
}

.preset-btn {
  @apply px-3 py-1.5 text-sm border border-gray-300 dark:border-gray-600 rounded-lg hover:border-blue-500 hover:text-blue-600 disabled:opacity-50 disabled:cursor-not-allowed transition-colors;
}

.preset-btn.preset-active {
  @apply border-blue-500 bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400;
}

/* 信息卡片 */
.info-card {
  @apply bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4;
}

.info-header {
  @apply flex items-center gap-2 mb-3;
}

.info-title {
  @apply text-sm font-medium text-blue-900 dark:text-blue-300;
}

.info-grid {
  @apply grid grid-cols-1 gap-3;
}

.info-item {
  @apply flex justify-between items-center;
}

.info-label {
  @apply text-sm text-blue-700 dark:text-blue-400;
}

.info-value {
  @apply text-sm font-semibold;
}

.info-value.duration {
  @apply text-red-600 dark:text-red-400;
}

.info-value.cycle {
  @apply font-bold;
}

/* 症状选择 */
.symptoms-grid {
  @apply grid grid-cols-1 gap-4;
}

.symptom-card {
  @apply bg-white dark:bg-gray-800 rounded-lg p-4 border border-gray-200 dark:border-gray-700;
}

.symptom-header {
  @apply flex items-center gap-2 mb-3;
}

.symptom-label {
  @apply text-sm font-medium text-gray-900 dark:text-white;
}

.intensity-selector {
  @apply flex gap-2;
}

.intensity-btn {
  @apply flex-1 flex items-center justify-center gap-2 py-2 px-3 border border-gray-300 dark:border-gray-600 rounded-lg hover:border-gray-400 dark:hover:border-gray-500 transition-all text-sm;
}

.intensity-btn.intensity-active {
  @apply border-transparent;
}

.intensity-btn.intensity-active.intensity-light {
  @apply bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400 border-yellow-500;
}

.intensity-btn.intensity-active.intensity-medium {
  @apply bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400 border-orange-500;
}

.intensity-btn.intensity-active.intensity-heavy {
  @apply bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 border-red-500;
}

.intensity-dot {
  @apply w-2 h-2 rounded-full bg-current opacity-70;
}

.intensity-text {
  @apply font-medium;
}

/* 备注区域 */
.notes-textarea {
  @apply w-full p-3 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors resize-none text-sm;
}

.textarea-footer {
  @apply flex justify-end mt-1;
}

.char-count {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

/* 表单操作 */
.form-actions {
  @apply flex items-center justify-between pt-6 border-t border-gray-200 dark:border-gray-700;
}

.actions-left,
.actions-right {
  @apply flex gap-3;
}

.btn-primary {
  @apply px-6 py-2.5 bg-blue-600 text-white rounded-lg font-medium hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center;
}

.btn-secondary {
  @apply px-6 py-2.5 bg-gray-200 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg font-medium hover:bg-gray-300 dark:hover:bg-gray-600 focus:ring-2 focus:ring-gray-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all;
}

.btn-danger {
  @apply px-4 py-2 bg-red-600 text-white rounded-lg font-medium hover:bg-red-700 focus:ring-2 focus:ring-red-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all flex items-center;
}

/* 弹窗样式 */
.confirmation-text {
  @apply text-gray-700 dark:text-gray-300 mb-4;
}

.deletion-info {
  @apply bg-gray-50 dark:bg-gray-900 rounded-lg p-3 mb-4 space-y-2;
}

.info-row {
  @apply flex justify-between items-center;
}

.info-key {
  @apply text-sm text-gray-600 dark:text-gray-400;
}

.info-val {
  @apply text-sm font-medium text-gray-900 dark:text-white;
}

.warning-note {
  @apply flex items-center gap-2 text-sm text-orange-700 dark:text-orange-400 bg-orange-50 dark:bg-orange-900/20 rounded-lg p-3;
}

.warning-text {
  @apply text-gray-700 dark:text-gray-300 mb-3;
}

.overlap-details {
  @apply bg-yellow-50 dark:bg-yellow-900/20 rounded-lg p-3 mb-4;
}

.overlap-record {
  @apply flex items-center gap-2 text-sm font-medium text-yellow-800 dark:text-yellow-300;
}

.warning-question {
  @apply text-gray-700 dark:text-gray-300 font-medium;
}

/* 响应式设计 */
@media (max-width: 640px) {
  .form-header {
    @apply px-4 py-3;
  }

  .form-body {
    @apply p-4;
  }

  .date-inputs {
    @apply grid-cols-1;
  }

  .info-grid {
    @apply grid-cols-1;
  }

  .quick-actions {
    @apply flex-col items-start gap-2;
  }

  .quick-buttons {
    @apply w-full;
  }

  .preset-btn {
    @apply flex-1 min-w-0;
  }

  .symptoms-grid {
    @apply space-y-3;
  }

  .intensity-selector {
    @apply flex-col gap-1;
  }

  .intensity-btn {
    @apply justify-start;
  }

  .form-actions {
    @apply flex-col gap-3;
  }

  .actions-left,
  .actions-right {
    @apply w-full justify-center;
  }
}

/* 动画效果 */
.section-card {
  animation: slideInUp 0.3s ease-out;
}

.info-card {
  animation: fadeInScale 0.4s ease-out;
}

@keyframes slideInUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

@keyframes fadeInScale {
  from {
    opacity: 0;
    transform: scale(0.95);
  }

  to {
    opacity: 1;
    transform: scale(1);
  }
}

/* 焦点状态增强 */
.date-input:focus {
  @apply shadow-lg;
}

.notes-textarea:focus {
  @apply shadow-lg;
}

/* 禁用状态 */
.preset-btn:disabled {
  @apply bg-gray-100 dark:bg-gray-800 text-gray-400 dark:text-gray-600 border-gray-200 dark:border-gray-700;
}

/* 加载状态 */
.btn-primary:disabled,
.btn-danger:disabled {
  @apply relative overflow-hidden;
}

.btn-primary:disabled::after,
.btn-danger:disabled::after {
  @apply content-[''] absolute inset-0 bg-white/10 animate-pulse;
}

/* 错误状态增强 */
.input-error {
  animation: shake 0.5s ease-in-out;
}

@keyframes shake {

  0%,
  100% {
    transform: translateX(0);
  }

  25% {
    transform: translateX(-5px);
  }

  75% {
    transform: translateX(5px);
  }
}

/* 成功状态 */
.success-indicator {
  @apply text-green-600 dark:text-green-400;
  animation: bounce 0.5s ease-in-out;
}

@keyframes bounce {

  0%,
  100% {
    transform: scale(1);
  }

  50% {
    transform: scale(1.1);
  }
}

/* 深色模式优化 */
@media (prefers-color-scheme: dark) {
  .section-card {
    @apply shadow-lg;
  }

  .info-card {
    @apply shadow-md;
  }

  .symptom-card {
    @apply shadow-sm;
  }
}

/* 无障碍访问增强 */
.input-label[aria-required="true"]::after {
  @apply content-['*'] text-red-500 ml-1;
}

.btn-primary:focus-visible,
.btn-secondary:focus-visible,
.btn-danger:focus-visible {
  @apply outline outline-2 outline-offset-2 outline-blue-500;
}

.date-input:focus-visible,
.notes-textarea:focus-visible {
  @apply outline outline-2 outline-offset-2 outline-blue-500;
}

/* 高对比度模式支持 */
@media (prefers-contrast: high) {
  .section-card {
    @apply border-2;
  }

  .info-card {
    @apply border-2 border-blue-500;
  }

  .btn-primary {
    @apply bg-blue-700 border-2 border-blue-800;
  }

  .btn-danger {
    @apply bg-red-700 border-2 border-red-800;
  }
}

/* 减少动画模式 */
@media (prefers-reduced-motion: reduce) {

  .section-card,
  .info-card {
    animation: none;
  }

  .input-error {
    animation: none;
  }

  .success-indicator {
    animation: none;
  }
}
</style>
