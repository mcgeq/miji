<script setup lang="ts">
import {
  ArrowLeft,
  ArrowRight,
  ArrowRightLeft,
  BarChart3,
  CheckCircle2,
  DollarSign,
  Inbox,
  Lightbulb,
  Network,
  RefreshCw,
  TrendingDown,
  TrendingUp,
  Users,
  XCircle,
  Zap,
} from 'lucide-vue-next';
import { useRouter } from 'vue-router';
import { useMoneyAuth } from '@/composables/useMoneyAuth';
import { settlementService } from '@/services/money/settlement';
import { handleApiError } from '@/utils/apiHelper';
import { toast } from '@/utils/toast';
import SettlementPathVisualization from '../components/SettlementPathVisualization.vue';
import type { TransferSuggestion } from '@/services/money/settlement';

// ==================== 接口定义 ====================

interface SettlementSuggestion {
  familyLedgerSerialNum: string;
  optimizedTransfers: TransferSuggestion[];
  totalTransfers: number;
  totalAmount: number;
  savings: number;
}

// ==================== 状态管理 ====================

const router = useRouter();

const suggestion = ref<SettlementSuggestion | null>(null);
const loading = ref(false);
const executing = ref(false);
const showVisualization = ref(true);

// 使用认证composable获取当前用户信息
const { currentLedgerSerialNum, currentMemberSerialNum } = useMoneyAuth();

// ==================== 计算属性 ====================

// 原始转账次数（未优化前）
const originalTransferCount = computed(() => {
  if (!suggestion.value) return 0;
  return suggestion.value.totalTransfers + suggestion.value.savings;
});

// 优化节省的转账次数
const optimizationSavings = computed(() => {
  return suggestion.value?.savings || 0;
});

// 优化百分比
const optimizationPercentage = computed(() => {
  if (!suggestion.value || originalTransferCount.value === 0) return 0;
  return Math.round((suggestion.value.savings / originalTransferCount.value) * 100);
});

// 参与成员数量
const participantCount = computed(() => {
  if (!suggestion.value) return 0;
  const members = new Set<string>();
  suggestion.value.optimizedTransfers.forEach(transfer => {
    members.add(transfer.from);
    members.add(transfer.to);
  });
  return members.size;
});

// ==================== 方法 ====================

// 加载结算建议
async function loadSuggestion() {
  loading.value = true;
  try {
    const result = await settlementService.calculateSuggestion({
      familyLedgerSerialNum: currentLedgerSerialNum.value,
      settlementType: 'optimized',
    });

    suggestion.value = {
      familyLedgerSerialNum: currentLedgerSerialNum.value,
      optimizedTransfers: result.optimizedTransfers,
      totalTransfers: result.optimizedTransfers.length,
      totalAmount: result.totalAmount,
      savings: result.savings,
    };
  } catch (error) {
    handleApiError(error, '加载结算建议失败');
  } finally {
    loading.value = false;
  }
}

// 返回
function handleBack() {
  router.back();
}

// 刷新
async function handleRefresh() {
  await loadSuggestion();
  toast.success('已刷新');
}

// 执行结算
async function handleExecute() {
  if (!suggestion.value) return;

  executing.value = true;
  try {
    const now = new Date();
    const periodStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    const periodEnd = now.toISOString().split('T')[0];

    const result = await settlementService.executeSettlement({
      familyLedgerSerialNum: suggestion.value.familyLedgerSerialNum,
      settlementType: 'optimized',
      periodStart,
      periodEnd,
      participantMembers: Array.from(new Set([
        ...suggestion.value.optimizedTransfers.map(t => t.from),
        ...suggestion.value.optimizedTransfers.map(t => t.to),
      ])),
      optimizedTransfers: suggestion.value.optimizedTransfers,
      totalAmount: suggestion.value.totalAmount,
      currency: 'CNY',
      initiatedBy: currentMemberSerialNum.value,
    });

    toast.success(`结算已成功执行，单号：${result.serialNum}`);
    router.push('/money/settlement-records');
  } catch (error) {
    handleApiError(error, '执行结算失败');
  } finally {
    executing.value = false;
  }
}

// 切换可视化显示
function toggleVisualization() {
  showVisualization.value = !showVisualization.value;
}

// 获取成员颜色
function getMemberColor(memberSerialNum: string): string {
  const colors = [
    '#3b82f6',
    '#ef4444',
    '#10b981',
    '#f59e0b',
    '#8b5cf6',
    '#ec4899',
    '#14b8a6',
    '#f97316',
  ];
  const index = Number.parseInt(memberSerialNum.slice(-1), 16) % colors.length;
  return colors[index];
}

// 获取首字母
function getInitials(name: string): string {
  return name.charAt(0).toUpperCase();
}

// 格式化金额
function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

// ==================== 生命周期 ====================

onMounted(() => {
  loadSuggestion();
});
</script>

<template>
  <div class="settlement-suggestion-view">
    <!-- 页面标题 -->
    <div class="page-header">
      <div class="header-left">
        <button class="back-btn" @click="handleBack">
          <component :is="ArrowLeft" class="w-5 h-5" />
        </button>
        <div>
          <h1 class="page-title">
            智能结算建议
          </h1>
          <p class="page-subtitle">
            基于当前债务关系，为您优化结算方案
          </p>
        </div>
      </div>
      <div class="header-right">
        <button class="btn-secondary" :disabled="loading" @click="handleRefresh">
          <component :is="RefreshCw" :class="{ 'animate-spin': loading }" class="w-4 h-4" />
          <span>刷新</span>
        </button>
        <button
          class="btn-primary"
          :disabled="!suggestion || executing"
          @click="handleExecute"
        >
          <component :is="Zap" class="w-4 h-4" />
          <span>{{ executing ? '执行中...' : '一键结算' }}</span>
        </button>
      </div>
    </div>

    <!-- 优化统计 -->
    <div v-if="suggestion" class="optimization-summary">
      <div class="summary-card summary-main">
        <div class="summary-icon">
          <component :is="TrendingUp" class="w-8 h-8" />
        </div>
        <div class="summary-content">
          <div class="summary-label">
            优化效果
          </div>
          <div class="summary-value">
            减少 {{ optimizationSavings }} 笔转账
          </div>
          <div class="summary-hint">
            从 {{ originalTransferCount }} 笔优化至 {{ suggestion.totalTransfers }} 笔
          </div>
        </div>
      </div>

      <div class="summary-card summary-transfers">
        <div class="summary-icon">
          <component :is="ArrowRightLeft" class="w-6 h-6" />
        </div>
        <div class="summary-content">
          <div class="summary-label">
            需要转账
          </div>
          <div class="summary-value">
            {{ suggestion.totalTransfers }} 笔
          </div>
          <div class="summary-hint">
            最优方案
          </div>
        </div>
      </div>

      <div class="summary-card summary-amount">
        <div class="summary-icon">
          <component :is="DollarSign" class="w-6 h-6" />
        </div>
        <div class="summary-content">
          <div class="summary-label">
            结算总额
          </div>
          <div class="summary-value">
            ¥{{ formatAmount(suggestion.totalAmount) }}
          </div>
          <div class="summary-hint">
            CNY
          </div>
        </div>
      </div>

      <div class="summary-card summary-members">
        <div class="summary-icon">
          <component :is="Users" class="w-6 h-6" />
        </div>
        <div class="summary-content">
          <div class="summary-label">
            参与成员
          </div>
          <div class="summary-value">
            {{ participantCount }} 人
          </div>
          <div class="summary-hint">
            全部成员
          </div>
        </div>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      <div class="loading-spinner" />
      <p class="loading-text">
        正在计算最优结算方案...
      </p>
    </div>

    <!-- 无建议状态 -->
    <div v-else-if="!suggestion" class="empty-state">
      <component :is="Inbox" class="empty-icon" />
      <p class="empty-text">
        暂无结算建议
      </p>
      <p class="empty-hint">
        当前没有需要结算的债务关系
      </p>
      <button class="btn-primary mt-4" @click="handleRefresh">
        <component :is="RefreshCw" class="w-4 h-4" />
        <span>重新计算</span>
      </button>
    </div>

    <!-- 结算方案 -->
    <div v-else class="settlement-section">
      <!-- 算法说明 -->
      <div class="algorithm-explanation">
        <div class="explanation-header">
          <component :is="Lightbulb" class="w-5 h-5" />
          <span>算法说明</span>
        </div>
        <p class="explanation-text">
          使用贪心算法优化结算路径，通过计算每个成员的净欠款，
          将多对多的债务关系简化为最少的转账次数。
          本次优化节省了 {{ optimizationSavings }} 笔转账操作。
        </p>
      </div>

      <!-- 转账列表 -->
      <div class="transfers-container">
        <div class="section-header">
          <h3 class="section-title">
            <component :is="ArrowRightLeft" class="w-5 h-5" />
            <span>转账明细</span>
          </h3>
          <span class="section-count">{{ suggestion.optimizedTransfers.length }} 笔</span>
        </div>

        <div class="transfers-list">
          <div
            v-for="(transfer, index) in suggestion.optimizedTransfers"
            :key="index"
            class="transfer-card"
          >
            <!-- 序号 -->
            <div class="transfer-index">
              <span>{{ index + 1 }}</span>
            </div>

            <!-- 转账信息 -->
            <div class="transfer-content">
              <div class="transfer-members">
                <!-- 付款人 -->
                <div class="member-info">
                  <div class="member-avatar" :style="{ backgroundColor: getMemberColor(transfer.from) }">
                    {{ getInitials(transfer.fromName) }}
                  </div>
                  <div class="member-details">
                    <div class="member-name">
                      {{ transfer.fromName }}
                    </div>
                    <div class="member-role">
                      付款人
                    </div>
                  </div>
                </div>

                <!-- 箭头 -->
                <div class="transfer-arrow">
                  <component :is="ArrowRight" class="w-6 h-6" />
                </div>

                <!-- 收款人 -->
                <div class="member-info">
                  <div class="member-avatar" :style="{ backgroundColor: getMemberColor(transfer.to) }">
                    {{ getInitials(transfer.toName) }}
                  </div>
                  <div class="member-details">
                    <div class="member-name">
                      {{ transfer.toName }}
                    </div>
                    <div class="member-role">
                      收款人
                    </div>
                  </div>
                </div>
              </div>

              <!-- 金额 -->
              <div class="transfer-amount">
                <span class="amount-value">¥{{ formatAmount(transfer.amount) }}</span>
                <span class="amount-currency">{{ transfer.currency }}</span>
              </div>
            </div>

            <!-- 状态 -->
            <div class="transfer-status">
              <span class="status-badge status-pending">待执行</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 可视化图表 -->
      <div class="visualization-container">
        <div class="section-header">
          <h3 class="section-title">
            <component :is="Network" class="w-5 h-5" />
            <span>结算路径图</span>
          </h3>
          <button class="btn-text" @click="toggleVisualization">
            {{ showVisualization ? '收起' : '展开' }}
          </button>
        </div>

        <div v-if="showVisualization" class="visualization-content">
          <SettlementPathVisualization
            v-if="suggestion"
            :transfers="suggestion.optimizedTransfers"
          />
        </div>
      </div>

      <!-- 对比分析 -->
      <div class="comparison-section">
        <div class="section-header">
          <h3 class="section-title">
            <component :is="BarChart3" class="w-5 h-5" />
            <span>优化对比</span>
          </h3>
        </div>

        <div class="comparison-cards">
          <div class="comparison-card comparison-before">
            <div class="comparison-header">
              <component :is="XCircle" class="w-5 h-5" />
              <span>优化前</span>
            </div>
            <div class="comparison-stats">
              <div class="stat-item">
                <span class="stat-label">转账次数</span>
                <span class="stat-value">{{ originalTransferCount }}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">复杂度</span>
                <span class="stat-value complexity-high">高</span>
              </div>
            </div>
          </div>

          <div class="comparison-arrow">
            <component :is="ArrowRight" class="w-8 h-8" />
          </div>

          <div class="comparison-card comparison-after">
            <div class="comparison-header">
              <component :is="CheckCircle2" class="w-5 h-5" />
              <span>优化后</span>
            </div>
            <div class="comparison-stats">
              <div class="stat-item">
                <span class="stat-label">转账次数</span>
                <span class="stat-value">{{ suggestion.totalTransfers }}</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">复杂度</span>
                <span class="stat-value complexity-low">低</span>
              </div>
            </div>
          </div>
        </div>

        <div class="comparison-benefit">
          <component :is="TrendingDown" class="w-5 h-5" />
          <span>节省 {{ optimizationPercentage }}% 的转账操作</span>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* 页面布局 */
.settlement-suggestion-view {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 页面标题 */
.page-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.header-left {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
}

.back-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  transition: background-color 0.15s, color 0.15s;
  color: #4b5563;
}

.back-btn:hover {
  background-color: #f3f4f6;
}

:global(.dark) .back-btn {
  color: #9ca3af;
}

:global(.dark) .back-btn:hover {
  background-color: #1f2937;
}

.page-title {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .page-title {
  color: #f3f4f6;
}

.page-subtitle {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .page-subtitle {
  color: #9ca3af;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

/* 优化统计 */
.optimization-summary {
  display: grid;
  grid-template-columns: repeat(1, minmax(0, 1fr));
  gap: 1rem;
}

@media (min-width: 768px) {
  .optimization-summary {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (min-width: 1024px) {
  .optimization-summary {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}

.summary-card {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.25rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  border-left: 4px solid transparent;
}

:global(.dark) .summary-card {
  background-color: #1f2937;
}

.summary-main {
  border-left-color: #10b981;
}

@media (min-width: 768px) {
  .summary-main {
    grid-column: span 2;
  }
}

.summary-transfers {
  border-left-color: #3b82f6;
}

.summary-amount {
  border-left-color: #a855f7;
}

.summary-members {
  border-left-color: #f97316;
}

.summary-icon {
  width: 3rem;
  height: 3rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

.summary-main .summary-icon {
  background-color: #d1fae5;
  color: #059669;
}

:global(.dark) .summary-main .summary-icon {
  background-color: rgba(6, 95, 70, 0.3);
  color: #34d399;
}

.summary-transfers .summary-icon {
  background-color: #dbeafe;
  color: #2563eb;
}

:global(.dark) .summary-transfers .summary-icon {
  background-color: rgba(30, 58, 138, 0.3);
  color: #60a5fa;
}

.summary-amount .summary-icon {
  background-color: #f3e8ff;
  color: #9333ea;
}

:global(.dark) .summary-amount .summary-icon {
  background-color: rgba(107, 33, 168, 0.3);
  color: #c084fc;
}

.summary-members .summary-icon {
  background-color: #ffedd5;
  color: #ea580c;
}

:global(.dark) .summary-members .summary-icon {
  background-color: rgba(124, 45, 18, 0.3);
  color: #fb923c;
}

.summary-content {
  flex: 1;
}

.summary-label {
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .summary-label {
  color: #9ca3af;
}

.summary-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  margin-top: 0.25rem;
}

:global(.dark) .summary-value {
  color: #f3f4f6;
}

.summary-hint {
  font-size: 0.75rem;
  color: #6b7280;
  margin-top: 0.25rem;
}

/* 加载状态 */
.loading-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding-top: 5rem;
  padding-bottom: 5rem;
  background-color: white;
  border-radius: 0.5rem;
}

:global(.dark) .loading-container {
  background-color: #1f2937;
}

.loading-spinner {
  width: 4rem;
  height: 4rem;
  border: 4px solid #3b82f6;
  border-top-color: transparent;
  border-radius: 9999px;
  animation: spin 1s linear infinite;
}

.loading-text {
  margin-top: 1rem;
  color: #4b5563;
}

:global(.dark) .loading-text {
  color: #9ca3af;
}

/* 空状态 */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding-top: 5rem;
  padding-bottom: 5rem;
  background-color: white;
  border-radius: 0.5rem;
}

:global(.dark) .empty-state {
  background-color: #1f2937;
}

.empty-icon {
  width: 4rem;
  height: 4rem;
  color: #9ca3af;
}

:global(.dark) .empty-icon {
  color: #4b5563;
}

.empty-text {
  margin-top: 1rem;
  font-size: 1.125rem;
  font-weight: 500;
  color: #111827;
}

:global(.dark) .empty-text {
  color: #f3f4f6;
}

.empty-hint {
  margin-top: 0.5rem;
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .empty-hint {
  color: #9ca3af;
}

/* 结算方案区域 */
.settlement-section {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 算法说明 */
.algorithm-explanation {
  background-color: #eff6ff;
  border-radius: 0.5rem;
  padding: 1rem;
  border: 1px solid #bfdbfe;
}

:global(.dark) .algorithm-explanation {
  background-color: rgba(30, 58, 138, 0.2);
  border-color: #1e3a8a;
}

.explanation-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #1d4ed8;
  font-weight: 500;
  margin-bottom: 0.5rem;
}

:global(.dark) .explanation-header {
  color: #93c5fd;
}

.explanation-text {
  font-size: 0.875rem;
  color: #2563eb;
  line-height: 1.625;
}

:global(.dark) .explanation-text {
  color: #60a5fa;
}

/* 区域标题 */
.section-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 1.125rem;
  font-weight: 600;
  color: #111827;
}

:global(.dark) .section-title {
  color: #f3f4f6;
}

.section-count {
  font-size: 0.875rem;
  color: #6b7280;
}

/* 转账列表 */
.transfers-container {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

:global(.dark) .transfers-container {
  background-color: #1f2937;
}

.transfers-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.transfer-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background-color: #f9fafb;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
}

:global(.dark) .transfer-card {
  background-color: rgba(17, 24, 39, 0.5);
  border-color: #374151;
}

.transfer-index {
  width: 2rem;
  height: 2rem;
  border-radius: 9999px;
  background-color: #dbeafe;
  color: #1d4ed8;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 0.875rem;
}

:global(.dark) .transfer-index {
  background-color: rgba(30, 58, 138, 0.3);
  color: #93c5fd;
}

.transfer-content {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.transfer-members {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.member-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.member-avatar {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 0.875rem;
}

.member-details {
  display: flex;
  flex-direction: column;
}

.member-name {
  font-weight: 500;
  color: #111827;
  font-size: 0.875rem;
}

:global(.dark) .member-name {
  color: #f3f4f6;
}

.member-role {
  font-size: 0.75rem;
  color: #6b7280;
}

.transfer-arrow {
  color: #3b82f6;
}

:global(.dark) .transfer-arrow {
  color: #60a5fa;
}

.transfer-amount {
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
}

.amount-value {
  font-size: 1.25rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .amount-value {
  color: #f3f4f6;
}

.amount-currency {
  font-size: 0.875rem;
  color: #6b7280;
}

.transfer-status {
  display: flex;
  align-items: center;
}

.status-badge {
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.status-pending {
  background-color: #fef3c7;
  color: #92400e;
}

:global(.dark) .status-pending {
  background-color: rgba(120, 53, 15, 0.3);
  color: #fcd34d;
}

/* 可视化容器 */
.visualization-container {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

:global(.dark) .visualization-container {
  background-color: #1f2937;
}

.visualization-content {
  margin-top: 1rem;
}

/* 对比分析 */
.comparison-section {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

:global(.dark) .comparison-section {
  background-color: #1f2937;
}

.comparison-cards {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1.5rem;
}

.comparison-card {
  flex: 1;
  max-width: 20rem;
  padding: 1rem;
  border-radius: 0.5rem;
  border: 2px solid;
}

.comparison-before {
  border-color: #fecaca;
  background-color: #fef2f2;
}

:global(.dark) .comparison-before {
  border-color: #991b1b;
  background-color: rgba(127, 29, 29, 0.2);
}

.comparison-after {
  border-color: #bbf7d0;
  background-color: #f0fdf4;
}

:global(.dark) .comparison-after {
  border-color: #166534;
  background-color: rgba(20, 83, 45, 0.2);
}

.comparison-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-weight: 500;
  margin-bottom: 0.75rem;
}

.comparison-before .comparison-header {
  color: #b91c1c;
}

:global(.dark) .comparison-before .comparison-header {
  color: #fca5a5;
}

.comparison-after .comparison-header {
  color: #15803d;
}

:global(.dark) .comparison-after .comparison-header {
  color: #86efac;
}

.comparison-stats {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.stat-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.stat-label {
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .stat-label {
  color: #9ca3af;
}

.stat-value {
  font-size: 1.125rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .stat-value {
  color: #f3f4f6;
}

.complexity-high {
  color: #dc2626;
}

:global(.dark) .complexity-high {
  color: #f87171;
}

.complexity-low {
  color: #059669;
}

:global(.dark) .complexity-low {
  color: #34d399;
}

.comparison-arrow {
  color: #9ca3af;
}

:global(.dark) .comparison-arrow {
  color: #4b5563;
}

.comparison-benefit {
  margin-top: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  color: #15803d;
  font-weight: 500;
}

:global(.dark) .comparison-benefit {
  color: #86efac;
}

/* 按钮 */
.btn-primary {
  padding: 0.5rem 1rem;
  background-color: #2563eb;
  color: white;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  transition: background-color 0.15s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-primary:hover:not(:disabled) {
  background-color: #1d4ed8;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  padding: 0.5rem 1rem;
  background-color: #f3f4f6;
  color: #111827;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  transition: background-color 0.15s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-secondary:hover:not(:disabled) {
  background-color: #e5e7eb;
}

.btn-secondary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

:global(.dark) .btn-secondary {
  background-color: #374151;
  color: #f3f4f6;
}

:global(.dark) .btn-secondary:hover:not(:disabled) {
  background-color: #4b5563;
}

.btn-text {
  font-size: 0.875rem;
  color: #2563eb;
}

.btn-text:hover {
  text-decoration: underline;
}

:global(.dark) .btn-text {
  color: #60a5fa;
}

.animate-spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
