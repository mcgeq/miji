<script setup lang="ts">
import {
  ArrowRight,
  CheckCircle2,
  Clock,
  DollarSign,
  Eye,
  Inbox,
  RefreshCw,
  Search,
  TrendingDown,
  TrendingUp,
  Users,
} from 'lucide-vue-next';
import { useRouter } from 'vue-router';
import { useMoneyAuth } from '@/composables/useMoneyAuth';
import { debtService } from '@/services/money/debt';
import { handleApiError } from '@/utils/apiHelper';
import { toast } from '@/utils/toast';
import type { DebtRelation } from '@/services/money/debt';

// ==================== 接口定义 ====================

interface Member {
  serialNum: string;
  name: string;
  color?: string;
}

interface DebtStatistics {
  totalDebt: number;
  totalCredit: number;
  debtCount: number;
  creditCount: number;
  memberCount: number;
  totalRelations: number;
}

// ==================== 状态管理 ====================

const router = useRouter();

// 数据
const debtRelations = ref<DebtRelation[]>([]);
const members = ref<Member[]>([]);
const loading = ref(false);
const syncing = ref(false);

// 使用认证composable获取当前用户信息
const { currentLedgerSerialNum, currentMemberSerialNum } = useMoneyAuth();

// 筛选
const filters = ref({
  memberSerialNum: '',
  status: 'all',
});
const searchQuery = ref('');
const sortBy = ref('amount');

// 分页
const currentPage = ref(1);
const pageSize = 20;

// ==================== 计算属性 ====================

// 统计信息
const statistics = computed<DebtStatistics>(() => {
  const stats = {
    totalDebt: 0,
    totalCredit: 0,
    debtCount: 0,
    creditCount: 0,
    memberCount: 0,
    totalRelations: debtRelations.value.filter(r => r.status === 'active').length,
  };

  const memberSet = new Set<string>();

  debtRelations.value.forEach(relation => {
    if (relation.status !== 'active') return;

    memberSet.add(relation.debtorMemberSerialNum);
    memberSet.add(relation.creditorMemberSerialNum);

    // 我欠别人
    if (relation.debtorMemberSerialNum === currentMemberSerialNum.value) {
      stats.totalDebt += relation.amount;
      stats.debtCount++;
    }

    // 别人欠我
    if (relation.creditorMemberSerialNum === currentMemberSerialNum.value) {
      stats.totalCredit += relation.amount;
      stats.creditCount++;
    }
  });

  stats.memberCount = memberSet.size;

  return stats;
});

// 净额
const netAmount = computed(() => statistics.value.totalCredit - statistics.value.totalDebt);

const netAmountClass = computed(() => {
  if (netAmount.value > 0) return 'text-green-600';
  if (netAmount.value < 0) return 'text-red-600';
  return 'text-gray-600';
});

const netAmountText = computed(() => {
  const abs = Math.abs(netAmount.value);
  if (netAmount.value > 0) return `+¥${formatAmount(abs)}`;
  if (netAmount.value < 0) return `-¥${formatAmount(abs)}`;
  return '¥0.00';
});

const netAmountHint = computed(() => {
  if (netAmount.value > 0) return '净债权';
  if (netAmount.value < 0) return '净债务';
  return '已平衡';
});

// 筛选后的关系
const filteredRelations = computed(() => {
  let result = [...debtRelations.value];

  // 筛选成员
  if (filters.value.memberSerialNum) {
    result = result.filter(
      r =>
        r.debtorMemberSerialNum === filters.value.memberSerialNum ||
        r.creditorMemberSerialNum === filters.value.memberSerialNum,
    );
  }

  // 筛选状态
  if (filters.value.status !== 'all') {
    result = result.filter(r => r.status === filters.value.status);
  }

  // 搜索
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    result = result.filter(
      r =>
        r.debtorMemberName.toLowerCase().includes(query) ||
        r.creditorMemberName.toLowerCase().includes(query),
    );
  }

  // 排序
  switch (sortBy.value) {
    case 'amount':
      result.sort((a, b) => b.amount - a.amount);
      break;
    case 'time':
      result.sort((a, b) => new Date(b.lastCalculatedAt).getTime() - new Date(a.lastCalculatedAt).getTime());
      break;
    case 'member':
      result.sort((a, b) => a.debtorMemberName.localeCompare(b.debtorMemberName));
      break;
  }

  return result;
});

// 分页后的关系
const paginatedRelations = computed(() => {
  const start = (currentPage.value - 1) * pageSize;
  const end = start + pageSize;
  return filteredRelations.value.slice(start, end);
});

const totalPages = computed(() => Math.ceil(filteredRelations.value.length / pageSize));

// ==================== 方法 ====================

// 加载债务关系数据
async function loadData() {
  loading.value = true;
  try {
    const result = await debtService.listRelations({
      familyLedgerSerialNum: currentLedgerSerialNum.value,
      memberSerialNum: filters.value.memberSerialNum || undefined,
      status: filters.value.status === 'all' ? undefined : filters.value.status as any,
    });
    debtRelations.value = result.rows || [];

    // TODO: 从成员API获取成员列表
    // members.value = await memberService.listMembers(currentLedgerSerialNum.value);
  } catch (error) {
    handleApiError(error, '加载债务关系失败');
  } finally {
    loading.value = false;
  }
}

// 同步债务关系
async function handleSync() {
  syncing.value = true;
  try {
    const count = await debtService.syncRelations(
      currentLedgerSerialNum.value,
      currentMemberSerialNum.value,
    );
    await loadData();
    toast.success(`同步成功，更新了 ${count} 条记录`);
  } catch (error) {
    handleApiError(error, '同步债务关系失败');
  } finally {
    syncing.value = false;
  }
}

// 发起结算
function handleSettlement() {
  router.push('/money/settlement-suggestion');
}

// 查看详情
function viewRelationDetail(relation: DebtRelation) {
  // eslint-disable-next-line no-console
  console.log('查看详情:', relation);
  // TODO: 打开详情弹窗或跳转
}

// 标记为已结算
async function markAsSettled(relation: DebtRelation) {
  try {
    await debtService.markAsSettled(relation.serialNum);
    relation.status = 'settled';
    toast.success('已标记为结算');
  } catch (error) {
    handleApiError(error, '标记结算失败');
  }
}

// 获取关系样式类
function getRelationClass(relation: DebtRelation) {
  const classes = [];

  if (relation.debtorMemberSerialNum === currentMemberSerialNum.value) {
    classes.push('debt-card-debt');
  }

  if (relation.creditorMemberSerialNum === currentMemberSerialNum.value) {
    classes.push('debt-card-credit');
  }

  if (relation.status !== 'active') {
    classes.push('debt-card-inactive');
  }

  return classes.join(' ');
}

// 获取成员颜色
function getMemberColor(memberSerialNum: string) {
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
function getInitials(name: string) {
  return name.charAt(0).toUpperCase();
}

// 格式化金额
function formatAmount(amount: number) {
  return amount.toFixed(2);
}

// 格式化时间
function formatTime(dateString: string) {
  const date = new Date(dateString);
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));

  if (days === 0) return '今天';
  if (days === 1) return '昨天';
  if (days < 7) return `${days}天前`;
  return date.toLocaleDateString();
}

// 获取状态文本
function getStatusText(status: string) {
  const statusMap: Record<string, string> = {
    active: '活跃',
    settled: '已结算',
    cancelled: '已取消',
  };
  return statusMap[status] || status;
}

// ==================== 生命周期 ====================

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="debt-relation-view">
    <!-- 页面标题 -->
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">
          债务关系
        </h1>
        <p class="page-subtitle">
          查看和管理成员间的债务关系
        </p>
      </div>
      <div class="header-right">
        <button class="btn-secondary" @click="handleSync">
          <component :is="RefreshCw" :class="{ 'animate-spin': syncing }" class="w-4 h-4" />
          <span>同步债务</span>
        </button>
        <button class="btn-primary" @click="handleSettlement">
          <component :is="TrendingUp" class="w-4 h-4" />
          <span>发起结算</span>
        </button>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-cards">
      <div class="stat-card stat-card-red">
        <div class="stat-icon">
          <component :is="TrendingDown" class="w-6 h-6" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            我欠别人
          </div>
          <div class="stat-value">
            ¥{{ formatAmount(statistics.totalDebt) }}
          </div>
          <div class="stat-hint">
            {{ statistics.debtCount }}笔债务
          </div>
        </div>
      </div>

      <div class="stat-card stat-card-green">
        <div class="stat-icon">
          <component :is="TrendingUp" class="w-6 h-6" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            别人欠我
          </div>
          <div class="stat-value">
            ¥{{ formatAmount(statistics.totalCredit) }}
          </div>
          <div class="stat-hint">
            {{ statistics.creditCount }}笔债权
          </div>
        </div>
      </div>

      <div class="stat-card stat-card-blue">
        <div class="stat-icon">
          <component :is="DollarSign" class="w-6 h-6" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            净额
          </div>
          <div class="stat-value" :class="netAmountClass">
            {{ netAmountText }}
          </div>
          <div class="stat-hint">
            {{ netAmountHint }}
          </div>
        </div>
      </div>

      <div class="stat-card stat-card-gray">
        <div class="stat-icon">
          <component :is="Users" class="w-6 h-6" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            涉及成员
          </div>
          <div class="stat-value">
            {{ statistics.memberCount }}
          </div>
          <div class="stat-hint">
            {{ statistics.totalRelations }}条关系
          </div>
        </div>
      </div>
    </div>

    <!-- 筛选和操作栏 -->
    <div class="filter-bar">
      <div class="filter-left">
        <!-- 成员筛选 -->
        <select v-model="filters.memberSerialNum" class="filter-select">
          <option value="">
            全部成员
          </option>
          <option v-for="member in members" :key="member.serialNum" :value="member.serialNum">
            {{ member.name }}
          </option>
        </select>

        <!-- 状态筛选 -->
        <select v-model="filters.status" class="filter-select">
          <option value="all">
            全部状态
          </option>
          <option value="active">
            活跃
          </option>
          <option value="settled">
            已结算
          </option>
          <option value="cancelled">
            已取消
          </option>
        </select>

        <!-- 排序 -->
        <select v-model="sortBy" class="filter-select">
          <option value="amount">
            按金额
          </option>
          <option value="time">
            按时间
          </option>
          <option value="member">
            按成员
          </option>
        </select>
      </div>

      <div class="filter-right">
        <div class="search-box">
          <component :is="Search" class="search-icon" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="搜索成员..."
            class="search-input"
          >
        </div>
      </div>
    </div>

    <!-- 债务关系列表 -->
    <div v-if="loading" class="loading-state">
      <div class="loading-spinner" />
      <p>加载中...</p>
    </div>

    <div v-else-if="filteredRelations.length === 0" class="empty-state">
      <component :is="Inbox" class="empty-icon" />
      <p class="empty-text">
        暂无债务关系
      </p>
      <p class="empty-hint">
        分摊记录产生后会自动生成债务关系
      </p>
      <button class="btn-primary mt-4" @click="handleSync">
        <component :is="RefreshCw" class="w-4 h-4" />
        <span>同步债务关系</span>
      </button>
    </div>

    <div v-else class="debt-list">
      <!-- 债务关系卡片 -->
      <div
        v-for="relation in paginatedRelations"
        :key="relation.serialNum"
        class="debt-card"
        :class="getRelationClass(relation)"
      >
        <div class="debt-card-header">
          <div class="debt-members">
            <!-- 债务人头像 -->
            <div class="member-avatar" :style="{ backgroundColor: getMemberColor(relation.debtorMemberSerialNum) }">
              {{ getInitials(relation.debtorMemberName) }}
            </div>

            <!-- 箭头 -->
            <div class="debt-arrow">
              <component :is="ArrowRight" class="w-5 h-5" />
            </div>

            <!-- 债权人头像 -->
            <div class="member-avatar" :style="{ backgroundColor: getMemberColor(relation.creditorMemberSerialNum) }">
              {{ getInitials(relation.creditorMemberName) }}
            </div>
          </div>

          <div class="debt-actions">
            <button
              class="icon-btn"
              title="查看详情"
              @click="viewRelationDetail(relation)"
            >
              <component :is="Eye" class="w-4 h-4" />
            </button>
            <button
              v-if="relation.status === 'active'"
              class="icon-btn"
              title="标记为已结算"
              @click="markAsSettled(relation)"
            >
              <component :is="CheckCircle2" class="w-4 h-4" />
            </button>
          </div>
        </div>

        <div class="debt-card-body">
          <div class="debt-description">
            <span class="debtor-name">{{ relation.debtorMemberName }}</span>
            <span class="debt-text">欠</span>
            <span class="creditor-name">{{ relation.creditorMemberName }}</span>
          </div>

          <div class="debt-amount">
            <span class="amount-value">¥{{ formatAmount(relation.amount) }}</span>
            <span class="amount-currency">{{ relation.currency }}</span>
          </div>

          <div class="debt-meta">
            <span class="meta-item">
              <component :is="Clock" class="w-3 h-3" />
              {{ formatTime(relation.lastCalculatedAt) }}
            </span>
            <span class="meta-item">
              <span class="status-badge" :class="`status-${relation.status}`">
                {{ getStatusText(relation.status) }}
              </span>
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="filteredRelations.length > pageSize" class="pagination">
      <button
        class="pagination-btn"
        :disabled="currentPage === 1"
        @click="currentPage--"
      >
        上一页
      </button>
      <span class="pagination-info">
        第 {{ currentPage }} / {{ totalPages }} 页，共 {{ filteredRelations.length }} 条
      </span>
      <button
        class="pagination-btn"
        :disabled="currentPage === totalPages"
        @click="currentPage++"
      >
        下一页
      </button>
    </div>
  </div>
</template>

<style scoped>
/* 页面布局 */
.debt-relation-view {
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
  flex: 1;
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

/* 统计卡片 */
.stats-cards {
  display: grid;
  grid-template-columns: repeat(1, minmax(0, 1fr));
  gap: 1rem;
}

@media (min-width: 768px) {
  .stats-cards {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (min-width: 1024px) {
  .stats-cards {
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
}

.stat-card {
  background-color: white;
  border-radius: 0.5rem;
  padding: 1.25rem;
  display: flex;
  align-items: center;
  gap: 1rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  transition: box-shadow 0.15s;
}

.stat-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

:global(.dark) .stat-card {
  background-color: #1f2937;
}

.stat-icon {
  width: 3rem;
  height: 3rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

.stat-card-red .stat-icon {
  background-color: #fee2e2;
  color: #dc2626;
}

:global(.dark) .stat-card-red .stat-icon {
  background-color: rgba(127, 29, 29, 0.3);
  color: #f87171;
}

.stat-card-green .stat-icon {
  background-color: #d1fae5;
  color: #059669;
}

:global(.dark) .stat-card-green .stat-icon {
  background-color: rgba(6, 95, 70, 0.3);
  color: #34d399;
}

.stat-card-blue .stat-icon {
  background-color: #dbeafe;
  color: #2563eb;
}

:global(.dark) .stat-card-blue .stat-icon {
  background-color: rgba(30, 58, 138, 0.3);
  color: #60a5fa;
}

.stat-card-gray .stat-icon {
  background-color: #f3f4f6;
  color: #4b5563;
}

:global(.dark) .stat-card-gray .stat-icon {
  background-color: #374151;
  color: #9ca3af;
}

.stat-content {
  flex: 1;
}

.stat-label {
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .stat-label {
  color: #9ca3af;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  color: #111827;
  margin-top: 0.25rem;
}

:global(.dark) .stat-value {
  color: #f3f4f6;
}

.stat-hint {
  font-size: 0.75rem;
  color: #6b7280;
  margin-top: 0.25rem;
}

/* 筛选栏 */
.filter-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  background-color: white;
  border-radius: 0.5rem;
  padding: 1rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

:global(.dark) .filter-bar {
  background-color: #1f2937;
}

.filter-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.filter-select {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background-color: white;
  color: #111827;
}

.filter-select:focus {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
  border-color: transparent;
}

:global(.dark) .filter-select {
  border-color: #4b5563;
  background-color: #374151;
  color: #f3f4f6;
}

.filter-right {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.search-box {
  position: relative;
}

.search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  width: 1rem;
  height: 1rem;
  color: #9ca3af;
}

.search-input {
  padding-left: 2.5rem;
  padding-right: 1rem;
  padding-top: 0.5rem;
  padding-bottom: 0.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background-color: white;
  color: #111827;
  width: 16rem;
}

.search-input:focus {
  outline: 2px solid #3b82f6;
  outline-offset: 2px;
  border-color: transparent;
}

:global(.dark) .search-input {
  border-color: #4b5563;
  background-color: #374151;
  color: #f3f4f6;
}

/* 加载状态 */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding-top: 5rem;
  padding-bottom: 5rem;
}

.loading-spinner {
  width: 3rem;
  height: 3rem;
  border: 4px solid #3b82f6;
  border-top-color: transparent;
  border-radius: 9999px;
  animation: spin 1s linear infinite;
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

/* 债务列表 */
.debt-list {
  display: grid;
  grid-template-columns: repeat(1, minmax(0, 1fr));
  gap: 1rem;
}

@media (min-width: 768px) {
  .debt-list {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (min-width: 1024px) {
  .debt-list {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

/* 债务卡片 */
.debt-card {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  transition: box-shadow 0.15s;
  border-left: 4px solid transparent;
}

.debt-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
}

:global(.dark) .debt-card {
  background-color: #1f2937;
}

.debt-card-debt {
  border-left-color: #ef4444;
}

.debt-card-credit {
  border-left-color: #10b981;
}

.debt-card-inactive {
  opacity: 0.5;
}

.debt-card-header {
  padding: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #e5e7eb;
}

:global(.dark) .debt-card-header {
  border-bottom-color: #374151;
}

.debt-members {
  display: flex;
  align-items: center;
  gap: 0.5rem;
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

.debt-arrow {
  color: #9ca3af;
}

.debt-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.debt-card-body {
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.debt-description {
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .debt-description {
  color: #9ca3af;
}

.debtor-name,
.creditor-name {
  font-weight: 500;
  color: #111827;
}

:global(.dark) .debtor-name,
:global(.dark) .creditor-name {
  color: #f3f4f6;
}

.debt-text {
  margin-left: 0.25rem;
  margin-right: 0.25rem;
}

.debt-amount {
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
}

.amount-value {
  font-size: 1.5rem;
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

.debt-meta {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 0.75rem;
  color: #6b7280;
}

.meta-item {
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.status-badge {
  padding: 0.25rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.status-active {
  background-color: #dbeafe;
  color: #1d4ed8;
}

:global(.dark) .status-active {
  background-color: rgba(30, 58, 138, 0.3);
  color: #93c5fd;
}

.status-settled {
  background-color: #f3f4f6;
  color: #374151;
}

:global(.dark) .status-settled {
  background-color: #374151;
  color: #d1d5db;
}

.status-cancelled {
  background-color: #fee2e2;
  color: #991b1b;
}

:global(.dark) .status-cancelled {
  background-color: rgba(127, 29, 29, 0.3);
  color: #fca5a5;
}

/* 分页 */
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  margin-top: 1.5rem;
}

.pagination-btn {
  padding: 0.5rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background-color: white;
  color: #111827;
  transition: background-color 0.15s;
}

.pagination-btn:hover:not(:disabled) {
  background-color: #f9fafb;
}

.pagination-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

:global(.dark) .pagination-btn {
  border-color: #4b5563;
  background-color: #1f2937;
  color: #f3f4f6;
}

:global(.dark) .pagination-btn:hover:not(:disabled) {
  background-color: #374151;
}

.pagination-info {
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .pagination-info {
  color: #9ca3af;
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

.btn-primary:hover {
  background-color: #1d4ed8;
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

.btn-secondary:hover {
  background-color: #e5e7eb;
}

:global(.dark) .btn-secondary {
  background-color: #374151;
  color: #f3f4f6;
}

:global(.dark) .btn-secondary:hover {
  background-color: #4b5563;
}

.icon-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  transition: background-color 0.15s, color 0.15s;
  color: #4b5563;
}

.icon-btn:hover {
  background-color: #f3f4f6;
  color: #111827;
}

:global(.dark) .icon-btn {
  color: #9ca3af;
}

:global(.dark) .icon-btn:hover {
  background-color: #374151;
  color: #f3f4f6;
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
