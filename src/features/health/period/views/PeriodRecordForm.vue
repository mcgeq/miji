<script setup lang="ts">
  import { AlertTriangle, Calendar, Info, Plus } from 'lucide-vue-next';
  import PresetButtons from '@/components/common/PresetButtons.vue';
  import { Badge, ConfirmDialog, Modal } from '@/components/ui';
  import FormRow from '@/components/ui/FormRow.vue';
  import type { Intensity, SymptomsType } from '@/schema/common';
  import type {
    PeriodRecordCreate,
    PeriodRecords,
    PeriodRecordUpdate,
  } from '@/schema/health/period';
  import { usePeriodStore } from '@/stores/periodStore';
  import { DateUtils } from '@/utils/date';
  import { deepDiff } from '@/utils/diff';
  import PeriodInfoCard from '../components/PeriodInfoCard.vue';
  import { usePeriodValidation } from '../composables/usePeriodValidation';
  import { durationPresets, intensityLevels, symptomGroups } from '../constants/periodConstants';
  import {
    PeriodCalculator,
    PeriodDateUtils,
    PeriodFormatter,
    PeriodValidator,
  } from '../utils/periodUtils';

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
  const { validatePeriodRecord, getFieldErrors, hasErrors, clearValidationErrors } =
    usePeriodValidation();

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
    if (!(formData.startDate && formData.endDate)) return 0;
    return DateUtils.daysBetween(formData.startDate, formData.endDate) + 1;
  });

  const showPeriodInfo = computed(() => {
    return formData.startDate && formData.endDate && periodDuration.value > 0;
  });

  const cycleLength = computed(() => {
    if (!formData.startDate || periodStore.periodRecords.length === 0) return 0;

    const currentStart = new Date(formData.startDate);
    const lastRecord = periodStore.periodRecords
      .filter(record => record.serialNum !== props.record?.serialNum)
      .sort((a, b) => new Date(b.startDate).getTime() - new Date(a.startDate).getTime())[0];

    if (!lastRecord) return 0;

    const lastStart = new Date(lastRecord.startDate);
    return Math.ceil((currentStart.getTime() - lastStart.getTime()) / (1000 * 60 * 60 * 24));
  });

  const cycleText = computed(() => {
    if (cycleLength.value === 0) return '首次记录';
    return PeriodFormatter.formatCycleDescription(cycleLength.value);
  });

  const cycleColorClass = computed(() => {
    const length = cycleLength.value;
    if (length === 0) return 'text-gray-500';
    if (length < 21) return 'text-orange-500';
    if (length > 35) return 'text-red-500';
    return 'text-green-500';
  });

  const predictedNext = computed(() => {
    if (!(formData.startDate && periodStore.periodStats.averageCycleLength)) return '';

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
      formData.startDate &&
      formData.endDate &&
      !hasErrors() &&
      periodDuration.value > 0 &&
      periodDuration.value <= 14
    );
  });

  const deletionInfo = computed(() => {
    if (!props.record) return { dateRange: '', duration: '' };

    return {
      dateRange: PeriodDateUtils.formatDateRange(props.record.startDate, props.record.endDate),
      duration: PeriodFormatter.formatDuration(
        PeriodCalculator.calculatePeriodLength(props.record),
      ),
    };
  });

  const overlapInfo = computed(() => {
    if (!overlapRecord.value) return { dateRange: '' };

    return {
      dateRange: PeriodDateUtils.formatDateRange(
        overlapRecord.value.startDate,
        overlapRecord.value.endDate,
      ),
    };
  });

  // Methods
  function setDurationPreset(days: number) {
    if (!formData.startDate) return;
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
    if (formData.endDate && formData.startDate > formData.endDate) {
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
      overlapRecord.value = PeriodCalculator.getPeriodForDate(formData.startDate, existingRecords);
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
    if (!props.record) return;

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
      return !!(formData.startDate || formData.endDate || formData.notes);
    }

    return (
      formData.startDate !== props.record.startDate ||
      formData.endDate !== props.record.endDate ||
      formData.notes !== (props.record.notes || '')
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
    size="lg"
    :confirm-text="isEditing ? '更新' : '创建'"
    :confirm-loading="loading"
    :confirm-disabled="!canSubmit"
    :show-delete="!!isEditing"
    @confirm="handleSubmit"
    @delete="showDeleteConfirm = true"
    @close="$emit('cancel')"
  >
    <!-- 日期设置区域 -->
    <PeriodInfoCard
      title="日期设置"
      :icon="Calendar"
      color="blue"
      :show-bottom-border="false"
      class="mb-4"
    >
      <!-- 开始日期 -->
      <FormRow label="开始日期" required :error="getFieldErrors('startDate')[0]">
        <input
          v-model="formData.startDate"
          type="date"
          class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          :max="maxDate"
          required
          @change="onStartDateChange"
        />
      </FormRow>

      <!-- 结束日期 -->
      <FormRow label="结束日期" required :error="getFieldErrors('endDate')[0]">
        <input
          v-model="formData.endDate"
          type="date"
          class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          :min="formData.startDate"
          required
          @change="validateDates"
        />
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
    </PeriodInfoCard>

    <!-- 经期信息显示 -->
    <PeriodInfoCard
      v-if="showPeriodInfo"
      title="经期信息"
      :icon="Info"
      color="blue"
      :show-bottom-border="false"
      bg-class="bg-blue-50 dark:bg-blue-900/20"
      class="my-4"
    >
      <div class="space-y-2">
        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600 dark:text-gray-400">持续时间</span>
          <Badge variant="danger" size="sm">{{ periodDuration }}天</Badge>
        </div>
        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600 dark:text-gray-400">距离上次</span>
          <span class="text-sm font-bold" :class="cycleColorClass"> {{ cycleText }}</span>
        </div>
        <div v-if="predictedNext" class="flex justify-between items-center">
          <span class="text-sm text-gray-600 dark:text-gray-400">预测下次</span>
          <span class="text-sm font-semibold text-gray-900 dark:text-white"
            >{{ predictedNext }}</span
          >
        </div>
      </div>
    </PeriodInfoCard>

    <!-- 症状记录区域 -->
    <PeriodInfoCard
      title="症状记录"
      :icon="Plus"
      color="green"
      help-text="选择本次经期的症状程度"
      :show-bottom-border="false"
      class="mb-4"
    >
      <div class="space-y-4">
        <div
          v-for="symptomGroup in symptomGroups"
          :key="symptomGroup.type"
          class="p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg border border-gray-200 dark:border-gray-600"
        >
          <div class="flex items-center gap-2 mb-3">
            <i :class="[symptomGroup.icon, symptomGroup.color]" class="w-4 h-4" />
            <span class="text-sm font-medium text-gray-900 dark:text-white"
              >{{ symptomGroup.label }}</span
            >
          </div>
          <div class="grid grid-cols-3 gap-2">
            <button
              v-for="intensity in intensityLevels"
              :key="intensity.value"
              type="button"
              class="flex items-center justify-center gap-2 px-3 py-2 rounded-lg border transition-all text-sm font-medium"
              :class="symptoms[symptomGroup.type] === intensity.value
                ? intensity.value === 'Light'
                  ? 'bg-yellow-100 dark:bg-yellow-900/30 border-yellow-500 text-yellow-800 dark:text-yellow-300'
                  : intensity.value === 'Medium'
                    ? 'bg-orange-100 dark:bg-orange-900/30 border-orange-500 text-orange-800 dark:text-orange-300'
                    : 'bg-red-100 dark:bg-red-900/30 border-red-500 text-red-800 dark:text-red-300'
                : 'border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500 text-gray-700 dark:text-gray-300'"
              @click="updateSymptom(symptomGroup.type, intensity.value)"
            >
              <span
                class="w-2 h-2 rounded-full"
                :class="symptoms[symptomGroup.type] === intensity.value ? 'bg-current' : 'bg-gray-400'"
              />
              <span>{{ intensity.label }}</span>
            </button>
          </div>
        </div>
      </div>
    </PeriodInfoCard>

    <!-- 备注区域 -->
    <FormRow full-width>
      <textarea
        v-model="formData.notes"
        class="w-full px-4 py-3 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all resize-none"
        placeholder="记录本次经期的特殊情况、身体感受或其他想要记录的内容..."
        maxlength="500"
        rows="4"
      />
      <div class="text-xs text-gray-500 dark:text-gray-400 text-right mt-1">
        {{ notesLength }}/500
      </div>
    </FormRow>
  </Modal>

  <!-- 删除确认弹窗 -->
  <ConfirmDialog
    :open="showDeleteConfirm"
    title="删除经期记录"
    type="error"
    :loading="loading"
    icon-buttons
    @confirm="handleDelete"
    @close="showDeleteConfirm = false"
  >
    <div class="space-y-3">
      <p class="text-sm text-gray-700 dark:text-gray-300">确定要删除这条经期记录吗？</p>
      <div
        class="bg-gray-50 dark:bg-gray-700 rounded-lg p-3 border border-gray-200 dark:border-gray-600"
      >
        <div
          class="flex justify-between items-center py-2 border-b border-gray-200 dark:border-gray-600"
        >
          <span class="text-sm text-gray-600 dark:text-gray-400">记录时间:</span>
          <span class="text-sm font-semibold text-gray-900 dark:text-white"
            >{{ deletionInfo.dateRange }}</span
          >
        </div>
        <div class="flex justify-between items-center py-2">
          <span class="text-sm text-gray-600 dark:text-gray-400">持续时间:</span>
          <span class="text-sm font-semibold text-gray-900 dark:text-white"
            >{{ deletionInfo.duration }}</span
          >
        </div>
      </div>
      <div
        class="flex items-center gap-2 text-sm text-orange-800 dark:text-orange-300 bg-orange-50 dark:bg-orange-900/20 rounded-lg p-3"
      >
        <AlertTriangle :size="18" />
        <span>此操作无法撤销，请谨慎操作</span>
      </div>
    </div>
  </ConfirmDialog>

  <!-- 重叠警告弹窗 -->
  <ConfirmDialog
    :open="showOverlapWarning"
    title="日期重叠提醒"
    type="warning"
    confirm-text="继续保存"
    cancel-text="取消"
    @confirm="handleOverlapConfirm"
    @cancel="showOverlapWarning = false"
    @close="showOverlapWarning = false"
  >
    <div class="space-y-3">
      <p class="text-sm text-gray-700 dark:text-gray-300">检测到您选择的日期与已有记录存在重叠：</p>
      <div
        class="bg-yellow-50 dark:bg-yellow-900/20 p-3 rounded-lg border border-yellow-200 dark:border-yellow-800"
      >
        <div class="flex items-center gap-2 text-sm text-yellow-800 dark:text-yellow-300">
          <Calendar :size="16" />
          <span>{{ overlapInfo.dateRange }}</span>
        </div>
      </div>
      <p class="text-sm font-medium text-gray-900 dark:text-white">
        是否继续保存？这可能会影响数据的准确性。
      </p>
    </div>
  </ConfirmDialog>
</template>
