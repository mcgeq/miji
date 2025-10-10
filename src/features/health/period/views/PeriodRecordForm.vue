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

  if (new Date(endDate) > new Date(maxDate.value)) {
    formData.endDate = endDate.toISOString().split('T')[0];
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
    startDate: DateUtils.getTodayDate(),
    endDate: DateUtils.addDays(null, periodStore.settings.averagePeriodLength - 1),
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
            <LucideCalendar class="wh-5" />
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
                v-for="preset in durationPresets"
                :key="preset.days"
                type="button"
                class="preset-btn"
                :class="{ 'preset-active': periodDuration === preset.days }"
                :disabled="!formData.startDate"
                @click="setDurationPreset(preset.days)"
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
  background: linear-gradient(to right, #fef2f2, #fce7f3);
  border-bottom: 1px solid #e5e7eb;
  padding: 1rem 1.5rem;
}

.dark .form-header {
  background: linear-gradient(to right, rgba(127, 29, 29, 0.2), rgba(157, 23, 77, 0.2));
  border-color: #374151;
}

.header-content {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.title-section {
  flex: 1;
}

.form-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: #111827;
  display: flex;
  align-items: center;
  margin-bottom: 0.25rem;
}

.dark .form-title {
  color: white;
}

.form-subtitle {
  font-size: 0.875rem;
  color: #4b5563;
}

.dark .form-subtitle {
  color: #9ca3af;
}

.close-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  color: #6b7280;
  transition: all 0.2s ease-in-out;
}

.close-btn:hover {
  background-color: #f3f4f6;
  color: #374151;
}

.close-btn:disabled {
  opacity: 0.5;
}

.dark .close-btn {
  color: #9ca3af;
}

.dark .close-btn:hover {
  background-color: #374151;
  color: #d1d5db;
}

/* 表单主体 */
.form-body {
  padding: 1.5rem;
}

.period-form {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 区域卡片 */
.section-card {
  background-color: #f9fafb;
  border-radius: 0.5rem;
  padding: 1rem;
  border: 1px solid #e5e7eb;
}

.dark .section-card {
  background-color: rgba(17, 24, 39, 0.5);
  border-color: #374151;
}

.section-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.section-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #111827;
}

.dark .section-title {
  color: white;
}

.section-subtitle {
  font-size: 0.875rem;
  color: #6b7280;
  margin-left: auto;
}

.dark .section-subtitle {
  color: #9ca3af;
}

/* 日期输入 */
.date-inputs {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
  margin-bottom: 1rem;
}

@media (min-width: 640px) {
  .date-inputs {
    grid-template-columns: repeat(2, 1fr);
  }
}

.input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.input-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
}

.dark .input-label {
  color: #d1d5db;
}

.input-label.required::after {
  content: '*';
  color: #ef4444;
  margin-left: 0.25rem;
}

.input-wrapper {
  position: relative;
}

.date-input {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  background-color: white;
  color: #111827;
  font-size: 0.875rem;
  transition: all 0.2s ease-in-out;
}

.date-input:focus {
  outline: none;
  ring: 2px;
  ring-color: #3b82f6;
  border-color: #3b82f6;
}

.dark .date-input {
  border-color: #4b5563;
  background-color: #1f2937;
  color: white;
}

.date-input.input-error {
  border-color: #ef4444;
}

.date-input.input-error:focus {
  ring-color: #ef4444;
  border-color: #ef4444;
}

.input-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  pointer-events: none;
}

/* 快速操作 */
.quick-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.75rem;
}

.quick-label {
  font-size: 0.875rem;
  color: #4b5563;
  font-weight: 500;
}

.dark .quick-label {
  color: #9ca3af;
}

.quick-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.preset-btn {
  padding: 0.375rem 0.75rem;
  font-size: 0.875rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
}

.preset-btn:hover {
  border-color: #3b82f6;
  color: #2563eb;
}

.preset-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.dark .preset-btn {
  border-color: #4b5563;
}

.preset-btn.preset-active {
  border-color: #3b82f6;
  background-color: #eff6ff;
  color: #2563eb;
}

.dark .preset-btn.preset-active {
  background-color: rgba(59, 130, 246, 0.3);
  color: #60a5fa;
}

/* 信息卡片 */
.info-card {
  background-color: #eff6ff;
  border: 1px solid #bfdbfe;
  border-radius: 0.5rem;
  padding: 1rem;
}

.dark .info-card {
  background-color: rgba(30, 58, 138, 0.2);
  border-color: #1e40af;
}

.info-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.info-title {
  font-size: 0.875rem;
  font-weight: 500;
  color: #1e3a8a;
}

.dark .info-title {
  color: #93c5fd;
}

.info-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.75rem;
}

.info-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.info-label {
  font-size: 0.875rem;
  color: #1d4ed8;
}

.dark .info-label {
  color: #60a5fa;
}

.info-value {
  font-size: 0.875rem;
  font-weight: 600;
}

.info-value.duration {
  color: #dc2626;
}

.dark .info-value.duration {
  color: #f87171;
}

.info-value.cycle {
  font-weight: 700;
}

/* 症状选择 */
.symptoms-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}

.symptom-card {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1rem;
  border: 1px solid #e5e7eb;
}

.dark .symptom-card {
  background-color: #1f2937;
  border-color: #374151;
}

.symptom-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.symptom-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #111827;
}

.dark .symptom-label {
  color: white;
}

.intensity-selector {
  display: flex;
  gap: 0.5rem;
}

.intensity-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  transition: all 0.2s ease-in-out;
}

.intensity-btn:hover {
  border-color: #9ca3af;
}

.dark .intensity-btn {
  border-color: #4b5563;
}

.dark .intensity-btn:hover {
  border-color: #6b7280;
}

.intensity-btn.intensity-active {
  border-color: transparent;
}

.intensity-btn.intensity-active.intensity-light {
  background-color: #fef3c7;
  color: #92400e;
  border-color: #f59e0b;
}

.dark .intensity-btn.intensity-active.intensity-light {
  background-color: rgba(146, 64, 14, 0.3);
  color: #fbbf24;
}

.intensity-btn.intensity-active.intensity-medium {
  background-color: #fed7aa;
  color: #c2410c;
  border-color: #f97316;
}

.dark .intensity-btn.intensity-active.intensity-medium {
  background-color: rgba(194, 65, 12, 0.3);
  color: #fb923c;
}

.intensity-btn.intensity-active.intensity-heavy {
  background-color: #fecaca;
  color: #dc2626;
  border-color: #ef4444;
}

.dark .intensity-btn.intensity-active.intensity-heavy {
  background-color: rgba(220, 38, 38, 0.3);
  color: #f87171;
}

.intensity-dot {
  width: 0.5rem;
  height: 0.5rem;
  border-radius: 50%;
  background-color: currentColor;
  opacity: 0.7;
}

.intensity-text {
  font-weight: 500;
}

/* 备注区域 */
.notes-textarea {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  background-color: white;
  color: #111827;
  font-size: 0.875rem;
  resize: none;
  transition: all 0.2s ease-in-out;
}

.notes-textarea:focus {
  outline: none;
  ring: 2px;
  ring-color: #3b82f6;
  border-color: #3b82f6;
}

.dark .notes-textarea {
  border-color: #4b5563;
  background-color: #1f2937;
  color: white;
}

.textarea-footer {
  display: flex;
  justify-content: flex-end;
  margin-top: 0.25rem;
}

.char-count {
  font-size: 0.75rem;
  color: #6b7280;
}

.dark .char-count {
  color: #9ca3af;
}

/* 表单操作 */
.form-actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-top: 1.5rem;
  border-top: 1px solid #e5e7eb;
}

.dark .form-actions {
  border-color: #374151;
}

.actions-left,
.actions-right {
  display: flex;
  gap: 0.75rem;
}

.btn-primary {
  padding: 0.625rem 1.5rem;
  background-color: #2563eb;
  color: white;
  border-radius: 0.5rem;
  font-weight: 500;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.btn-primary:hover {
  background-color: #1d4ed8;
}

.btn-primary:focus {
  outline: none;
  ring: 2px;
  ring-color: #3b82f6;
  ring-offset: 2px;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  padding: 0.625rem 1.5rem;
  background-color: #e5e7eb;
  color: #374151;
  border-radius: 0.5rem;
  font-weight: 500;
  transition: all 0.2s ease-in-out;
}

.btn-secondary:hover {
  background-color: #d1d5db;
}

.btn-secondary:focus {
  outline: none;
  ring: 2px;
  ring-color: #6b7280;
  ring-offset: 2px;
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

.btn-danger {
  padding: 0.5rem 1rem;
  background-color: #dc2626;
  color: white;
  border-radius: 0.5rem;
  font-weight: 500;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.btn-danger:hover {
  background-color: #b91c1c;
}

.btn-danger:focus {
  outline: none;
  ring: 2px;
  ring-color: #ef4444;
  ring-offset: 2px;
}

.btn-danger:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 弹窗样式 */
.confirmation-text {
  color: #374151;
  margin-bottom: 1rem;
}

.dark .confirmation-text {
  color: #d1d5db;
}

.deletion-info {
  background-color: #f9fafb;
  border-radius: 0.5rem;
  padding: 0.75rem;
  margin-bottom: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.dark .deletion-info {
  background-color: #111827;
}

.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.info-key {
  font-size: 0.875rem;
  color: #4b5563;
}

.dark .info-key {
  color: #9ca3af;
}

.info-val {
  font-size: 0.875rem;
  font-weight: 500;
  color: #111827;
}

.dark .info-val {
  color: white;
}

.warning-note {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #c2410c;
  background-color: #fef3c7;
  border-radius: 0.5rem;
  padding: 0.75rem;
}

.dark .warning-note {
  color: #fb923c;
  background-color: rgba(146, 64, 14, 0.2);
}

.warning-text {
  color: #374151;
  margin-bottom: 0.75rem;
}

.dark .warning-text {
  color: #d1d5db;
}

.overlap-details {
  background-color: #fefce8;
  border-radius: 0.5rem;
  padding: 0.75rem;
  margin-bottom: 1rem;
}

.dark .overlap-details {
  background-color: rgba(146, 64, 14, 0.2);
}

.overlap-record {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: #a16207;
}

.dark .overlap-record {
  color: #fbbf24;
}

.warning-question {
  color: #374151;
  font-weight: 500;
}

.dark .warning-question {
  color: #d1d5db;
}

/* 响应式设计 */
@media (max-width: 640px) {
  .form-header {
    padding: 0.75rem 1rem;
  }

  .form-body {
    padding: 1rem;
  }

  .date-inputs {
    grid-template-columns: 1fr;
  }

  .info-grid {
    grid-template-columns: 1fr;
  }

  .quick-actions {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .quick-buttons {
    width: 100%;
  }

  .preset-btn {
    flex: 1;
    min-width: 0;
  }

  .symptoms-grid {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .intensity-selector {
    flex-direction: column;
    gap: 0.25rem;
  }

  .intensity-btn {
    justify-content: flex-start;
  }

  .form-actions {
    flex-direction: column;
    gap: 0.75rem;
  }

  .actions-left,
  .actions-right {
    width: 100%;
    justify-content: center;
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
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

.notes-textarea:focus {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

/* 禁用状态 */
.preset-btn:disabled {
  background-color: #f3f4f6;
  color: #9ca3af;
  border-color: #e5e7eb;
}

.dark .preset-btn:disabled {
  background-color: #1f2937;
  color: #4b5563;
  border-color: #374151;
}

/* 加载状态 */
.btn-primary:disabled,
.btn-danger:disabled {
  position: relative;
  overflow: hidden;
}

.btn-primary:disabled::after,
.btn-danger:disabled::after {
  content: '';
  position: absolute;
  inset: 0;
  background-color: rgba(255, 255, 255, 0.1);
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
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
  color: #16a34a;
  animation: bounce 0.5s ease-in-out;
}

.dark .success-indicator {
  color: #4ade80;
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
    box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  }

  .info-card {
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  }

  .symptom-card {
    box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  }
}

/* 无障碍访问增强 */
.input-label[aria-required="true"]::after {
  content: '*';
  color: #ef4444;
  margin-left: 0.25rem;
}

.btn-primary:focus-visible,
.btn-secondary:focus-visible,
.btn-danger:focus-visible {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}

.date-input:focus-visible,
.notes-textarea:focus-visible {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
}

/* 高对比度模式支持 */
@media (prefers-contrast: high) {
  .section-card {
    border-width: 2px;
  }

  .info-card {
    border-width: 2px;
    border-color: #3b82f6;
  }

  .btn-primary {
    background-color: #1d4ed8;
    border-width: 2px;
    border-color: #1e40af;
  }

  .btn-danger {
    background-color: #b91c1c;
    border-width: 2px;
    border-color: #991b1b;
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
