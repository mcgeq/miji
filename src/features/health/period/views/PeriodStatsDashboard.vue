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
  max-width: 80rem;
  margin: 0 auto;
}

.stats-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}

@media (min-width: 768px) {
  .stats-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (min-width: 1024px) {
  .stats-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

.stat-card {
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  padding: 1rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  transition: box-shadow 0.2s ease-in-out;
}

.stat-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.dark .stat-card {
  background-color: var(--color-base-200);
  border-color: var(--color-base-300);
}

.stat-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.stat-title {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.dark .stat-title {
  color: var(--color-base-content);
}

.stat-content {
  margin-bottom: 0.75rem;
}

.stat-value {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-base-content);
}

.dark .stat-value {
  color: var(--color-base-content);
}

.stat-description {
  font-size: 0.875rem;
  color: var(--color-neutral);
  margin-top: 0.25rem;
}

.dark .stat-description {
  color: var(--color-neutral-content);
}

.phase-indicator {
  width: 100%;
  background-color: var(--color-base-300);
  border-radius: 9999px;
  height: 0.5rem;
}

.dark .phase-indicator {
  background-color: var(--color-neutral);
}

.phase-progress {
  background-color: var(--color-accent);
  height: 0.5rem;
  border-radius: 9999px;
  transition: all 0.5s ease-in-out;
}

.countdown-ring {
  position: relative;
  display: flex;
  align-items: center;
  justify-content: center;
}

.countdown-svg {
  transform: rotate(-90deg);
}

.countdown-text {
  position: absolute;
  font-size: 0.75rem;
  font-weight: 700;
  color: var(--color-info);
}

.cycle-stats {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.cycle-stat {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.cycle-label {
  font-size: 0.875rem;
  color: var(--color-neutral);
}

.dark .cycle-label {
  color: var(--color-neutral-content);
}

.cycle-value {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.dark .cycle-value {
  color: var(--color-base-content);
}

.trend-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  margin-bottom: 0.75rem;
}

.trend-item:last-child {
  margin-bottom: 0;
}

.trend-label {
  font-size: 0.875rem;
  color: var(--color-neutral);
}

.dark .trend-label {
  color: var(--color-neutral-content);
}

.trend-indicator {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.trend-bar {
  height: 0.5rem;
  background-color: var(--color-primary);
  border-radius: 9999px;
  flex: 1;
  transition: all 0.5s ease-in-out;
}

.trend-bar.severity {
  background-color: var(--color-warning);
}

.trend-text {
  font-size: 0.75rem;
  color: var(--color-neutral);
  flex-shrink: 0;
}

.dark .trend-text {
  color: var(--color-neutral-content);
}

.flex-between {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.btn-primary {
  padding: 0.375rem 0.75rem;
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.btn-primary:hover {
  background-color: color-mix(in oklch, var(--color-primary) 85%, black);
}

.btn-primary:focus {
  outline: none;
  ring: 2px;
  ring-color: var(--color-primary);
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 2rem 0;
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }

  .stat-card {
    padding: 0.75rem;
  }

  .stat-value {
    font-size: 1.125rem;
  }
}
</style>
