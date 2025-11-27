<script setup lang="ts">
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
import PresetButtons from '@/components/common/PresetButtons.vue';
import { Modal } from '@/components/ui';
import FormRow from '@/components/ui/FormRow.vue';
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

// 持续时间预设值（用于PresetButtons组件）
const durationPresetValues = computed(() => durationPresets.map(p => p.days));

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
      if (Object.keys(updatedRecord).length > 0) {
        emit('update', props.record.serialNum, updatedRecord as PeriodRecordUpdate);
      } else {
        // 如果没有更改，直接关闭表单
        emit('cancel');
      }
    } else {
      emit('create', period_record);
    }
    // 移除了 emit('cancel')，让父组件在操作完成后再关闭
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
    // 移除了 emit('cancel')，让父组件在操作完成后再关闭
  } catch (error) {
    console.error('Failed to delete period record:', error);
  } finally {
    loading.value = false;
    showDeleteConfirm.value = false;
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
  <Modal
    :open="true"
    :title="isEditing ? '编辑经期记录' : '添加经期记录'"
    size="md"
    :confirm-text="isEditing ? '更新' : '创建'"
    :confirm-loading="loading"
    :confirm-disabled="!canSubmit"
    :show-delete="!!isEditing"
    @confirm="handleSubmit"
    @delete="showDeleteConfirm = true"
    @close="$emit('cancel')"
  >
    <!-- 日期设置区域 -->
    <div class="section-card">
      <div class="section-header">
        <LucideCalendar class="wh-5" />
        <h3 class="section-title">
          日期设置
        </h3>
      </div>

      <!-- 开始日期 -->
      <FormRow label="开始日期" required :error="getFieldErrors('startDate')[0]">
        <input
          v-model="formData.startDate"
          type="date"
          class="modal-input-select w-full"
          :max="maxDate"
          required
          @change="onStartDateChange"
        >
      </FormRow>

      <!-- 结束日期 -->
      <FormRow label="结束日期" required :error="getFieldErrors('endDate')[0]">
        <input
          v-model="formData.endDate"
          type="date"
          class="modal-input-select w-full"
          :min="formData.startDate"
          required
          @change="validateDates"
        >
      </FormRow>

      <!-- 快速设置持续时间 -->
      <FormRow label="快速设置">
        <PresetButtons
          :model-value="periodDuration"
          :presets="durationPresetValues"
          suffix="天"
          :disabled="!formData.startDate"
          @update:model-value="setDurationPreset"
        />
      </FormRow>
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
    <div class="section-card section-card-success">
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
    <FormRow label="" full-width>
      <textarea
        v-model="formData.notes"
        class="modal-input-select w-full"
        placeholder="记录本次经期的特殊情况、身体感受或其他想要记录的内容..."
        maxlength="500"
        rows="4"
      />
      <div class="character-count">
        {{ notesLength }}/500
      </div>
    </FormRow>
  </Modal>

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
  <ConfirmDialog
    v-model:show="showOverlapWarning"
    title="日期重叠提醒"
    type="warning"
    confirm-text="继续保存"
    cancel-text="取消"
    @confirm="handleOverlapConfirm"
    @cancel="showOverlapWarning = false"
  >
    <div class="space-y-3">
      <p class="text-sm text-gray-700 dark:text-gray-300">
        检测到您选择的日期与已有记录存在重叠：
      </p>
      <div class="bg-yellow-50 dark:bg-yellow-900/20 p-3 rounded-lg">
        <div class="flex items-center gap-2 text-sm text-yellow-800 dark:text-yellow-300">
          <i class="i-tabler-calendar wh-4" />
          <span>{{ overlapInfo.dateRange }}</span>
        </div>
      </div>
      <p class="text-sm font-medium text-gray-900 dark:text-white">
        是否继续保存？这可能会影响数据的准确性。
      </p>
    </div>
  </ConfirmDialog>
</template>

<style scoped lang="postcss">
/* 自定义样式 - 大部分样式已由Modal和FormRow提供 */

/* 区域卡片 */
.section-card {
  background-color: var(--color-base-100);
  border-radius: 0.5rem;
  padding: 1rem;
  border: 1px solid var(--color-base-300);
  border-left-width: 4px;
  border-left-color: var(--color-primary);
}

.dark .section-card {
  background-color: var(--color-base-200);
  border-color: var(--color-base-300);
  border-left-color: var(--color-primary);
}

.section-card-success {
  border-left-color: var(--color-success);
}

.dark .section-card-success {
  border-left-color: var(--color-success);
}

.section-card-success .section-title {
  color: var(--color-success);
}

.dark .section-card-success .section-title {
  color: var(--color-success);
}

.section-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-primary);
}

.dark .section-title {
  color: var(--color-primary);
}

.section-subtitle {
  font-size: 0.875rem;
  color: var(--color-neutral);
  margin-left: auto;
}

.dark .section-subtitle {
  color: var(--color-neutral);
}

/* 信息卡片 */
.info-card {
  background-color: var(--color-base-100);
  border: 1px solid var(--color-info);
  border-radius: 0.5rem;
  padding: 1rem;
  border-left-width: 4px;
  margin-top: 1.5rem;
  margin-bottom: 1.5rem;
}

.dark .info-card {
  background-color: var(--color-base-200);
  border-color: var(--color-info);
}

.info-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.info-title {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-info);
}

.dark .info-title {
  color: var(--color-info);
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
  color: var(--color-base-content);
  opacity: 0.8;
}

.dark .info-label {
  color: var(--color-base-content);
  opacity: 0.7;
}

.info-value {
  font-size: 0.875rem;
  font-weight: 600;
}

.info-value.duration {
  color: var(--color-error);
}

.dark .info-value.duration {
  color: var(--color-error);
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
  background-color: var(--color-base-100);
  border-radius: 0.5rem;
  padding: 1rem;
  border: 1px solid var(--color-base-300);
}

.dark .symptom-card {
  background-color: var(--color-base-200);
  border-color: var(--color-base-300);
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
  color: var(--color-base-content);
}

.dark .symptom-label {
  color: var(--color-base-content);
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
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  font-size: 0.875rem;
  transition: all 0.2s ease-in-out;
}

.intensity-btn:hover {
  border-color: var(--color-neutral);
}

.dark .intensity-btn {
  border-color: var(--color-base-300);
}

.dark .intensity-btn:hover {
  border-color: var(--color-neutral);
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

/* 字符计数 */
.character-count {
  font-size: 0.75rem;
  color: var(--color-neutral);
  text-align: right;
  margin-top: 0.25rem;
}

.dark .character-count {
  color: var(--color-base-content);
}

/* 弹窗样式 */
.confirmation-text {
  color: var(--color-base-content);
  margin-bottom: 1rem;
}

.dark .confirmation-text {
  color: var(--color-base-content);
}

.deletion-info {
  background-color: var(--color-base-100);
  border-radius: 0.5rem;
  padding: 0.75rem;
  margin-bottom: 1rem;
  border: 1px solid var(--color-base-300);
}

.dark .deletion-info {
  background-color: var(--color-base-200);
}

.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--color-base-200);
}

.info-row:last-child {
  border-bottom: none;
}

.dark .info-row {
  border-color: var(--color-base-300);
}

.info-key {
  font-size: 0.875rem;
  color: var(--color-neutral);
  font-weight: 500;
}

.dark .info-key {
  color: var(--color-neutral);
}

.info-val {
  font-size: 0.875rem;
  color: var(--color-base-content);
  font-weight: 600;
}

.dark .info-val {
  color: var(--color-base-content);
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
