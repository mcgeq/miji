<script setup lang="ts">
import { Heart } from 'lucide-vue-next';
import type { PeriodStats } from '@/schema/health/period';

interface Props {
  stats: PeriodStats;
}
const props = defineProps<Props>();

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
  const phase = props.stats.currentPhase;
  if (phase === 'Menstrual') {
    return [
      { id: 1, icon: 'i-tabler-cup', text: '多喝温水，避免冷饮' },
      { id: 2, icon: 'i-tabler-bed', text: '充分休息，避免剧烈运动' },
      { id: 3, icon: 'i-tabler-flame', text: '注意保暖，特别是腹部' },
    ];
  }

  return tips.slice(0, 3);
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
