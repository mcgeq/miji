<script setup lang="ts">
import { MoneyDb } from '@/services/money/money';
import ExpenseChart from './charts/ExpenseChart.vue';
import MemberContributionChart from './charts/MemberContributionChart.vue';
import type { FamilyLedgerStats } from '@/schema/money';

interface Props {
  familyLedgerSerialNum: string;
}

const props = defineProps<Props>();

// 本地状态
const stats = ref<FamilyLedgerStats | null>(null);
const loading = ref(false);
const selectedPeriod = ref<'month' | 'quarter' | 'year'>('month');

// 获取统计数据
async function fetchStats() {
  loading.value = true;
  try {
    const result = await MoneyDb.getFamilyLedgerStats(props.familyLedgerSerialNum);
    stats.value = result;
  } catch (error) {
    console.error('获取统计数据失败:', error);
    // 如果获取失败，设置默认值
    stats.value = {
      familyLedgerSerialNum: props.familyLedgerSerialNum,
      totalIncome: 0,
      totalExpense: 0,
      sharedExpense: 0,
      personalExpense: 0,
      pendingSettlement: 0,
      memberCount: 0,
      activeTransactionCount: 0,
      memberStats: [],
    };
  } finally {
    loading.value = false;
  }
}

// 格式化金额
function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

// 移除未使用的函数

// 切换时间周期
function changePeriod(period: 'month' | 'quarter' | 'year') {
  selectedPeriod.value = period;
  fetchStats();
}

// 初始化
onMounted(() => {
  fetchStats();
});
</script>

<template>
  <div class="financial-stats">
    <!-- 头部控制 -->
    <div class="stats-header">
      <h3 class="stats-title">
        财务统计
      </h3>
      <div class="period-selector">
        <button
          v-for="period in [
            { key: 'month', label: '本月' },
            { key: 'quarter', label: '本季度' },
            { key: 'year', label: '本年' },
          ]"
          :key="period.key"
          class="period-btn"
          :class="{ active: selectedPeriod === period.key }"
          @click="changePeriod(period.key as any)"
        >
          {{ period.label }}
        </button>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <div class="loading-spinner" />
      <span>加载统计数据...</span>
    </div>

    <!-- 统计内容 -->
    <div v-else-if="stats" class="stats-content">
      <!-- 总览卡片 -->
      <div class="overview-cards">
        <div class="stat-card income">
          <div class="card-icon" title="总收入">
            <LucideTrendingUp class="w-6 h-6" />
          </div>
          <div class="card-content">
            <div class="card-value">
              ¥{{ formatAmount(stats.totalIncome) }}
            </div>
          </div>
        </div>

        <div class="stat-card expense">
          <div class="card-icon" title="总支出">
            <LucideTrendingDown class="w-6 h-6" />
          </div>
          <div class="card-content">
            <div class="card-value">
              ¥{{ formatAmount(stats.totalExpense) }}
            </div>
          </div>
        </div>

        <div class="stat-card balance">
          <div class="card-icon" title="净余额">
            <LucideWallet class="w-6 h-6" />
          </div>
          <div class="card-content">
            <div class="card-value">
              ¥{{ formatAmount(stats.totalIncome - stats.totalExpense) }}
            </div>
          </div>
        </div>

        <div class="stat-card pending">
          <div class="card-icon" title="待结算">
            <LucideClock class="w-6 h-6" />
          </div>
          <div class="card-content">
            <div class="card-value">
              ¥{{ formatAmount(stats.pendingSettlement) }}
            </div>
          </div>
        </div>
      </div>

      <!-- 支出分析 -->
      <div class="expense-analysis">
        <ExpenseChart
          :data="[
            { category: '共同支出', amount: stats.sharedExpense, color: '#3b82f6' },
            { category: '个人支出', amount: stats.personalExpense, color: '#10b981' },
          ]"
          title="支出分析"
          height="300px"
        />
      </div>

      <!-- 成员统计 -->
      <div class="member-stats">
        <MemberContributionChart
          :data="stats.memberStats.map(member => ({
            name: member.memberName,
            totalPaid: member.totalPaid,
            totalOwed: member.totalOwed,
            netBalance: member.netBalance,
          }))"
          title="成员贡献度"
          height="400px"
        />
      </div>

      <!-- 活动统计 -->
      <div class="activity-stats">
        <h4 class="section-title">
          活动统计
        </h4>
        <div class="activity-grid">
          <div class="activity-item">
            <LucideUsers class="activity-icon" />
            <div class="activity-content">
              <div class="activity-value">
                {{ stats.memberCount }}
              </div>
              <div class="activity-label">
                活跃成员
              </div>
            </div>
          </div>
          <div class="activity-item">
            <LucideReceipt class="activity-icon" />
            <div class="activity-content">
              <div class="activity-value">
                {{ stats.activeTransactionCount }}
              </div>
              <div class="activity-label">
                交易笔数
              </div>
            </div>
          </div>
          <div class="activity-item">
            <LucideSplit class="activity-icon" />
            <div class="activity-content">
              <div class="activity-value">
                {{ stats.memberStats.reduce((sum, m) => sum + m.splitCount, 0) }}
              </div>
              <div class="activity-label">
                分摊记录
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-else class="empty-state">
      <LucideBarChart3 class="empty-icon" />
      <h3 class="empty-title">
        暂无统计数据
      </h3>
      <p class="empty-description">
        当前时间段内没有财务数据
      </p>
    </div>
  </div>
</template>

<style scoped>
.financial-stats {
  padding: 1rem;
}

.stats-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
}

.stats-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.period-selector {
  display: flex;
  gap: 0.25rem;
  background-color: var(--color-gray-100);
  border-radius: 0.375rem;
  padding: 0.25rem;
}

.period-btn {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  color: var(--color-gray-500);
  border-radius: 0.25rem;
  transition: all 0.2s;
}

.period-btn:hover {
  color: var(--color-gray-700);
}

.period-btn.active {
  background-color: var(--color-base-100);
  color: var(--color-primary);
  box-shadow: var(--shadow-sm);
}

.loading-container {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 2rem;
  color: var(--color-gray-500);
}

.loading-spinner {
  width: 1rem;
  height: 1rem;
  border: 2px solid var(--color-gray-200);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.stats-content {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.overview-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 1rem;
}

.stat-card {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  padding: 1rem 1.25rem;
  background: var(--color-base-200);
  border-radius: 0.5rem;
  border: 1px solid var(--color-gray-200);
  box-shadow: var(--shadow-sm);
}

.card-icon {
  padding: 0.375rem;
  border-radius: 0.5rem;
}

.card-icon :deep(svg) {
  width: 1.25rem;
  height: 1.25rem;
}

.stat-card.income .card-icon {
  background-color: var(--color-green-50);
  color: var(--color-green-600);
}

.stat-card.expense .card-icon {
  background-color: var(--color-red-50);
  color: var(--color-red-600);
}

.stat-card.balance .card-icon {
  background-color: var(--color-blue-100);
  color: var(--color-blue-600);
}

.stat-card.pending .card-icon {
  background-color: var(--color-yellow-100);
  color: var(--color-yellow-500);
}

.card-content {
  flex: 1;
  min-width: 0;
}

.card-value {
  font-size: 1.375rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 0.25rem;
  word-break: break-all;
}

.card-label {
  font-size: 0.875rem;
  color: var(--color-gray-500);
}

.expense-analysis, .member-stats, .activity-stats {
  background: var(--color-base-100);
  border-radius: 0.5rem;
  border: 1px solid var(--color-gray-200);
  padding: 1.5rem;
}

.section-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 1rem;
}

.expense-breakdown {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.breakdown-item {
  display: grid;
  grid-template-columns: 1fr 200px auto;
  align-items: center;
  gap: 1rem;
}

.breakdown-info {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.breakdown-label {
  font-weight: 500;
  color: #374151;
}

.breakdown-amount {
  font-weight: 600;
  color: #1f2937;
}

.breakdown-bar {
  height: 0.5rem;
  background-color: var(--color-gray-100);
  border-radius: 0.25rem;
  overflow: hidden;
}

.bar-fill {
  height: 100%;
  border-radius: 0.25rem;
  transition: width 0.3s ease;
}

.bar-fill.shared {
  background-color: var(--color-primary);
}

.bar-fill.personal {
  background-color: var(--color-green-500);
}

.breakdown-percentage {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-500);
  text-align: right;
}

.member-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.member-stat-item {
  padding: 1rem;
  background-color: var(--color-base-100);
  border-radius: 0.5rem;
  border: 1px solid var(--color-gray-200);
}

.member-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.75rem;
}

.member-name {
  font-size: 1rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.member-balance {
  font-weight: 600;
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  font-size: 0.875rem;
}

.member-balance.positive {
  background-color: var(--color-green-50);
  color: var(--color-green-600);
}

.member-balance.negative {
  background-color: var(--color-red-50);
  color: var(--color-red-600);
}

.member-balance.neutral {
  background-color: var(--color-gray-100);
  color: var(--color-gray-500);
}

.member-details {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));
  gap: 0.5rem;
  margin-bottom: 1rem;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.detail-label {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

.detail-value {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.contribution-bar {
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 0.75rem;
}

.contribution-label {
  font-size: 0.75rem;
  color: #6b7280;
}

.bar-container {
  height: 0.375rem;
  background-color: var(--color-gray-200);
  border-radius: 0.25rem;
  overflow: hidden;
}

.contribution-fill {
  height: 100%;
  border-radius: 0.25rem;
  transition: width 0.3s ease;
}

.contribution-percentage {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-gray-500);
}

.activity-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 1rem;
}

.activity-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
  background-color: var(--color-base-100);
  border-radius: 0.375rem;
}

.activity-icon {
  width: 2rem;
  height: 2rem;
  color: var(--color-gray-500);
}

.activity-content {
  flex: 1;
}

.activity-value {
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.activity-label {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  text-align: center;
}

.empty-icon {
  width: 3rem;
  height: 3rem;
  color: var(--color-gray-400);
  margin-bottom: 1rem;
}

.empty-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 0.5rem;
}

.empty-description {
  color: var(--color-gray-500);
}
</style>
