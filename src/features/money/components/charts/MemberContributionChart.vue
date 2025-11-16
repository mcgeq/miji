<script setup lang="ts">
// 成员贡献度图表组件
interface MemberData {
  name: string;
  totalPaid: number;
  totalOwed: number;
  netBalance: number;
  color?: string;
}

interface Props {
  data: MemberData[];
  title?: string;
  height?: string;
}

const props = withDefaults(defineProps<Props>(), {
  title: '成员贡献度',
  height: '400px',
});

// 计算总支付金额
const totalPaid = computed(() =>
  props.data.reduce((sum, member) => sum + member.totalPaid, 0),
);

// 计算图表数据
const chartData = computed(() =>
  props.data.map((member, index) => ({
    ...member,
    percentage: totalPaid.value > 0 ? (member.totalPaid / totalPaid.value) * 100 : 0,
    color: member.color || getDefaultColor(index),
  })).sort((a, b) => b.totalPaid - a.totalPaid),
);

// 预设颜色
const colors = [
  '#3b82f6',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#06b6d4',
  '#84cc16',
  '#f97316',
];

function getDefaultColor(index: number): string {
  return colors[index % colors.length];
}

// 格式化金额
function formatAmount(amount: number | undefined | null): string {
  if (amount === undefined || amount === null || Number.isNaN(amount)) {
    return '0.00';
  }
  return amount.toFixed(2);
}

// 获取余额状态样式
function getBalanceClass(balance: number): string {
  if (balance > 0) return 'positive';
  if (balance < 0) return 'negative';
  return 'neutral';
}
</script>

<template>
  <div class="contribution-chart" :style="{ height }">
    <h4 v-if="title" class="chart-title">
      {{ title }}
    </h4>

    <div class="chart-content">
      <!-- 柱状图 -->
      <div class="bar-chart">
        <div class="chart-grid">
          <!-- Y轴标签 -->
          <div class="y-axis">
            <div class="y-label">
              支付金额 (¥)
            </div>
            <div class="y-scale">
              <div v-for="i in 5" :key="i" class="scale-line">
                <span class="scale-value">{{ formatAmount(totalPaid * (5 - i + 1) / 5) }}</span>
              </div>
            </div>
          </div>

          <!-- 图表区域 -->
          <div class="chart-area">
            <div class="bars-container">
              <div
                v-for="member in chartData"
                :key="member.name"
                class="bar-group"
              >
                <!-- 支付金额柱 -->
                <div class="bar-wrapper">
                  <div
                    class="bar paid-bar"
                    :style="{
                      height: `${member.percentage}%`,
                      backgroundColor: member.color,
                    }"
                  >
                    <div class="bar-tooltip">
                      <div class="tooltip-title">
                        {{ member.name }}
                      </div>
                      <div class="tooltip-item">
                        <span>支付: ¥{{ formatAmount(member.totalPaid) }}</span>
                      </div>
                      <div class="tooltip-item">
                        <span>应分摊: ¥{{ formatAmount(member.totalOwed) }}</span>
                      </div>
                      <div class="tooltip-item" :class="getBalanceClass(member.netBalance)">
                        <span>净余额: ¥{{ formatAmount(Math.abs(member.netBalance)) }}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- X轴标签 -->
                <div class="x-label">
                  {{ member.name }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 统计信息 -->
      <div class="stats-panel">
        <div class="stats-header">
          <h5 class="stats-title">
            详细统计
          </h5>
        </div>

        <div class="stats-list">
          <div
            v-for="member in chartData"
            :key="member.name"
            class="stats-item"
          >
            <div class="member-info">
              <div class="member-indicator" :style="{ backgroundColor: member.color }" />
              <span class="member-name">{{ member.name }}</span>
            </div>

            <div class="member-stats">
              <div class="stat-row">
                <span class="stat-label">支付金额:</span>
                <span class="stat-value">¥{{ formatAmount(member.totalPaid) }}</span>
              </div>
              <div class="stat-row">
                <span class="stat-label">应分摊:</span>
                <span class="stat-value">¥{{ formatAmount(member.totalOwed) }}</span>
              </div>
              <div class="stat-row">
                <span class="stat-label">净余额:</span>
                <span class="stat-value" :class="getBalanceClass(member.netBalance)">
                  <span v-if="member.netBalance > 0">+</span>
                  <span v-else-if="member.netBalance < 0">-</span>
                  ¥{{ formatAmount(Math.abs(member.netBalance)) }}
                </span>
              </div>
              <div class="stat-row">
                <span class="stat-label">贡献度:</span>
                <span class="stat-value">{{ member.percentage.toFixed(1) }}%</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-if="data.length === 0" class="empty-state">
      <LucideBarChart3 class="empty-icon" />
      <p class="empty-text">
        暂无数据
      </p>
    </div>
  </div>
</template>

<style scoped>
.contribution-chart {
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

.chart-content {
  display: flex;
  gap: 1.5rem;
  height: calc(100% - 3rem);
}

.bar-chart {
  flex: 2;
  min-height: 0;
}

.chart-grid {
  display: flex;
  height: 100%;
}

.y-axis {
  display: flex;
  flex-direction: column;
  width: 80px;
  margin-right: 1rem;
}

.y-label {
  font-size: 0.75rem;
  color: #6b7280;
  text-align: center;
  margin-bottom: 0.5rem;
  writing-mode: vertical-rl;
  text-orientation: mixed;
}

.y-scale {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  position: relative;
}

.scale-line {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  position: relative;
}

.scale-line::after {
  content: '';
  position: absolute;
  right: -8px;
  width: 4px;
  height: 1px;
  background-color: #d1d5db;
}

.scale-value {
  font-size: 0.75rem;
  color: #6b7280;
  margin-right: 0.5rem;
}

.chart-area {
  flex: 1;
  position: relative;
  border-left: 1px solid #e5e7eb;
  border-bottom: 1px solid #e5e7eb;
}

.bars-container {
  display: flex;
  align-items: flex-end;
  justify-content: space-around;
  height: calc(100% - 2rem);
  padding: 1rem 0.5rem 0;
}

.bar-group {
  display: flex;
  flex-direction: column;
  align-items: center;
  flex: 1;
  max-width: 80px;
}

.bar-wrapper {
  position: relative;
  width: 100%;
  height: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.bar {
  width: 60%;
  min-height: 4px;
  border-radius: 4px 4px 0 0;
  position: relative;
  transition: all 0.3s ease;
  cursor: pointer;
}

.bar:hover {
  opacity: 0.8;
  transform: scaleX(1.1);
}

.bar-tooltip {
  position: absolute;
  bottom: 100%;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0, 0, 0, 0.8);
  color: white;
  padding: 0.5rem;
  border-radius: 0.25rem;
  font-size: 0.75rem;
  white-space: nowrap;
  opacity: 0;
  visibility: hidden;
  transition: all 0.2s;
  z-index: 10;
}

.bar:hover .bar-tooltip {
  opacity: 1;
  visibility: visible;
}

.tooltip-title {
  font-weight: 600;
  margin-bottom: 0.25rem;
}

.tooltip-item {
  margin-bottom: 0.125rem;
}

.tooltip-item.positive {
  color: #10b981;
}

.tooltip-item.negative {
  color: #f87171;
}

.x-label {
  font-size: 0.75rem;
  color: #6b7280;
  text-align: center;
  margin-top: 0.5rem;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
}

.stats-panel {
  flex: 1;
  min-width: 200px;
  border-left: 1px solid #e5e7eb;
  padding-left: 1rem;
}

.stats-header {
  margin-bottom: 1rem;
}

.stats-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: #1f2937;
}

.stats-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  max-height: calc(100% - 3rem);
  overflow-y: auto;
  /* 隐藏滚动条 */
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE and Edge */
}

.stats-list::-webkit-scrollbar {
  display: none; /* Chrome, Safari, Opera */
}

.stats-item {
  padding: 0.75rem;
  background-color: #f9fafb;
  border-radius: 0.375rem;
  border: 1px solid #e5e7eb;
}

.member-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.member-indicator {
  width: 0.75rem;
  height: 0.75rem;
  border-radius: 50%;
}

.member-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: #1f2937;
}

.member-stats {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.stat-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.stat-label {
  font-size: 0.75rem;
  color: #6b7280;
}

.stat-value {
  font-size: 0.75rem;
  font-weight: 500;
  color: #1f2937;
}

.stat-value.positive {
  color: #10b981;
}

.stat-value.negative {
  color: #ef4444;
}

.stat-value.neutral {
  color: #6b7280;
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
@media (max-width: 768px) {
  .chart-content {
    flex-direction: column;
  }

  .stats-panel {
    border-left: none;
    border-top: 1px solid #e5e7eb;
    padding-left: 0;
    padding-top: 1rem;
  }
}
</style>
