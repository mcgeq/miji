<script setup lang="ts">
import { Card, Spinner } from '@/components/ui';
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
function formatAmount(amount: number | undefined | null): string {
  if (amount === undefined || amount === null || Number.isNaN(amount)) {
    return '0.00';
  }
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
  <div class="p-4">
    <!-- 头部控制 -->
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        财务统计
      </h3>
      <div class="flex gap-1 bg-gray-100 dark:bg-gray-800 rounded-md p-1">
        <button
          v-for="period in [
            { key: 'month', label: '本月' },
            { key: 'quarter', label: '本季度' },
            { key: 'year', label: '本年' },
          ]"
          :key="period.key"
          class="px-4 py-2 text-sm rounded transition-all"
          :class="selectedPeriod === period.key ? 'bg-white dark:bg-gray-700 text-blue-600 dark:text-blue-400 shadow-sm' : 'text-gray-500 dark:text-gray-400 hover:text-gray-700 dark:hover:text-gray-200'"
          @click="changePeriod(period.key as any)"
        >
          {{ period.label }}
        </button>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex items-center justify-center gap-2 py-8 text-gray-500 dark:text-gray-400">
      <Spinner size="md" />
      <span>加载统计数据...</span>
    </div>

    <!-- 统计内容 -->
    <div v-else-if="stats" class="flex flex-col gap-6">
      <!-- 总览卡片 -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <Card padding="md" hoverable>
          <div class="flex items-start gap-3">
            <div class="p-1.5 rounded-lg bg-green-50 dark:bg-green-900/30 text-green-600 dark:text-green-400" title="总收入">
              <LucideTrendingUp :size="20" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-xl sm:text-2xl font-semibold text-gray-900 dark:text-white break-all">
                ¥{{ formatAmount(stats.totalIncome) }}
              </div>
            </div>
          </div>
        </Card>

        <Card padding="md" hoverable>
          <div class="flex items-start gap-3">
            <div class="p-1.5 rounded-lg bg-red-50 dark:bg-red-900/30 text-red-600 dark:text-red-400" title="总支出">
              <LucideTrendingDown :size="20" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-xl sm:text-2xl font-semibold text-gray-900 dark:text-white break-all">
                ¥{{ formatAmount(stats.totalExpense) }}
              </div>
            </div>
          </div>
        </Card>

        <Card padding="md" hoverable>
          <div class="flex items-start gap-3">
            <div class="p-1.5 rounded-lg bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400" title="净余额">
              <LucideWallet :size="20" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-xl sm:text-2xl font-semibold text-gray-900 dark:text-white break-all">
                ¥{{ formatAmount(stats.totalIncome - stats.totalExpense) }}
              </div>
            </div>
          </div>
        </Card>

        <Card padding="md" hoverable>
          <div class="flex items-start gap-3">
            <div class="p-1.5 rounded-lg bg-yellow-100 dark:bg-yellow-900/30 text-yellow-500 dark:text-yellow-400" title="待结算">
              <LucideClock :size="20" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-xl sm:text-2xl font-semibold text-gray-900 dark:text-white break-all">
                ¥{{ formatAmount(stats.pendingSettlement) }}
              </div>
            </div>
          </div>
        </Card>
      </div>

      <!-- 支出分析 -->
      <Card padding="lg">
        <ExpenseChart
          :data="[
            { category: '共同支出', amount: stats.sharedExpense, color: '#3b82f6' },
            { category: '个人支出', amount: stats.personalExpense, color: '#10b981' },
          ]"
          title="支出分析"
          height="300px"
        />
      </Card>

      <!-- 成员统计 -->
      <Card padding="lg">
        <MemberContributionChart
          :data="stats.memberStats.map(member => ({
            name: member.memberName,
            totalPaid: member.totalPaid || 0,
            totalOwed: member.totalOwed || 0,
            netBalance: member.netBalance || 0,
          }))"
          title="成员贡献度"
          height="400px"
        />
      </Card>

      <!-- 活动统计 -->
      <Card padding="lg">
        <h4 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          活动统计
        </h4>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <div class="flex items-center gap-3 p-4 bg-gray-50 dark:bg-gray-900/50 rounded-md">
            <LucideUsers :size="32" class="text-gray-500 dark:text-gray-400" />
            <div class="flex-1">
              <div class="text-xl font-semibold text-gray-900 dark:text-white">
                {{ stats.memberCount }}
              </div>
              <div class="text-xs text-gray-500 dark:text-gray-400">
                活跃成员
              </div>
            </div>
          </div>
          <div class="flex items-center gap-3 p-4 bg-gray-50 dark:bg-gray-900/50 rounded-md">
            <LucideReceipt :size="32" class="text-gray-500 dark:text-gray-400" />
            <div class="flex-1">
              <div class="text-xl font-semibold text-gray-900 dark:text-white">
                {{ stats.activeTransactionCount }}
              </div>
              <div class="text-xs text-gray-500 dark:text-gray-400">
                交易笔数
              </div>
            </div>
          </div>
          <div class="flex items-center gap-3 p-4 bg-gray-50 dark:bg-gray-900/50 rounded-md">
            <LucideSplit :size="32" class="text-gray-500 dark:text-gray-400" />
            <div class="flex-1">
              <div class="text-xl font-semibold text-gray-900 dark:text-white">
                {{ stats.memberStats.reduce((sum, m) => sum + m.splitCount, 0) }}
              </div>
              <div class="text-xs text-gray-500 dark:text-gray-400">
                分摆记录
              </div>
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- 空状态 -->
    <div v-else class="flex flex-col items-center justify-center py-12 text-center">
      <LucideBarChart3 :size="48" class="text-gray-400 dark:text-gray-600 mb-4" />
      <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
        暂无统计数据
      </h3>
      <p class="text-gray-500 dark:text-gray-400">
        当前时间段内没有财务数据
      </p>
    </div>
  </div>
</template>
