<script setup lang="ts">
  import {
    CalendarClock,
    CalendarHeart,
    Calendar as CalendarIcon,
    TrendingUp,
  } from 'lucide-vue-next';
  import { Badge, Card } from '@/components/ui';
  import type {
    PeriodRecordCreate,
    PeriodRecords,
    PeriodRecordUpdate,
  } from '@/schema/health/period';
  import { usePeriodStore as usePeriodStores } from '@/stores/periodStore';
  import { usePeriodRecords } from '../composables/usePeriodRecords';
  import PeriodListView from './PeriodListView.vue';
  import PeriodRecordForm from './PeriodRecordForm.vue';

  // Store & Composables
  const periodStore = usePeriodStores();
  const { t } = useI18n();
  const periodRecords = usePeriodRecords(t);

  // UI State
  const showRecordForm = ref(false);
  const editingRecord = ref<PeriodRecords | undefined>();

  // Methods
  function openRecordForm(record?: PeriodRecords) {
    editingRecord.value = record;
    showRecordForm.value = true;
  }

  function closeRecordForm() {
    showRecordForm.value = false;
    editingRecord.value = undefined;
  }

  async function handleRecordCreate(record: PeriodRecordCreate) {
    await periodRecords.create(record);
    closeRecordForm();
  }

  async function handleRecordUpdate(serialNum: string, record: PeriodRecordUpdate) {
    await periodRecords.update(serialNum, record);
    closeRecordForm();
  }

  async function handleRecordDelete(serialNum: string) {
    await periodRecords.remove(serialNum);
    closeRecordForm();
  }

  // Computed
  const stats = computed(() => periodStore.periodStats);

  const phaseLabel = computed(() => {
    const phase = stats.value.currentPhase;
    const labels = {
      Menstrual: '经期',
      Follicular: '卵泡期',
      Ovulation: '排卵期',
      Luteal: '黄体期',
    };
    return labels[phase];
  });

  const phaseDescription = computed(() => {
    const phase = stats.value.currentPhase;
    const descriptions = {
      Menstrual: '月经期间，注意休息和保暖',
      Follicular: '新周期开始，精力逐渐恢复',
      Ovulation: '排卵期，受孕几率较高',
      Luteal: '黄体期，可能出现经前症状',
    };
    return descriptions[phase];
  });

  const phaseProgress = computed(() => {
    // 简化的阶段进度计算
    const phase = stats.value.currentPhase;
    const totalDays = stats.value.averageCycleLength;
    const daysUntilNext = stats.value.daysUntilNext;
    const daysSinceStart = totalDays - daysUntilNext;

    let phaseStart = 0;
    let phaseLength = 0;

    switch (phase) {
      case 'Menstrual':
        phaseStart = 0;
        phaseLength = stats.value.averagePeriodLength;
        break;
      case 'Follicular':
        phaseStart = stats.value.averagePeriodLength;
        phaseLength = Math.floor(totalDays / 2) - stats.value.averagePeriodLength;
        break;
      case 'Ovulation':
        phaseStart = Math.floor(totalDays / 2) - 1;
        phaseLength = 3;
        break;
      case 'Luteal':
        phaseStart = Math.floor(totalDays / 2) + 2;
        phaseLength = totalDays - phaseStart;
        break;
    }

    const progressInPhase = daysSinceStart - phaseStart;
    return Math.max(0, Math.min(100, (progressInPhase / phaseLength) * 100));
  });

  const nextPeriodText = computed(() => {
    const days = stats.value.daysUntilNext;
    if (days === 0) return '今天';
    if (days === 1) return '明天';
    if (days < 0) return '已延迟';
    return `${days}天后`;
  });

  const nextPeriodDate = computed(() => {
    if (stats.value.nextPredictedDate) {
      const date = new Date(stats.value.nextPredictedDate);
      return `${date.getMonth() + 1}月${date.getDate()}日`;
    }
    return '暂无预测';
  });

  const countdownCircumference = computed(() => 2 * Math.PI * 16);

  const countdownOffset = computed(() => {
    const progress = Math.max(0, stats.value.daysUntilNext) / stats.value.averageCycleLength;
    return countdownCircumference.value * (1 - progress);
  });

  const cycleRegularity = computed(() => {
    // 计算周期规律性（基于标准差）
    const records = periodStore.periodRecords;
    if (records.length < 3) return 50;

    const cycles: number[] = [];
    for (let i = 1; i < records.length; i++) {
      const current = new Date(records[i].startDate);
      const previous = new Date(records[i - 1].startDate);
      const cycleDays = (current.getTime() - previous.getTime()) / (1000 * 60 * 60 * 24);
      cycles.push(cycleDays);
    }

    const average = cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length;
    const variance = cycles.reduce((sum, cycle) => sum + (cycle - average) ** 2, 0) / cycles.length;
    const standardDeviation = Math.sqrt(variance);

    // 标准差越小，规律性越高
    const regularity = Math.max(0, 100 - standardDeviation * 10);
    return Math.min(100, regularity);
  });

  const cycleRegularityText = computed(() => {
    const regularity = cycleRegularity.value;
    if (regularity >= 80) return '非常规律';
    if (regularity >= 60) return '较为规律';
    if (regularity >= 40) return '一般';
    return '不太规律';
  });

  const symptomSeverity = computed(() => {
    // 基于症状统计计算严重度
    const symptoms = periodStore.symptomsStats;
    const totalSymptoms = Object.values(symptoms).reduce((sum, count) => sum + count, 0);
    if (totalSymptoms === 0) return 20;

    // 简化计算：症状越多，严重度越高
    return Math.min(100, (totalSymptoms / periodStore.currentMonthRecords.length) * 50);
  });

  const symptomSeverityText = computed(() => {
    const severity = symptomSeverity.value;
    if (severity >= 80) return '较重';
    if (severity >= 60) return '中等';
    if (severity >= 40) return '轻度';
    return '很少';
  });
</script>

<template>
  <div class="max-w-7xl mx-auto space-y-6">
    <!-- 主要统计信息 -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      <Card shadow="md" padding="md" hoverable>
        <div class="flex items-center gap-2 mb-3">
          <CalendarHeart :size="24" class="text-pink-500" />
          <h3 class="text-sm font-medium text-gray-700 dark:text-gray-300">当前阶段</h3>
        </div>
        <div class="mb-3">
          <div class="text-xl font-bold text-gray-900 dark:text-white">{{ phaseLabel }}</div>
          <div class="text-sm text-gray-500 dark:text-gray-400 mt-1">{{ phaseDescription }}</div>
        </div>
        <div class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-pink-500 to-rose-500 rounded-full transition-all duration-500 ease-in-out"
            :style="{ width: `${phaseProgress}%` }"
          />
        </div>
      </Card>

      <Card shadow="md" padding="md" hoverable>
        <div class="flex items-center gap-2 mb-3">
          <CalendarClock :size="24" class="text-blue-500" />
          <h3 class="text-sm font-medium text-gray-700 dark:text-gray-300">下次经期</h3>
        </div>
        <div class="mb-3">
          <div class="text-xl font-bold text-gray-900 dark:text-white">{{ nextPeriodText }}</div>
          <div class="text-sm text-gray-500 dark:text-gray-400 mt-1">{{ nextPeriodDate }}</div>
        </div>
        <div class="relative flex items-center justify-center">
          <svg class="-rotate-90" width="40" height="40">
            <circle
              cx="20"
              cy="20"
              r="16"
              stroke="currentColor"
              stroke-width="2"
              fill="none"
              class="text-gray-300 dark:text-gray-600"
            />
            <circle
              cx="20"
              cy="20"
              r="16"
              stroke="currentColor"
              stroke-width="2"
              fill="none"
              class="text-blue-500 transition-all duration-500"
              :stroke-dasharray="countdownCircumference"
              :stroke-dashoffset="countdownOffset"
              stroke-linecap="round"
            />
          </svg>
          <span class="absolute text-xs font-bold text-blue-600 dark:text-blue-400"
            >{{ stats.daysUntilNext }}</span
          >
        </div>
      </Card>

      <Card shadow="md" padding="md" hoverable>
        <div class="flex items-center gap-2 mb-3">
          <CalendarIcon :size="24" class="text-green-500" />
          <h3 class="text-sm font-medium text-gray-700 dark:text-gray-300">周期信息</h3>
        </div>
        <div class="space-y-3">
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-500 dark:text-gray-400">平均周期</span>
            <Badge variant="success" size="sm">{{ stats.averageCycleLength }}天</Badge>
          </div>
          <div class="flex justify-between items-center">
            <span class="text-sm text-gray-500 dark:text-gray-400">平均经期</span>
            <Badge variant="success" size="sm">{{ stats.averagePeriodLength }}天</Badge>
          </div>
        </div>
      </Card>

      <Card shadow="md" padding="md" hoverable>
        <div class="flex items-center gap-2 mb-3">
          <TrendingUp :size="24" class="text-purple-500" />
          <h3 class="text-sm font-medium text-gray-700 dark:text-gray-300">趋势分析</h3>
        </div>
        <div class="space-y-4">
          <div class="space-y-1">
            <div class="flex justify-between items-center mb-1">
              <span class="text-sm text-gray-500 dark:text-gray-400">周期规律性</span>
              <span class="text-xs font-medium text-gray-600 dark:text-gray-300"
                >{{ cycleRegularityText }}</span
              >
            </div>
            <div class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
              <div
                class="h-full bg-gradient-to-r from-blue-500 to-blue-600 rounded-full transition-all duration-500"
                :style="{ width: `${cycleRegularity}%` }"
              />
            </div>
          </div>
          <div class="space-y-1">
            <div class="flex justify-between items-center mb-1">
              <span class="text-sm text-gray-500 dark:text-gray-400">症状严重度</span>
              <span class="text-xs font-medium text-gray-600 dark:text-gray-300"
                >{{ symptomSeverityText }}</span
              >
            </div>
            <div class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
              <div
                class="h-full bg-gradient-to-r from-yellow-500 to-orange-500 rounded-full transition-all duration-500"
                :style="{ width: `${symptomSeverity}%` }"
              />
            </div>
          </div>
        </div>
      </Card>
    </div>

    <PeriodListView @add-record="openRecordForm()" @edit-record="openRecordForm($event)" />

    <!-- 经期记录表单 -->
    <PeriodRecordForm
      v-if="showRecordForm"
      :record="editingRecord"
      @create="handleRecordCreate"
      @update="handleRecordUpdate"
      @delete="handleRecordDelete"
      @cancel="closeRecordForm"
    />
  </div>
</template>
