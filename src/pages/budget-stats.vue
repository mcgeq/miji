<script setup lang="ts">
import { useBudgetStats } from '@/composables/useBudgetStats';
import BudgetStatsAnalysis from '@/features/money/components/BudgetStatsAnalysis.vue';

const { t } = useI18n();

// 页面标题
const pageTitle = ref(t('financial.budget.stats'));

// 使用预算统计 composable
const {
  state,
  loadAllStats,
  refresh,
} = useBudgetStats();

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
  <div class="budget-stats-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="page-title">
        <h1>{{ pageTitle }}</h1>
        <p class="page-description">
          {{ t('financial.budget.statsDescription') }}
        </p>
      </div>
      <div class="page-actions">
        <button
          class="refresh-button"
          :disabled="state.loading"
          @click="refresh"
        >
          <span v-if="state.loading">加载中...</span>
          <span v-else>刷新数据</span>
        </button>
      </div>
    </div>

    <!-- 错误状态 -->
    <div v-if="state.error" class="error-container">
      <div class="error-icon">
        !
      </div>
      <div class="error-message">
        {{ state.error }}
      </div>
      <button class="retry-button" @click="refresh">
        重试
      </button>
    </div>

    <!-- 统计分析组件 -->
    <BudgetStatsAnalysis />
  </div>
</template>

<style scoped>
.budget-stats-page {
  padding: 20px;
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  margin-bottom: 24px;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  flex-wrap: wrap;
  gap: 16px;
}

.page-title h1 {
  font-size: 24px;
  font-weight: bold;
  color: #333;
  margin: 0 0 8px 0;
}

.page-description {
  color: #666;
  font-size: 14px;
  margin: 0;
}

.page-actions {
  display: flex;
  gap: 8px;
}

.refresh-button {
  padding: 8px 16px;
  background: #1890ff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s;
}

.refresh-button:hover {
  background: #40a9ff;
}

.refresh-button:disabled {
  background: #d9d9d9;
  cursor: not-allowed;
}

.error-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  background: #fff2f0;
  border: 1px solid #ffccc7;
  border-radius: 8px;
  margin-bottom: 16px;
}

.error-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.error-message {
  color: #ff4d4f;
  font-size: 16px;
  margin-bottom: 16px;
  text-align: center;
}

.retry-button {
  padding: 8px 16px;
  background: #ff4d4f;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.retry-button:hover {
  background: #ff7875;
}

@media (max-width: 768px) {
  .budget-stats-page {
    padding: 16px;
  }
  .page-title h1 {
    font-size: 20px;
  }
}
</style>
