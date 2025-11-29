<script setup lang="ts">
import { Heart } from 'lucide-vue-next';
import { HealthTipsManager } from '../utils/periodUtils';
import PeriodInfoCard from './PeriodInfoCard.vue';
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
  <PeriodInfoCard title="健康建议" :icon="Heart" color="green">
    <!-- 建议列表 -->
    <div class="flex flex-col gap-2.5">
      <div
        v-for="tip in healthTips"
        :key="tip.id"
        class="flex items-center gap-3 px-3 py-2.5 rounded-lg bg-gray-50 dark:bg-gray-700/50 transition-colors hover:bg-gray-100 dark:hover:bg-gray-700"
      >
        <!-- 提示图标 -->
        <component
          :is="tip.icon"
          class="w-5 h-5 flex-shrink-0 text-green-600 dark:text-green-400"
        />

        <!-- 提示文本 -->
        <span class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">
          {{ tip.text }}
        </span>
      </div>
    </div>
  </PeriodInfoCard>
</template>
