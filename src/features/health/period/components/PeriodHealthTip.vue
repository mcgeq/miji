<script setup lang="ts">
import { Heart } from 'lucide-vue-next';
import Card from '@/components/ui/Card.vue';
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
  <Card shadow="sm" padding="md" class="overflow-hidden border-l-4 border-l-green-500 dark:border-l-green-400">
    <!-- 自定义头部 -->
    <template #header>
      <div class="flex items-center gap-2">
        <!-- 图标容器 -->
        <div
          class="flex items-center justify-center w-10 h-10 rounded-full bg-gradient-to-r from-green-500 to-green-600 shadow-sm"
        >
          <Heart class="w-5 h-5 text-white" />
        </div>

        <!-- 标题 -->
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          健康建议
        </h3>
      </div>
    </template>

    <!-- 建议列表 -->
    <div class="flex flex-col gap-2">
      <div
        v-for="tip in healthTips"
        :key="tip.id"
        class="flex items-center gap-3 p-3 rounded-lg bg-gray-50 dark:bg-gray-700/50 transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-700"
      >
        <!-- 提示图标 -->
        <component
          :is="tip.icon"
          class="w-5 h-5 flex-shrink-0 text-blue-600 dark:text-blue-400"
        />

        <!-- 提示文本 -->
        <span class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">
          {{ tip.text }}
        </span>
      </div>
    </div>
  </Card>
</template>
