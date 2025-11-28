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
  primary: { border: 'border-l-blue-500', text: 'text-blue-500', bg: 'bg-blue-500' },
  success: { border: 'border-l-green-500', text: 'text-green-500', bg: 'bg-green-500' },
  danger: { border: 'border-l-red-500', text: 'text-red-500', bg: 'bg-red-500' },
  warning: { border: 'border-l-amber-500', text: 'text-amber-500', bg: 'bg-amber-500' },
  info: { border: 'border-l-teal-500', text: 'text-teal-500', bg: 'bg-teal-500' },
};

const colorBorderClass = computed(() => colorMap[props.color].border);
const iconColorClass = computed(() => colorMap[props.color].text);

const trendTextClass = computed(() => {
  switch (props.trendType) {
    case 'up':
      return 'text-green-600 dark:text-green-400';
    case 'down':
      return 'text-red-600 dark:text-red-400';
    default:
      return 'text-gray-500 dark:text-gray-400';
  }
});

const changeTextClass = computed(() => {
  switch (props.changeType) {
    case 'increase':
      return 'text-green-600 dark:text-green-400';
    case 'decrease':
      return 'text-red-600 dark:text-red-400';
    default:
      return 'text-gray-500 dark:text-gray-400';
  }
});

const formattedValue = computed(() => props.value);
</script>

<template>
  <div
    class="relative overflow-hidden bg-white dark:bg-gray-800 rounded-lg border-l-4 p-4 shadow-sm transition-all duration-300 hover:shadow-md"
    :class="[colorBorderClass]"
  >
    <div class="flex items-center justify-between mb-2">
      <div class="text-xs font-semibold uppercase text-gray-500 dark:text-gray-400 tracking-wider">
        {{ title }}
      </div>
      <div class="opacity-80 transition-opacity duration-300 hover:opacity-100" :class="[iconColorClass]">
        <component :is="iconComponent" :size="24" />
      </div>
    </div>

    <div class="relative z-10">
      <div class="flex gap-1 items-baseline mb-1">
        <span class="text-sm font-semibold text-gray-700 dark:text-gray-300">{{ currency }}</span>
        <span
          class="text-2xl font-bold leading-none text-gray-900 dark:text-white"
          :class="[loading ? 'loading-shimmer' : '']"
        >
          {{ formattedValue }}
        </span>
      </div>

      <div v-if="subtitle" class="text-[11px] text-gray-500 dark:text-gray-400 mb-1">
        {{ subtitle }}
      </div>

      <!-- Comparison Mode -->
      <div v-if="showComparison" class="mb-3">
        <div class="text-xs text-gray-500 dark:text-gray-400">
          {{ compareLabel }}: {{ currency }}{{ compareValue }}
        </div>
        <div class="mt-1 flex gap-1 items-center text-sm font-medium" :class="changeTextClass">
          <component :is="changeIcon" :size="16" />
          <span>
            {{ changeAmount }} ({{ changePercentage }})
          </span>
        </div>
      </div>

      <!-- Trend -->
      <div v-else-if="trend" class="flex gap-1 items-center text-sm font-medium" :class="trendTextClass">
        <component :is="trendIcon" :size="16" />
        <span>{{ trend }}</span>
      </div>

      <!-- Extra Stats -->
      <div v-if="extraStats && extraStats.length" class="mt-3 space-y-1">
        <div
          v-for="stat in extraStats"
          :key="stat.label"
          class="text-xs flex justify-between"
        >
          <span class="text-gray-500 dark:text-gray-400">{{ stat.label }}</span>
          <span
            :class="[stat.color ? colorMap[stat.color].text : 'text-gray-500 dark:text-gray-400']"
          >
            {{ stat.value }}
          </span>
        </div>
      </div>
    </div>

    <!-- Decorative overlay -->
    <div class="absolute top-0 right-0 w-24 h-24 rounded-full bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.1),transparent)] translate-x-8 -translate-y-8 dark:bg-[radial-gradient(circle_at_center,rgba(255,255,255,0.05),transparent)]" />
  </div>
</template>

<style scoped>
/* 加载动画（无法用 Tailwind 替代） */
.loading-shimmer {
  color: transparent;
  background: linear-gradient(90deg, #f3f4f6, #e5e7eb, #f3f4f6);
  background-size: 200% 100%;
  -webkit-background-clip: text;
  background-clip: text;
  animation: shimmer 1.5s infinite;
}

:global(.dark) .loading-shimmer {
  background: linear-gradient(90deg, #374151, #4b5563, #374151);
  background-size: 200% 100%;
  -webkit-background-clip: text;
  background-clip: text;
}

@keyframes shimmer {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}
</style>
