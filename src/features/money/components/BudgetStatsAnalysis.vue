<script setup lang="ts">
import { ArrowLeft, BarChart3, PieChart, TrendingUp } from 'lucide-vue-next';
import VChart from 'vue-echarts';
import { useRouter } from 'vue-router';
import { useBudgetStats } from '@/composables/useBudgetStats';
import { initECharts } from '@/utils/echarts';

const { t } = useI18n();
const router = useRouter();

// 使用预算统计 composable
const {
  state,
  filters,
  hasData,
  isHealthy,
  needsAttention,
  loadAllStats,
  resetFilters,
} = useBudgetStats();

// 显示状态
const showFilters = ref(false);
const showStats = ref(false);

// 初始化ECharts
initECharts();

// 图表类型切换
const chartType = ref<'trend' | 'category' | 'overview'>('trend');
const trendChartType = ref<'line' | 'bar' | 'area'>('line');
const categoryChartType = ref<'pie' | 'bar' | 'radar'>('pie');

// 图表唯一标识，用于强制重新创建实例
const chartKey = computed(() => `${chartType.value}-${trendChartType.value}-${categoryChartType.value}`);

// 图表实例引用
const chartRef = ref();

// 确保图表在下一个 tick 中正确渲染
async function ensureChartRender() {
  await nextTick();
  // 等待 DOM 更新完成
  await new Promise(resolve => setTimeout(resolve, 100));
  if (chartRef.value) {
    try {
      // 检查容器是否有有效尺寸
      const container = chartRef.value.$el;
      if (container && container.clientWidth > 0 && container.clientHeight > 0) {
        chartRef.value.resize();
      } else {
        // 如果容器尺寸为0，延迟重试
        setTimeout(() => {
          if (chartRef.value) {
            chartRef.value.resize();
          }
        }, 200);
      }
    } catch (error) {
      console.warn('图表渲染失败:', error);
    }
  }
}

// 监听数据变化，确保图表正确渲染
watch(
  [() => state.value.trends, () => state.value.categoryStats, () => chartType.value],
  async () => {
    if (hasData.value && !state.value.loading) {
      await ensureChartRender();
    }
  },
  { deep: true },
);

// 组件销毁时清理
onUnmounted(() => {
  // 清理可能的定时器或监听器
});

// 计算属性
const statusColor = computed(() => {
  if (needsAttention.value) return 'text-red-500';
  if (isHealthy.value) return 'text-green-500';
  return 'text-gray-500';
});

const statusText = computed(() => {
  if (needsAttention.value) return '需要关注';
  if (isHealthy.value) return '健康';
  return '未知';
});

const statusIcon = computed(() => {
  if (needsAttention.value) return '!';
  if (isHealthy.value) return '✅';
  return '❓';
});

// 方法
function toggleFilters() {
  showFilters.value = !showFilters.value;
};

function handleResetFilters() {
  resetFilters();
};

// 监听筛选条件变化
watch(filters, () => {
  if (showStats.value) {
    loadAllStats();
  }
}, { deep: true });

// 格式化货币
function formatCurrency(amount: number) {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: 'CNY',
  }).format(amount);
}

// 格式化百分比
function formatPercentage(value: number) {
  return `${value.toFixed(1)}%`;
}

// 跳转到预算列表页面
function goToBudgetList() {
  router.push('/money');
}

// 回退到上一个页面
function goBack() {
  if (window.history.length > 1) {
    window.history.back();
  } else {
    // 如果没有历史记录，跳转到预算列表页面
    router.push('/money');
  }
}

// 创建测试数据
async function createTestData() {
  try {
    // 这里可以调用后端 API 创建测试预算数据
    // 创建完成后刷新数据
    await loadAllStats();
  } catch (error) {
    console.error('创建测试数据失败:', error);
    // eslint-disable-next-line no-alert
    alert('创建测试数据失败，请手动创建预算数据。');
  }
}

// 图表配置
const trendChartOption = computed(() => {
  if (!state.value.trends.length) {
    return {
      title: {
        text: '暂无趋势数据',
        left: 'center',
        top: 'middle',
        textStyle: {
          color: '#999',
          fontSize: 16,
        },
      },
    };
  }

  const periods = state.value.trends.map(item => item.period);
  const totalBudgets = state.value.trends.map(item => item.totalBudget);
  const usedAmounts = state.value.trends.map(item => item.usedAmount);
  const remainingAmounts = state.value.trends.map(item => item.remainingAmount);

  const baseOption = {
    title: {
      text: '预算趋势分析',
      left: 'center',
      textStyle: {
        fontSize: 16,
        fontWeight: 'bold',
      },
    },
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'cross',
      },
    },
    legend: {
      data: ['总预算', '已使用', '剩余'],
      top: 30,
    },
    xAxis: {
      type: 'category',
      data: periods,
      axisLabel: {
        rotate: 45,
      },
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: '¥{value}',
      },
    },
    series: [
      {
        name: '总预算',
        type: trendChartType.value,
        data: totalBudgets,
        itemStyle: { color: '#3b82f6' },
        areaStyle: trendChartType.value === 'area' ? { opacity: 0.3 } : undefined,
      },
      {
        name: '已使用',
        type: trendChartType.value,
        data: usedAmounts,
        itemStyle: { color: '#ef4444' },
        areaStyle: trendChartType.value === 'area' ? { opacity: 0.3 } : undefined,
      },
      {
        name: '剩余',
        type: trendChartType.value,
        data: remainingAmounts,
        itemStyle: { color: '#10b981' },
        areaStyle: trendChartType.value === 'area' ? { opacity: 0.3 } : undefined,
      },
    ],
  };

  return baseOption;
});

const categoryChartOption = computed(() => {
  if (!state.value.categoryStats.length) {
    return {
      title: {
        text: '暂无分类数据',
        left: 'center',
        top: 'middle',
        textStyle: {
          color: '#999',
          fontSize: 16,
        },
      },
    };
  }

  const categories = state.value.categoryStats.map(item => item.category);
  const budgets = state.value.categoryStats.map(item => item.totalBudget);
  const usedAmounts = state.value.categoryStats.map(item => item.usedAmount);

  if (categoryChartType.value === 'pie') {
    return {
      title: {
        text: '预算分类分析',
        left: 'center',
        textStyle: {
          fontSize: 16,
          fontWeight: 'bold',
        },
      },
      tooltip: {
        trigger: 'item',
        formatter: '{a} <br/>{b}: ¥{c} ({d}%)',
      },
      series: [
        {
          name: '预算金额',
          type: 'pie',
          radius: '50%',
          data: categories.map((category, index) => ({
            value: budgets[index],
            name: category,
          })),
          emphasis: {
            itemStyle: {
              shadowBlur: 10,
              shadowOffsetX: 0,
              shadowColor: 'rgba(0, 0, 0, 0.5)',
            },
          },
        },
      ],
    };
  }

  return {
    title: {
      text: '预算分类分析',
      left: 'center',
      textStyle: {
        fontSize: 16,
        fontWeight: 'bold',
      },
    },
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow',
      },
    },
    xAxis: {
      type: 'category',
      data: categories,
      axisLabel: {
        rotate: 45,
      },
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: '¥{value}',
      },
    },
    series: [
      {
        name: '总预算',
        type: categoryChartType.value === 'radar' ? 'radar' : 'bar',
        data: budgets,
        itemStyle: { color: '#3b82f6' },
      },
      {
        name: '已使用',
        type: categoryChartType.value === 'radar' ? 'radar' : 'bar',
        data: usedAmounts,
        itemStyle: { color: '#ef4444' },
      },
    ],
  };
});

const currentChartOption = computed(() => {
  switch (chartType.value) {
    case 'trend':
      return trendChartOption.value;
    case 'category':
      return categoryChartOption.value;
    default:
      return trendChartOption.value;
  }
});
</script>

<template>
  <div class="budget-stats-container">
    <!-- 页面头部 -->
    <div class="page-header">
      <button class="back-button" :title="t('common.actions.back')" @click="goBack">
        <ArrowLeft class="w-4 h-4 mr-1" />
        返回
      </button>
      <h2 class="page-title">
        预算统计分析
      </h2>
    </div>

    <!-- 加载状态 -->
    <div v-if="state.loading" class="loading-container">
      <div class="loading-spinner" />
      <div class="loading-text">
        加载统计数据中...
      </div>
    </div>

    <!-- 空状态 -->
    <div v-else-if="!hasData" class="empty-state">
      <div class="empty-icon">
        📊
      </div>
      <div class="empty-text">
        暂无统计数据
      </div>
      <div class="empty-description">
        <p>
          系统中还没有预算数据，无法进行统计分析。
        </p>
        <p>
          请先创建一些预算，然后再查看统计结果。
        </p>
      </div>
      <div class="debug-info">
        <p>
          调试信息:
        </p>
        <p>
          Loading: {{ state.loading }}
        </p>
        <p>
          Has Data: {{ hasData }}
        </p>
        <p>
          Overview: {{ state.overview ? `有数据 (${state.overview.budgetCount} 个预算)` : '无数据' }}
        </p>
        <p>
          Error: {{ state.error || '无错误' }}
        </p>
      </div>
      <div class="empty-actions">
        <button class="empty-button primary" @click="goToBudgetList">
          去创建预算
        </button>
        <button class="empty-button secondary" @click="loadAllStats">
          刷新数据
        </button>
        <button class="empty-button test" @click="createTestData">
          创建测试数据
        </button>
      </div>
    </div>

    <!-- 统计概览卡片 -->
    <div v-if="state.overview" class="stats-overview">
      <div class="stats-grid">
        <!-- 总预算 -->
        <div class="stat-card">
          <div class="stat-icon">
            <PieChart class="w-6 h-6 text-blue-500" />
          </div>
          <div class="stat-content">
            <div class="stat-label">
              总预算
            </div>
            <div class="stat-value">
              {{ formatCurrency(state.overview.totalBudgetAmount) }}
            </div>
          </div>
        </div>

        <!-- 已使用 -->
        <div class="stat-card">
          <div class="stat-icon">
            <TrendingUp class="w-6 h-6 text-green-500" />
          </div>
          <div class="stat-content">
            <div class="stat-label">
              已使用
            </div>
            <div class="stat-value">
              {{ formatCurrency(state.overview.usedAmount) }}
            </div>
          </div>
        </div>

        <!-- 剩余金额 -->
        <div class="stat-card">
          <div class="stat-icon">
            <BarChart3 class="w-6 h-6 text-orange-500" />
          </div>
          <div class="stat-content">
            <div class="stat-label">
              剩余金额
            </div>
            <div class="stat-value">
              {{ formatCurrency(state.overview.remainingAmount) }}
            </div>
          </div>
        </div>

        <!-- 完成率 -->
        <div class="stat-card">
          <div class="stat-icon">
            <div class="w-6 h-6 flex items-center justify-center">
              <span class="text-lg">{{ statusIcon }}</span>
            </div>
          </div>
          <div class="stat-content">
            <div class="stat-label">
              完成率
            </div>
            <div class="stat-value" :class="statusColor">
              {{ formatPercentage(state.overview.completionRate) }}
            </div>
            <div class="stat-status" :class="statusColor">
              {{ statusText }}
            </div>
          </div>
        </div>

        <!-- 预算数量 -->
        <div class="stat-card">
          <div class="stat-icon">
            <div class="w-6 h-6 flex items-center justify-center">
              <span class="text-lg">📊</span>
            </div>
          </div>
          <div class="stat-content">
            <div class="stat-label">
              预算数量
            </div>
            <div class="stat-value">
              {{ state.overview.budgetCount }}
            </div>
          </div>
        </div>

        <!-- 超预算数量 -->
        <div v-if="state.overview.overBudgetCount > 0" class="stat-card warning">
          <div class="stat-icon">
            <div class="w-6 h-6 flex items-center justify-center">
              <span class="text-lg">!</span>
            </div>
          </div>
          <div class="stat-content">
            <div class="stat-label">
              超预算
            </div>
            <div class="stat-value text-red-500">
              {{ state.overview.overBudgetCount }}
            </div>
            <div class="stat-status text-red-500">
              超预算金额: {{ formatCurrency(state.overview.overBudgetAmount) }}
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 筛选器 -->
    <div v-if="showFilters" class="filters-section">
      <div class="filters-header">
        <h3 class="filters-title">
          筛选条件
        </h3>
        <button
          class="close-button"
          @click="toggleFilters"
        >
          ✕
        </button>
      </div>
      <div class="filters-content">
        <div class="filter-row">
          <label class="filter-label">
            基础货币
          </label>
          <select
            v-model="filters.baseCurrency"
            class="filter-select"
          >
            <option value="CNY">
              人民币 (CNY)
            </option>
            <option value="USD">
              美元 (USD)
            </option>
            <option value="EUR">
              欧元 (EUR)
            </option>
            <option value="JPY">
              日元 (JPY)
            </option>
          </select>
        </div>

        <div class="filter-row">
          <label class="filter-label">计算日期</label>
          <input
            v-model="filters.calculationDate"
            type="date"
            class="filter-input"
          >
        </div>

        <div class="filter-row">
          <label class="filter-label">
            <input
              v-model="filters.includeInactive"
              type="checkbox"
              class="filter-checkbox"
            >
            包含非激活预算
          </label>
        </div>

        <div class="filter-row">
          <label class="filter-label">时间范围</label>
          <div class="date-range">
            <input
              v-model="filters.timeRange.startDate"
              type="date"
              class="filter-input"
            >
            <span class="date-separator">至</span>
            <input
              v-model="filters.timeRange.endDate"
              type="date"
              class="filter-input"
            >
          </div>
        </div>

        <div class="filter-row">
          <label class="filter-label">时间维度</label>
          <select
            v-model="filters.period"
            class="filter-select"
          >
            <option value="month">
              按月
            </option>
            <option value="week">
              按周
            </option>
          </select>
        </div>

        <div class="filter-actions">
          <button
            class="filter-button secondary"
            @click="handleResetFilters"
          >
            重置
          </button>
          <button
            class="filter-button primary"
            @click="toggleFilters"
          >
            应用
          </button>
        </div>
      </div>
    </div>

    <div v-if="state.error" class="error-message">
      <div class="error-icon">
        !
      </div>
      <div class="error-text">
        {{ state.error }}
      </div>
    </div>

    <!-- 图表区域 -->
    <div v-if="hasData" class="charts-section">
      <div class="charts-header">
        <h3>
          图表分析
        </h3>
        <div class="chart-controls">
          <button
            class="control-button"
            :class="{ active: chartType === 'trend' }"
            @click="chartType = 'trend'"
          >
            <TrendingUp class="w-4 h-4 mr-1" />
            趋势分析
          </button>
          <button
            class="control-button"
            :class="{ active: chartType === 'category' }"
            @click="chartType = 'category'"
          >
            <PieChart class="w-4 h-4 mr-1" />
            分类分析
          </button>
        </div>
      </div>

      <!-- 图表容器 -->
      <div class="chart-container">
        <VChart
          v-if="!state.loading && hasData"
          ref="chartRef"
          :key="chartKey"
          :option="currentChartOption"
          class="chart"
          autoresize
          :loading="false"
          @finished="ensureChartRender"
        />
        <div v-else-if="state.loading" class="loading-container">
          <div class="loading-spinner" />
          <div class="loading-text">
            加载中...
          </div>
        </div>
        <div v-else class="empty-chart">
          <div class="empty-chart-text">
            暂无图表数据
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.budget-stats-container {
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

.page-header {
  display: flex;
  align-items: center;
  padding: 16px 20px;
  border-bottom: 1px solid #f0f0f0;
  background: #fafafa;
}

.back-button {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  background: #f5f5f5;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  font-size: 14px;
  color: #666;
  cursor: pointer;
  transition: all 0.2s;
  margin-right: 16px;
}

.back-button:hover {
  background: #e6f7ff;
  border-color: #40a9ff;
  color: #1890ff;
}

.page-title {
  font-size: 20px;
  font-weight: 600;
  color: #333;
  margin: 0;
}

.stats-overview {
  padding: 16px;
  border-bottom: 1px solid #f0f0f0;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
}

.stat-card {
  display: flex;
  align-items: center;
  padding: 16px;
  background: #fafafa;
  border-radius: 8px;
  border: 1px solid #e0e0e0;
  transition: all 0.2s;
}

.stat-card:hover {
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.stat-card.warning {
  background: #fff2f0;
  border-color: #ffccc7;
}

.stat-icon {
  margin-right: 12px;
  flex-shrink: 0;
}

.stat-content {
  flex: 1;
}

.stat-label {
  font-size: 12px;
  color: #666;
  margin-bottom: 4px;
}

.stat-value {
  font-size: 18px;
  font-weight: bold;
  color: #333;
  margin-bottom: 2px;
}

.stat-status {
  font-size: 11px;
  font-weight: 500;
}

.filters-section {
  border-bottom: 1px solid #f0f0f0;
}

.filters-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  background: #fafafa;
  border-bottom: 1px solid #e0e0e0;
}

.filters-title {
  font-size: 16px;
  font-weight: bold;
  margin: 0;
}

.close-button {
  background: none;
  border: none;
  font-size: 18px;
  cursor: pointer;
  color: #666;
  padding: 4px;
  border-radius: 4px;
}

.close-button:hover {
  background: #e0e0e0;
}

.filters-content {
  padding: 16px;
}

.filter-row {
  display: flex;
  align-items: center;
  margin-bottom: 16px;
}

.filter-label {
  width: 100px;
  font-size: 14px;
  color: #333;
  margin-right: 12px;
  flex-shrink: 0;
}

.filter-select,
.filter-input {
  flex: 1;
  padding: 8px 12px;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  font-size: 14px;
}

.filter-checkbox {
  margin-right: 8px;
}

.date-range {
  display: flex;
  align-items: center;
  flex: 1;
  gap: 8px;
}

.date-separator {
  color: #666;
  font-size: 14px;
}

.filter-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  margin-top: 16px;
}

.filter-button {
  padding: 8px 16px;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s;
}

.filter-button.primary {
  background: #1890ff;
  color: white;
  border: 1px solid #1890ff;
}

.filter-button.primary:hover {
  background: #40a9ff;
}

.filter-button.secondary {
  background: white;
  color: #666;
  border: 1px solid #d9d9d9;
}

.filter-button.secondary:hover {
  background: #f5f5f5;
}

.charts-section {
  padding: 16px;
}

.charts-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}

.charts-title {
  font-size: 16px;
  font-weight: bold;
  margin: 0;
}

.charts-actions {
  display: flex;
  gap: 8px;
}

.action-button {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 6px 12px;
  background: white;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s;
}

.action-button:hover {
  background: #f5f5f5;
}

.action-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.error-message {
  display: flex;
  align-items: center;
  padding: 16px;
  background: #fff2f0;
  border: 1px solid #ffccc7;
  border-radius: 4px;
  margin-bottom: 16px;
}

.error-icon {
  margin-right: 8px;
  font-size: 16px;
}

.error-text {
  color: #ff4d4f;
  font-size: 14px;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  color: #999;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-text {
  font-size: 16px;
  margin-bottom: 16px;
}

.empty-button {
  padding: 8px 16px;
  background: #1890ff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.empty-button:hover {
  background: #40a9ff;
}

.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  color: #999;
}

.loading-spinner {
  width: 32px;
  height: 32px;
  border: 3px solid #f3f3f3;
  border-top: 3px solid #1890ff;
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 8px;
}

.loading-text {
  font-size: 14px;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px;
  color: #999;
}

.empty-icon {
  font-size: 48px;
  margin-bottom: 16px;
}

.empty-text {
  font-size: 16px;
  margin-bottom: 8px;
  font-weight: 500;
}

.empty-description {
  font-size: 14px;
  margin-bottom: 16px;
  text-align: center;
  max-width: 400px;
}

.empty-description p {
  margin: 4px 0;
}

.empty-actions {
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}

.empty-button.primary {
  padding: 10px 20px;
  background: #1890ff;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.empty-button.primary:hover {
  background: #40a9ff;
}

.empty-button.secondary {
  padding: 10px 20px;
  background: white;
  color: #666;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.empty-button.secondary:hover {
  background: #f5f5f5;
  border-color: #40a9ff;
  color: #40a9ff;
}

.empty-button.test {
  padding: 10px 20px;
  background: #52c41a;
  color: white;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.empty-button.test:hover {
  background: #73d13d;
}

.debug-info {
  background: #f5f5f5;
  border: 1px solid #e0e0e0;
  border-radius: 4px;
  padding: 12px;
  margin: 16px 0;
  font-size: 12px;
  color: #666;
  text-align: left;
  max-width: 300px;
}

.debug-info p {
  margin: 4px 0;
}

.empty-button {
  padding: 8px 16px;
  background: #1890ff;
  color: white;
  border: none;
  border-radius: 4px;
  font-size: 14px;
  cursor: pointer;
}

.empty-button:hover {
  background: #40a9ff;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

/* 图表区域样式 */
.charts-section {
  margin-top: 24px;
  background: white;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.charts-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  flex-wrap: wrap;
  gap: 16px;
}

.charts-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: #333;
  margin: 0;
}

.chart-controls {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.control-button {
  display: flex;
  align-items: center;
  padding: 8px 16px;
  background: #f5f5f5;
  border: 1px solid #d9d9d9;
  border-radius: 6px;
  font-size: 14px;
  color: #666;
  cursor: pointer;
  transition: all 0.2s;
}

.control-button:hover {
  background: #e6f7ff;
  border-color: #40a9ff;
  color: #1890ff;
}

.control-button.active {
  background: #1890ff;
  border-color: #1890ff;
  color: white;
}

.chart-container {
  width: 100%;
  height: 400px;
  position: relative;
}

.chart {
  width: 100%;
  height: 100%;
}

.empty-chart {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #999;
}

.empty-chart-text {
  font-size: 14px;
}

@media (max-width: 768px) {
  .stats-grid {
    grid-template-columns: 1fr;
  }
  .filter-row {
    flex-direction: column;
    align-items: stretch;
  }
  .filter-label {
    width: auto;
    margin-bottom: 8px;
    margin-right: 0;
  }
  .date-range {
    flex-direction: column;
    align-items: stretch;
  }
  .date-separator {
    text-align: center;
  }
}
</style>
