<template>
  <div
    :class="[
      'stat-card relative overflow-hidden rounded-xl p-5 bg-white shadow transition-all border-l-4',
      colorBorderClass
    ]"
  >
    <div class="flex justify-between items-center mb-4">
      <div class="text-sm font-medium uppercase tracking-wide text-gray-600">
        {{ title }}
      </div>
      <div :class="[iconColorClass, 'opacity-80 group-hover:opacity-100 transition']">
        <component :is="iconComponent" :size="24" />
      </div>
    </div>

    <div class="relative z-10">
      <div class="flex items-baseline gap-1 mb-2">
        <span class="text-lg font-semibold text-gray-500">{{ currency }}</span>
        <span
          :class="[
            'text-3xl font-bold leading-none',
            loading ? 'text-transparent bg-gradient-to-r from-gray-100 via-gray-200 to-gray-100 bg-clip-text animate-pulse' : 'text-gray-800'
          ]"
        >
          {{ formattedValue }}
        </span>
      </div>

      <div v-if="subtitle" class="text-xs text-gray-500 mb-3">
        {{ subtitle }}
      </div>

      <div v-if="trend" class="flex items-center gap-1 text-sm font-medium">
        <component :is="trendIcon" :size="16" />
        <span :class="trendTextClass">{{ trend }}</span>
      </div>
    </div>

    <!-- Decorative overlay -->
    <div class="absolute top-0 right-0 w-24 h-24 bg-gradient-to-br from-transparent via-white/10 to-transparent rounded-full transform translate-x-8 -translate-y-8" />
  </div>
</template>


<script setup lang="ts">
import {
  Wallet,
  TrendingUp,
  TrendingDown,
  Target,
  CreditCard,
  PiggyBank,
  ArrowUp,
  ArrowDown,
  Minus,
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
}

const props = withDefaults(defineProps<Props>(), {
  currency: '¥',
  icon: 'wallet',
  color: 'primary',
  trendType: 'neutral',
  loading: false,
});

const iconMap = {
  wallet: Wallet,
  'trending-up': TrendingUp,
  'trending-down': TrendingDown,
  target: Target,
  'credit-card': CreditCard,
  'piggy-bank': PiggyBank,
};

const trendIconMap = {
  up: ArrowUp,
  down: ArrowDown,
  neutral: Minus,
};

const iconComponent = computed(
  () => iconMap[props.icon as keyof typeof iconMap] || Wallet,
);
const trendIcon = computed(() => trendIconMap[props.trendType]);

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

const formattedValue = computed(() => {
  return props.value;
});
</script>
