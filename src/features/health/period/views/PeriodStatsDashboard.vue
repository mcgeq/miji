<template>
  <div class="period-stats-dashboard space-y-6">
    <!-- 主要统计信息 -->
    <div class="stats-grid">
      <div class="stat-card current-phase">
        <div class="stat-header">
          <CalendarHeart class="wh-6 text-pink-500" />
          <h3 class="stat-title">当前阶段</h3>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ phaseLabel }}</div>
          <div class="stat-description">{{ phaseDescription }}</div>
        </div>
        <div class="phase-indicator">
          <div class="phase-progress" :style="{ width: `${phaseProgress}%` }"></div>
        </div>
      </div>

      <div class="stat-card next-period">
        <div class="stat-header">
          <CalendarClock class="wh-6 text-blue-500" /> 
          <h3 class="stat-title">下次经期</h3>
        </div>
        <div class="stat-content">
          <div class="stat-value">{{ nextPeriodText }}</div>
          <div class="stat-description">{{ nextPeriodDate }}</div>
        </div>
        <div class="countdown-ring">
          <svg class="countdown-svg" width="40" height="40">
            <circle cx="20" cy="20" r="16" stroke="currentColor" stroke-width="2" fill="none"
              class="text-gray-300 dark:text-gray-600" />
            <circle cx="20" cy="20" r="16" stroke="currentColor" stroke-width="2" fill="none" class="text-blue-500"
              :stroke-dasharray="countdownCircumference" :stroke-dashoffset="countdownOffset" stroke-linecap="round"
              transform="rotate(-90 20 20)" />
          </svg>
          <span class="countdown-text">{{ stats.daysUntilNext }}</span>
        </div>
      </div>

      <div class="stat-card cycle-info">
        <div class="stat-header">
          <CalendarSync class="wh-6 text-green-500" />
          <h3 class="stat-title">周期信息</h3>
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
          <TrendingUp class="wh-6 text-purple-500" />
          <h3 class="stat-title">趋势分析</h3>
        </div>
        <div class="stat-content">
          <div class="trend-item">
            <span class="trend-label">周期规律性</span>
            <div class="trend-indicator">
              <div class="trend-bar" :style="{ width: `${cycleRegularity}%` }"></div>
              <span class="trend-text">{{ cycleRegularityText }}</span>
            </div>
          </div>
          <div class="trend-item">
            <span class="trend-label">症状严重度</span>
            <div class="trend-indicator">
              <div class="trend-bar severity" :style="{ width: `${symptomSeverity}%` }"></div>
              <span class="trend-text">{{ symptomSeverityText }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 最近记录 -->
    <div class="recent-records card-base p-4">
      <div class="flex-between mb-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">最近记录</h3>
        <button @click="emit('add-record')" class="btn-primary text-sm">
          <Plus class="wh-5" />
        </button>
      </div>

      <div v-if="periodStore.periodRecords.length === 0" class="empty-state">
        <i class="i-tabler-calendar-off wh-12 text-gray-400 mx-auto mb-3" />
        <p class="text-gray-500 dark:text-gray-400 text-center">
          还没有经期记录，<button @click="emit('add-record')" class="text-blue-500 hover:underline">点击添加</button>
        </p>
      </div>

      <div v-else class="space-y-3">
        <div v-for="record in recentRecords" :key="record.serialNum" class="record-item"
          @click="$emit('edit-record', record)">
          <div class="record-date">
            <div class="record-month">{{ formatMonth(record.startDate) }}</div>
            <div class="record-day">{{ formatDay(record.startDate) }}</div>
          </div>
          <div class="record-info">
            <div class="record-duration">
              持续 {{ calculateDuration(record) }} 天
            </div>
            <div class="record-cycle">
              {{ calculateCycleFromPrevious(record) }}
            </div>
          </div>
          <div class="record-actions">
            <i class="i-tabler-chevron-right wh-4 text-gray-400" />
          </div>
        </div>
      </div>
    </div>

    <!-- 健康建议 -->
    <div class="health-tips card-base p-4">
      <div class="flex items-center gap-2 mb-3">
        <i class="i-tabler-bulb wh-5 text-yellow-500" />
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">健康建议</h3>
      </div>
      <div class="space-y-2">
        <div v-for="tip in healthTips" :key="tip.id" class="tip-item">
          <i :class="tip.icon" class="wh-4 text-blue-500 flex-shrink-0 mt-0.5" />
          <span class="text-sm text-gray-700 dark:text-gray-300">{{ tip.text }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  CalendarClock,
  CalendarHeart,
  CalendarSync,
  Plus,
  TrendingUp,
} from 'lucide-vue-next';
import type {PeriodRecords} from '@/schema/health/period';
import {usePeriodStore} from '@/stores/periodStore';

// Emits
const emit = defineEmits<{
  'add-record': [];
  'edit-record': [record: PeriodRecords];
}>();

// Store
const periodStore = usePeriodStore();

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
  const progress =
    Math.max(0, stats.value.daysUntilNext) / stats.value.averageCycleLength;
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
    const cycleDays =
      (current.getTime() - previous.getTime()) / (1000 * 60 * 60 * 24);
    cycles.push(cycleDays);
  }

  const average = cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length;
  const variance =
    cycles.reduce((sum, cycle) => sum + Math.pow(cycle - average, 2), 0) /
    cycles.length;
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
  const totalSymptoms = Object.values(symptoms).reduce(
    (sum, count) => sum + count,
    0,
  );
  if (totalSymptoms === 0) return 20;

  // 简化计算：症状越多，严重度越高
  return Math.min(
    100,
    (totalSymptoms / periodStore.currentMonthRecords.length) * 50,
  );
});

const symptomSeverityText = computed(() => {
  const severity = symptomSeverity.value;
  if (severity >= 80) return '较重';
  if (severity >= 60) return '中等';
  if (severity >= 40) return '轻度';
  return '很少';
});

const recentRecords = computed(() => {
  return periodStore.periodRecords
    .slice()
    .sort(
      (a, b) =>
        new Date(b.startDate).getTime() - new Date(a.startDate).getTime(),
    )
    .slice(0, 3);
});

const healthTips = computed(() => {
  const tips = [
    {
      id: 1,
      icon: 'i-tabler-droplet',
      text: '每天喝足够的水有助于缓解经期不适',
    },
    {
      id: 2,
      icon: 'i-tabler-moon',
      text: '保持规律的睡眠时间对月经周期很重要',
    },
    {
      id: 3,
      icon: 'i-tabler-apple',
      text: '富含铁质的食物有助于补充经期流失的营养',
    },
    {
      id: 4,
      icon: 'i-tabler-activity',
      text: '适度的运动可以缓解经期症状',
    },
  ];

  // 根据当前阶段返回相关建议
  const phase = stats.value.currentPhase;
  if (phase === 'Menstrual') {
    return [
      {id: 1, icon: 'i-tabler-cup', text: '多喝温水，避免冷饮'},
      {id: 2, icon: 'i-tabler-bed', text: '充分休息，避免剧烈运动'},
      {id: 3, icon: 'i-tabler-flame', text: '注意保暖，特别是腹部'},
    ];
  }

  return tips.slice(0, 3);
});

// Methods
const formatMonth = (dateStr: string) => {
  const date = new Date(dateStr);
  return `${date.getMonth() + 1}月`;
};

const formatDay = (dateStr: string) => {
  const date = new Date(dateStr);
  return date.getDate();
};

const calculateDuration = (record: PeriodRecords) => {
  const start = new Date(record.startDate);
  const end = new Date(record.endDate);
  return (
    Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1
  );
};

const calculateCycleFromPrevious = (record: PeriodRecords) => {
  const records = periodStore.periodRecords
    .slice()
    .sort(
      (a, b) =>
        new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

  const index = records.findIndex((r) => r.serialNum === record.serialNum);
  if (index <= 0) return '首次记录';

  const current = new Date(record.startDate);
  const previous = new Date(records[index - 1].startDate);
  const cycleDays = Math.ceil(
    (current.getTime() - previous.getTime()) / (1000 * 60 * 60 * 24),
  );

  return `周期 ${cycleDays} 天`;
};
</script>

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

.card-base {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm;
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

.record-item {
  @apply flex items-center gap-4 p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors;
}

.record-date {
  @apply text-center flex-shrink-0;
}

.record-month {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

.record-day {
  @apply text-lg font-bold text-gray-900 dark:text-white;
}

.record-info {
  @apply flex-1;
}

.record-duration {
  @apply text-sm font-medium text-gray-900 dark:text-white;
}

.record-cycle {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

.record-actions {
  @apply flex-shrink-0;
}

.tip-item {
  @apply flex items-start gap-2;
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
