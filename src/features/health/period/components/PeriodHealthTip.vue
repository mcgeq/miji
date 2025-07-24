<script setup lang="ts">
import { Heart } from 'lucide-vue-next';
import { HealthTipsManager } from '../utils/periodUtils';
import type { PeriodStats } from '@/schema/health/period';

interface Props {
  stats: PeriodStats;
}
const props = defineProps<Props>();

const healthTips = computed(() => {
  return HealthTipsManager.getPersonalizedTips(props.stats.currentPhase);
});
</script>

<template>
  <!-- 健康建议 -->
  <div class="health-tips card-base p-4">
    <div class="mb-4 flex items-center gap-2">
      <div
        class="h-10 w-10 flex items-center justify-center rounded-full from-green-500 to-emerald-500 bg-gradient-to-r"
      >
        <Heart class="wh-5 text-white" />
      </div>
      <h3 class="text-lg text-gray-900 font-semibold dark:text-white">
        健康建议
      </h3>
    </div>

    <div class="flex flex-col space-y-2">
      <div
        v-for="tip in healthTips"
        :key="tip.id"
        class="flex items-center gap-3 rounded-lg bg-blue-50 p-3 dark:bg-blue-900/30"
      >
        <component :is="tip.icon" class="wh-5 text-blue-600 dark:text-blue-400" />
        <span class="text-sm text-gray-800 leading-relaxed dark:text-gray-200">
          {{ tip.text }}
        </span>
      </div>
    </div>
  </div>
</template>

<style lang="postcss" scoped>
.card-base {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm;
}
</style>
