<script setup lang="ts">
import {
  ArrowDown,
  ArrowUp,
  CreditCard,
  Minus,
  PiggyBank,
  Target,
  TrendingDown,
  TrendingUp,
  Wallet,
} from 'lucide-vue-next';

interface Props {
  title: string;
  value: string;
  currency?: string;
  icon?: string;
  color?: 'primary' | 'success' | 'danger' | 'warning' | 'info';
  subtitle?: string;
  trend?: string;
  trendType?: 'up' | 'down' | 'neutral';
  loading?: boolean;
  compareValue?: string;
  compareLabel?: string;
  changeAmount?: string;
  changePercentage?: string;
  changeType?: 'increase' | 'decrease' | 'unchanged';
  showComparison?: boolean;
  extraStats?: Array<{
    label: string;
    value: string;
    color?: 'primary' | 'success' | 'danger' | 'warning' | 'info';
  }>;
}

const props = withDefaults(defineProps<Props>(), {
  currency: '¥',
  icon: 'wallet',
  color: 'primary',
  trendType: 'neutral',
  loading: false,
  showComparison: false,
});

const iconMap = {
  'wallet': Wallet,
  'trending-up': TrendingUp,
  'trending-down': TrendingDown,
  'target': Target,
  'credit-card': CreditCard,
  'piggy-bank': PiggyBank,
};

const trendIconMap = {
  up: ArrowUp,
  down: ArrowDown,
  neutral: Minus,
};

const changeIconMap = {
  increase: ArrowUp,
  decrease: ArrowDown,
  unchanged: Minus,
};

const iconComponent = computed(
  () => iconMap[props.icon as keyof typeof iconMap] || Wallet,
);
const trendIcon = computed(() => trendIconMap[props.trendType]);
const changeIcon = computed(
  () => changeIconMap[props.changeType || 'unchanged'],
);

const colorMap = {
  primary: { border: 'border-primary', text: 'text-primary' },
  success: { border: 'border-success', text: 'text-success' },
  danger: { border: 'border-danger', text: 'text-danger' },
  warning: { border: 'border-warning', text: 'text-warning' },
  info: { border: 'border-info', text: 'text-info' },
};

const colorBorderClass = computed(() => colorMap[props.color].border);
const iconColorClass = computed(() => colorMap[props.color].text);

const trendTextClass = computed(() => {
  switch (props.trendType) {
    case 'up':
      return 'text-success';
    case 'down':
      return 'text-danger';
    default:
      return 'text-gray';
  }
});

const changeTextClass = computed(() => {
  switch (props.changeType) {
    case 'increase':
      return 'text-success';
    case 'decrease':
      return 'text-danger';
    default:
      return 'text-gray';
  }
});

const formattedValue = computed(() => props.value);
</script>

<template>
  <div class="stat-card" :class="[colorBorderClass]">
    <div class="stat-header">
      <div class="stat-title">
        {{ title }}
      </div>
      <div class="stat-icon" :class="[iconColorClass]">
        <component :is="iconComponent" :size="24" />
      </div>
    </div>

    <div class="stat-body">
      <div class="stat-value">
        <span class="currency">{{ currency }}</span>
        <span class="value" :class="[loading ? 'loading' : '']">
          {{ formattedValue }}
        </span>
      </div>

      <div v-if="subtitle" class="subtitle">
        {{ subtitle }}
      </div>

      <!-- Comparison Mode -->
      <div v-if="showComparison" class="comparison">
        <div class="compare-label">
          {{ compareLabel }}: {{ currency }}{{ compareValue }}
        </div>
        <div class="compare-change">
          <component :is="changeIcon" :size="16" :class="changeTextClass" />
          <span :class="changeTextClass">
            {{ changeAmount }} ({{ changePercentage }})
          </span>
        </div>
      </div>

      <!-- Trend -->
      <div v-else-if="trend" class="trend">
        <component :is="trendIcon" :size="16" />
        <span :class="trendTextClass">{{ trend }}</span>
      </div>

      <!-- Extra Stats -->
      <div v-if="extraStats && extraStats.length" class="extra-stats">
        <div
          v-for="stat in extraStats"
          :key="stat.label"
          class="extra-stat"
        >
          <span class="extra-label">{{ stat.label }}</span>
          <span
            :class="[stat.color ? colorMap[stat.color].text : 'text-gray']"
          >
            {{ stat.value }}
          </span>
        </div>
      </div>
    </div>

    <!-- Decorative overlay -->
    <div class="overlay" />
  </div>
</template>

<style scoped>
/* ---------- 基础卡片 ---------- */
.stat-card {
  position: relative;
  overflow: hidden;
  background: var(--color-base-100);
  border-radius: 8px;
  border-left: 3px solid #3b82f6; /* 默认蓝色 */
  padding: 16px;
  box-shadow: 0 1px 4px rgba(0, 0, 0, 0.06);
  transition: all 0.3s ease;
}
.stat-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}
.stat-title {
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  color: var(--color-neutral);
  letter-spacing: 0.05em;
}
.stat-icon {
  opacity: 0.8;
  transition: opacity 0.3s ease;
}
.stat-card:hover .stat-icon {
  opacity: 1;
}

/* ---------- 数值部分 ---------- */
.stat-body {
  position: relative;
  z-index: 10;
}
.stat-value {
  display: flex;
  gap: 4px;
  align-items: baseline;
  margin-bottom: 4px;
}
.currency {
  font-size: 14px;
  font-weight: 600;
  color: var(--color-accent);
}
.value {
  font-size: 24px;
  font-weight: bold;
  line-height: 1;
  color: var(--color-accent-content);
}
.value.loading {
  color: transparent;
  background: linear-gradient(90deg, #f3f4f6, #e5e7eb, #f3f4f6);
  background-size: 200% 100%;
  -webkit-background-clip: text;
  background-clip: text;
  animation: pulse 1.5s infinite;
}
@keyframes pulse {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}
.subtitle {
  font-size: 11px;
  color: var(--color-neutral);
  margin-bottom: 4px;
}

/* ---------- 比较数据 ---------- */
.comparison {
  margin-bottom: 12px;
}
.compare-label {
  font-size: 12px;
  color: #6b7280;
}
.compare-change {
  margin-top: 4px;
  display: flex;
  gap: 4px;
  align-items: center;
  font-size: 14px;
  font-weight: 500;
}

/* ---------- 趋势 ---------- */
.trend {
  display: flex;
  gap: 4px;
  align-items: center;
  font-size: 14px;
  font-weight: 500;
}

/* ---------- 附加数据 ---------- */
.extra-stats {
  margin-top: 12px;
}
.extra-stat {
  font-size: 12px;
  display: flex;
  justify-content: space-between;
}
.extra-label {
  color: #6b7280;
}

/* ---------- 颜色 ---------- */
.text-primary {
  color: #3b82f6;
}
.text-success {
  color: #10b981;
}
.text-danger {
  color: #ef4444;
}
.text-warning {
  color: #f59e0b;
}
.text-info {
  color: #14b8a6;
}
.text-gray {
  color: #6b7280;
}
.border-primary {
  border-left-color: #3b82f6 !important;
}
.border-success {
  border-left-color: #10b981 !important;
}
.border-danger {
  border-left-color: #ef4444 !important;
}
.border-warning {
  border-left-color: #f59e0b !important;
}
.border-info {
  border-left-color: #14b8a6 !important;
}

/* ---------- 装饰 ---------- */
.overlay {
  position: absolute;
  top: 0;
  right: 0;
  width: 96px;
  height: 96px;
  border-radius: 50%;
  background: radial-gradient(
    circle at center,
    rgba(255, 255, 255, 0.1),
    transparent
  );
  transform: translate(32px, -32px);
}
</style>
