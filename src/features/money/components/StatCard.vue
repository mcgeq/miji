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
import { computed } from 'vue';

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
const changeIcon = computed(() => changeIconMap[props.changeType || 'unchanged']);

const colorMap = {
  primary: { border: 'border-blue-500', text: 'text-blue-500' },
  success: { border: 'border-green-500', text: 'text-green-500' },
  danger: { border: 'border-red-500', text: 'text-red-500' },
  warning: { border: 'border-orange-500', text: 'text-orange-500' },
  info: { border: 'border-teal-500', text: 'text-teal-500' },
};

const colorBorderClass = computed(() => colorMap[props.color].border);
const iconColorClass = computed(() => colorMap[props.color].text);

const trendTextClass = computed(() => {
  switch (props.trendType) {
    case 'up':
      return 'text-green-500';
    case 'down':
      return 'text-red-500';
    default:
      return 'text-gray-500';
  }
});

const changeTextClass = computed(() => {
  switch (props.changeType) {
    case 'increase':
      return 'text-green-500';
    case 'decrease':
      return 'text-red-500';
    default:
      return 'text-gray-500';
  }
});

const formattedValue = computed(() => {
  return props.value;
});
</script>

<template>
  <div
    class="stat-card relative overflow-hidden border-l-4 rounded-xl bg-white p-5 shadow transition-all" :class="[
      colorBorderClass,
    ]"
  >
    <div class="mb-4 flex items-center justify-between">
      <div class="text-sm text-gray-600 font-medium tracking-wide uppercase">
        {{ title }}
      </div>
      <div class="opacity-80 transition group-hover:opacity-100" :class="[iconColorClass]">
        <component :is="iconComponent" :size="24" />
      </div>
    </div>

    <div class="relative z-10">
      <div class="mb-2 flex items-baseline gap-1">
        <span class="text-lg text-gray-500 font-semibold">{{ currency }}</span>
        <span
          class="text-3xl font-bold leading-none" :class="[
            loading ? 'text-transparent bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-clip-text animate-pulse' : 'text-gray-800',
          ]"
        >
          {{ formattedValue }}
        </span>
      </div>

      <div v-if="subtitle" class="mb-3 text-xs text-gray-500">
        {{ subtitle }}
      </div>

      <!-- Comparison Mode -->
      <div v-if="showComparison" class="mb-3">
        <div class="text-xs text-gray-500">
          {{ compareLabel }}: {{ currency }}{{ compareValue }}
        </div>
        <div class="flex items-center gap-1 text-sm font-medium">
          <component :is="changeIcon" :size="16" :class="changeTextClass" />
          <span :class="changeTextClass">
            {{ changeAmount }} ({{ changePercentage }})
          </span>
        </div>
      </div>

      <!-- Trend (fallback if no comparison) -->
      <div v-else-if="trend" class="flex items-center gap-1 text-sm font-medium">
        <component :is="trendIcon" :size="16" />
        <span :class="trendTextClass">{{ trend }}</span>
      </div>

      <!-- Extra Stats -->
      <div v-if="extraStats && extraStats.length" class="mt-3 space-y-1">
        <div v-for="stat in extraStats" :key="stat.label" class="flex justify-between text-xs">
          <span class="text-gray-500">{{ stat.label }}</span>
          <span :class="[stat.color ? colorMap[stat.color].text : 'text-gray-600']">
            {{ stat.value }}
          </span>
        </div>
      </div>
    </div>

    <!-- Decorative overlay -->
    <div
      class="absolute right-0 top-0 h-24 w-24 translate-x-8 transform rounded-full from-transparent via-white/10 to-transparent bg-gradient-to-br -translate-y-8"
    />
  </div>
</template>
