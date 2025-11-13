<script setup lang="ts">
// 简化的支出分析图表组件
interface ExpenseData {
  category: string;
  amount: number;
  color?: string;
}

interface Props {
  data: ExpenseData[];
  title?: string;
  height?: string;
}

const props = withDefaults(defineProps<Props>(), {
  title: '支出分析',
  height: '300px',
});

// 计算总金额
const totalAmount = computed(() =>
  props.data.reduce((sum, item) => sum + item.amount, 0),
);

// 计算百分比
const chartData = computed(() =>
  props.data.map(item => ({
    ...item,
    percentage: totalAmount.value > 0 ? (item.amount / totalAmount.value) * 100 : 0,
  })),
);

// 预设颜色
const defaultColors = [
  '#3b82f6',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#06b6d4',
  '#84cc16',
  '#f97316',
];

// 格式化金额
function formatAmount(amount: number): string {
  return amount.toFixed(2);
}
</script>

<template>
  <div class="expense-chart" :style="{ height }">
    <h4 v-if="title" class="chart-title">
      {{ title }}
    </h4>

    <div class="chart-container">
      <!-- 饼图可视化 -->
      <div class="pie-chart">
        <svg viewBox="0 0 200 200" class="pie-svg">
          <g transform="translate(100,100)">
            <circle
              v-for="(item, index) in chartData"
              :key="item.category"
              :r="80"
              :stroke="item.color || defaultColors[index % defaultColors.length]"
              :stroke-width="20"
              :stroke-dasharray="`${item.percentage * 5.03} 502`"
              :stroke-dashoffset="`${-chartData.slice(0, index).reduce((sum, prev) => sum + prev.percentage, 0) * 5.03}`"
              fill="none"
              class="pie-segment"
            />
          </g>

          <!-- 中心文字 -->
          <text x="100" y="95" text-anchor="middle" class="center-text-label">总支出</text>
          <text x="100" y="115" text-anchor="middle" class="center-text-value">
            ¥{{ formatAmount(totalAmount) }}
          </text>
        </svg>
      </div>

      <!-- 图例 -->
      <div class="chart-legend">
        <div
          v-for="(item, index) in chartData"
          :key="item.category"
          class="legend-item"
        >
          <div
            class="legend-color"
            :style="{ backgroundColor: item.color || defaultColors[index % defaultColors.length] }"
          />
          <div class="legend-content">
            <div class="legend-label">
              {{ item.category }}
            </div>
            <div class="legend-value">
              ¥{{ formatAmount(item.amount) }}
              <span class="legend-percentage">({{ item.percentage.toFixed(1) }}%)</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-if="data.length === 0" class="empty-state">
      <LucidePieChart class="empty-icon" />
      <p class="empty-text">
        暂无数据
      </p>
    </div>
  </div>
</template>

<style scoped>
.expense-chart {
  background: white;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
  padding: 1rem;
}

.chart-title {
  font-size: 1rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 1rem;
  text-align: center;
}

.chart-container {
  display: flex;
  align-items: center;
  gap: 2rem;
  height: calc(100% - 3rem);
}

.pie-chart {
  flex: 0 0 200px;
  height: 200px;
}

.pie-svg {
  width: 100%;
  height: 100%;
}

.pie-segment {
  transition: stroke-width 0.3s ease;
}

.pie-segment:hover {
  stroke-width: 25;
}

.center-text-label {
  font-size: 12px;
  fill: #6b7280;
}

.center-text-value {
  font-size: 14px;
  font-weight: 600;
  fill: #1f2937;
}

.chart-legend {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  max-height: 200px;
  overflow-y: auto;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.5rem;
  border-radius: 0.375rem;
  transition: background-color 0.2s;
}

.legend-item:hover {
  background-color: #f9fafb;
}

.legend-color {
  width: 1rem;
  height: 1rem;
  border-radius: 0.25rem;
  flex-shrink: 0;
}

.legend-content {
  flex: 1;
}

.legend-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
  margin-bottom: 0.125rem;
}

.legend-value {
  font-size: 0.75rem;
  color: #6b7280;
}

.legend-percentage {
  color: #9ca3af;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #9ca3af;
}

.empty-icon {
  width: 2rem;
  height: 2rem;
  margin-bottom: 0.5rem;
}

.empty-text {
  font-size: 0.875rem;
}

/* 响应式设计 */
@media (max-width: 640px) {
  .chart-container {
    flex-direction: column;
    gap: 1rem;
  }

  .pie-chart {
    flex: none;
  }

  .chart-legend {
    max-height: none;
  }
}
</style>
