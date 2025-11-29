<script setup lang="ts">
import { ArrowLeft, RefreshCw } from 'lucide-vue-next';
import { useRouter } from 'vue-router';
import Button from '@/components/ui/Button.vue';
import { useBudgetStats } from '@/composables/useBudgetStats';
import BudgetStatsAnalysis from '@/features/money/components/BudgetStatsAnalysis.vue';

const { t } = useI18n();
const router = useRouter();

// 页面标题
const pageTitle = ref(t('financial.budget.stats'));

// 使用预算统计 composable
const {
  state,
  loadAllStats,
  refresh,
} = useBudgetStats();

// 回退到上一个页面
function goBack() {
  if (window.history.length > 1) {
    window.history.back();
  } else {
    // 如果没有历史记录，跳转到预算列表页面
    router.push('/money');
  }
}

// 页面加载时自动加载数据
onMounted(async () => {
  await loadAllStats();
});

// 页面销毁时清理
onUnmounted(() => {
  // 清理可能的定时器或监听器
});
</script>

<template>
  <div class="max-w-7xl mx-auto p-4 sm:p-6 lg:p-8">
    <!-- 页面头部 -->
    <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 mb-6">
      <div class="flex-1 min-w-0">
        <h1 class="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white mb-2 truncate">
          {{ pageTitle }}
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          {{ t('financial.budget.statsDescription') }}
        </p>
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <Button
          variant="primary"
          size="sm"
          circle
          :disabled="state.loading"
          :title="t('common.actions.refresh')"
          @click="refresh"
        >
          <RefreshCw
            class="w-4 h-4"
            :class="{ 'animate-spin': state.loading }"
          />
        </Button>
        <Button
          variant="secondary"
          size="sm"
          :title="t('common.actions.back')"
          @click="goBack"
        >
          <ArrowLeft class="w-4 h-4 sm:mr-1" />
          <span class="hidden sm:inline">{{ t('common.actions.back') }}</span>
        </Button>
      </div>
    </div>

    <!-- 错误状态 -->
    <div v-if="state.error" class="flex flex-col items-center justify-center py-12 sm:py-16 px-4 bg-red-50 dark:bg-red-900/10 border border-red-200 dark:border-red-800 rounded-xl mb-4">
      <div class="text-5xl sm:text-6xl mb-4 text-red-500">
        !
      </div>
      <div class="text-base sm:text-lg text-red-600 dark:text-red-400 mb-4 text-center">
        {{ state.error }}
      </div>
      <Button variant="danger" size="md" @click="refresh">
        {{ t('common.actions.retry') }}
      </Button>
    </div>

    <!-- 统计分析组件 -->
    <BudgetStatsAnalysis />
  </div>
</template>
