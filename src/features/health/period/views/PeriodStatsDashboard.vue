<script setup lang="ts">
import { usePeriodStore as usePeriodStores } from '@/stores/periodStore';
import PeriodListView from './PeriodListView.vue';

// Store
const periodStore = usePeriodStores();

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
  if (days === 0)
    return '今天';
  if (days === 1)
    return '明天';
  if (days < 0)
    return '已延迟';
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
  const progress
    = Math.max(0, stats.value.daysUntilNext) / stats.value.averageCycleLength;
  return countdownCircumference.value * (1 - progress);
});

const cycleRegularity = computed(() => {
  // 计算周期规律性（基于标准差）
  const records = periodStore.periodRecords;
  if (records.length < 3)
    return 50;

  const cycles: number[] = [];
  for (let i = 1; i < records.length; i++) {
    const current = new Date(records[i].startDate);
    const previous = new Date(records[i - 1].startDate);
    const cycleDays
      = (current.getTime() - previous.getTime()) / (1000 * 60 * 60 * 24);
    cycles.push(cycleDays);
  }

  const average = cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length;
  const variance
    = cycles.reduce((sum, cycle) => sum + (cycle - average) ** 2, 0)
      / cycles.length;
  const standardDeviation = Math.sqrt(variance);

  // 标准差越小，规律性越高
  const regularity = Math.max(0, 100 - standardDeviation * 10);
  return Math.min(100, regularity);
});

const cycleRegularityText = computed(() => {
  const regularity = cycleRegularity.value;
  if (regularity >= 80)
    return '非常规律';
  if (regularity >= 60)
    return '较为规律';
  if (regularity >= 40)
    return '一般';
  return '不太规律';
});

const symptomSeverity = computed(() => {
  // 基于症状统计计算严重度
  const symptoms = periodStore.symptomsStats;
  const totalSymptoms = Object.values(symptoms).reduce(
    (sum, count) => sum + count,
    0,
  );
  if (totalSymptoms === 0)
    return 20;

  // 简化计算：症状越多，严重度越高
  return Math.min(
    100,
    (totalSymptoms / periodStore.currentMonthRecords.length) * 50,
  );
});

const symptomSeverityText = computed(() => {
  const severity = symptomSeverity.value;
  if (severity >= 80)
    return '较重';
  if (severity >= 60)
    return '中等';
  if (severity >= 40)
    return '轻度';
  return '很少';
});
</script>

<template>
  <div class="period-stats-dashboard space-y-6">
    <!-- 主要统计信息 -->
    <div class="stats-grid">
      <div class="stat-card current-phase">
        <div class="stat-header">
          <LucideCalendarHeart class="text-pink-500 wh-6" />
          <h3 class="stat-title">
            当前阶段
          </h3>
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ phaseLabel }}
          </div>
          <div class="stat-description">
            {{ phaseDescription }}
          </div>
        </div>
        <div class="phase-indicator">
          <div class="phase-progress" :style="{ width: `${phaseProgress}%` }" />
        </div>
      </div>

      <div class="stat-card next-period">
        <div class="stat-header">
          <LucideCalendarClock class="text-blue-500 wh-6" />
          <h3 class="stat-title">
            下次经期
          </h3>
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ nextPeriodText }}
          </div>
          <div class="stat-description">
            {{ nextPeriodDate }}
          </div>
        </div>
        <div class="countdown-ring">
          <svg class="countdown-svg" width="40" height="40">
            <circle
              cx="20" cy="20" r="16" stroke="currentColor" stroke-width="2" fill="none"
              class="text-gray-300 dark:text-gray-600"
            />
            <circle
              cx="20" cy="20" r="16" stroke="currentColor" stroke-width="2" fill="none" class="text-blue-500"
              :stroke-dasharray="countdownCircumference" :stroke-dashoffset="countdownOffset" stroke-linecap="round"
              transform="rotate(-90 20 20)"
            />
          </svg>
          <span class="countdown-text">{{ stats.daysUntilNext }}</span>
        </div>
      </div>

      <div class="stat-card cycle-info">
        <div class="stat-header">
          <LucideCalendarSync class="text-green-500 wh-6" />
          <h3 class="stat-title">
            周期信息
          </h3>
        </div>
        <div class="stat-content">
          <div class="cycle-stats">
            <div class="cycle-stat">
              <span class="cycle-label">平均周期</span>
              <span class="cycle-value">{{ stats.averageCycleLength }}天</span>
            </div>
            <div class="cycle-stat">
              <span class="cycle-label">平均经期</span>
              <span class="cycle-value">{{ stats.averagePeriodLength }}天</span>
            </div>
          </div>
        </div>
      </div>

      <div class="stat-card trends">
        <div class="stat-header">
          <LucideTrendingUp class="text-purple-500 wh-6" />
          <h3 class="stat-title">
            趋势分析
          </h3>
        </div>
        <div class="stat-content">
          <div class="trend-item">
            <span class="trend-label">周期规律性</span>
            <div class="trend-indicator">
              <div class="trend-bar" :style="{ width: `${cycleRegularity}%` }" />
              <span class="trend-text">{{ cycleRegularityText }}</span>
            </div>
          </div>
          <div class="trend-item">
            <span class="trend-label">症状严重度</span>
            <div class="trend-indicator">
              <div class="trend-bar severity" :style="{ width: `${symptomSeverity}%` }" />
              <span class="trend-text">{{ symptomSeverityText }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <PeriodListView />
  </div>
</template>

<style scoped lang="postcss">
.period-stats-dashboard {
  @apply max-w-7xl mx-auto;
}

.stats-grid {
  @apply grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4;
}

.stat-card {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4 shadow-sm hover:shadow-md transition-shadow;
}

.stat-header {
  @apply flex items-center gap-2 mb-3;
}

.stat-title {
  @apply text-sm font-medium text-gray-700 dark:text-gray-300;
}

.stat-content {
  @apply mb-3;
}

.stat-value {
  @apply text-xl font-bold text-gray-900 dark:text-white;
}

.stat-description {
  @apply text-sm text-gray-500 dark:text-gray-400 mt-1;
}

.phase-indicator {
  @apply w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2;
}

.phase-progress {
  @apply bg-pink-500 h-2 rounded-full transition-all duration-500;
}

.countdown-ring {
  @apply relative flex items-center justify-center;
}

.countdown-svg {
  @apply transform -rotate-90;
}

.countdown-text {
  @apply absolute text-xs font-bold text-blue-500;
}

.cycle-stats {
  @apply space-y-2;
}

.cycle-stat {
  @apply flex justify-between items-center;
}

.cycle-label {
  @apply text-sm text-gray-600 dark:text-gray-400;
}

.cycle-value {
  @apply text-lg font-semibold text-gray-900 dark:text-white;
}

.trend-item {
  @apply space-y-1 mb-3 last:mb-0;
}

.trend-label {
  @apply text-sm text-gray-600 dark:text-gray-400;
}

.trend-indicator {
  @apply flex items-center gap-2;
}

.trend-bar {
  @apply h-2 bg-purple-500 rounded-full flex-1 transition-all duration-500;
}

.trend-bar.severity {
  @apply bg-orange-500;
}

.trend-text {
  @apply text-xs text-gray-500 dark:text-gray-400 flex-shrink-0;
}

.flex-between {
  @apply flex items-center justify-between;
}

.btn-primary {
  @apply px-3 py-1.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 transition-colors flex items-center;
}

.empty-state {
  @apply flex flex-col items-center py-8;
}

@media (max-width: 768px) {
  .stats-grid {
    @apply grid-cols-1;
  }

  .stat-card {
    @apply p-3;
  }

  .stat-value {
    @apply text-lg;
  }
}
</style>
