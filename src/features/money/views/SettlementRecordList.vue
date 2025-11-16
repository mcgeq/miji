<script setup lang="ts">
import {
  CheckCircle2,
  Clock,
  DollarSign,
  Download,
  FileText,
  Inbox,
  Plus,
  Search,
} from 'lucide-vue-next';
import { useRouter } from 'vue-router';
import { settlementRecordService } from '@/services/money/settlement-record';
import { toast } from '@/utils/toast';
import type { SettlementRecord } from '@/services/money/settlement-record';

interface Statistics {
  totalCount: number;
  completedCount: number;
  pendingCount: number;
  totalAmount: number;
}

const router = useRouter();
const records = ref<SettlementRecord[]>([]);
const loading = ref(false);
const searchQuery = ref('');

// 当前账本
const currentLedgerSerialNum = ref('FL001'); // TODO: 从store获取

const filters = ref({
  status: 'all',
  type: 'all',
});

const currentPage = ref(1);
const pageSize = 10;

const statistics = computed<Statistics>(() => ({
  totalCount: records.value.length,
  completedCount: records.value.filter(r => r.status === 'completed').length,
  pendingCount: records.value.filter(r => r.status === 'pending').length,
  totalAmount: records.value
    .filter(r => r.status === 'completed')
    .reduce((sum, r) => sum + r.totalAmount, 0),
}));

const filteredRecords = computed(() => {
  let result = [...records.value];
  if (filters.value.status !== 'all') {
    result = result.filter(r => r.status === filters.value.status);
  }
  if (filters.value.type !== 'all') {
    result = result.filter(r => r.settlementType === filters.value.type);
  }
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    result = result.filter(r => r.serialNum.toLowerCase().includes(query));
  }
  return result.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
});

const paginatedRecords = computed(() => {
  const start = (currentPage.value - 1) * pageSize;
  return filteredRecords.value.slice(start, start + pageSize);
});

const totalPages = computed(() => Math.ceil(filteredRecords.value.length / pageSize));

async function loadData() {
  loading.value = true;
  try {
    const result = await settlementRecordService.listRecords({
      familyLedgerSerialNum: currentLedgerSerialNum.value,
      status: filters.value.status === 'all' ? undefined : filters.value.status as any,
      settlementType: filters.value.type === 'all' ? undefined : filters.value.type as any,
    });
    records.value = result.rows || [];
  } catch (error) {
    console.error('加载失败:', error);
    toast.error('加载失败');
  } finally {
    loading.value = false;
  }
}

function handleNewSettlement() {
  router.push('/money/settlement-suggestion');
}

function handleViewDetail(record: SettlementRecord) {
  // eslint-disable-next-line no-console
  console.log('查看详情:', record);
}

async function handleExport() {
  try {
    const result = await settlementRecordService.exportRecords(
      {
        familyLedgerSerialNum: currentLedgerSerialNum.value,
      },
      'excel',
    );
    // TODO: 处理下载文件
    // eslint-disable-next-line no-console
    console.log('Export result:', result);
    toast.success('导出成功');
  } catch (error) {
    console.error('导出失败:', error);
    toast.error('导出功能开发中...');
  }
}

function getTypeText(type: string): string {
  const map: Record<string, string> = {
    manual: '手动结算',
    auto: '自动结算',
    optimized: '优化结算',
  };
  return map[type] || type;
}

function getStatusText(status: string): string {
  const map: Record<string, string> = {
    pending: '待确认',
    completed: '已完成',
    cancelled: '已取消',
  };
  return map[status] || status;
}

function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return `${date.getMonth() + 1}/${date.getDate()}`;
}

function formatTime(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const days = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));
  if (days === 0) return '今天';
  if (days === 1) return '昨天';
  if (days < 7) return `${days}天前`;
  return date.toLocaleDateString();
}

onMounted(() => {
  loadData();
});
</script>

<template>
  <div class="settlement-record-list">
    <!-- 页面标题 -->
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">
          结算记录
        </h1>
        <p class="page-subtitle">
          查看和管理历史结算记录
        </p>
      </div>
      <div class="header-right">
        <button class="btn-secondary" @click="handleExport">
          <component :is="Download" class="w-4 h-4" />
          <span>导出</span>
        </button>
        <button class="btn-primary" @click="handleNewSettlement">
          <component :is="Plus" class="w-4 h-4" />
          <span>新建结算</span>
        </button>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-section">
      <div class="stat-card">
        <div class="stat-icon stat-icon-total">
          <component :is="FileText" class="w-6 h-6" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            总结算次数
          </div>
          <div class="stat-value">
            {{ statistics.totalCount }}
          </div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon stat-icon-completed">
          <component :is="CheckCircle2" class="w-6 h-6" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            已完成
          </div>
          <div class="stat-value">
            {{ statistics.completedCount }}
          </div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon stat-icon-pending">
          <component :is="Clock" class="w-4 h-4" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            待确认
          </div>
          <div class="stat-value">
            {{ statistics.pendingCount }}
          </div>
        </div>
      </div>

      <div class="stat-card">
        <div class="stat-icon stat-icon-amount">
          <component :is="DollarSign" class="w-6 h-6" />
        </div>
        <div class="stat-content">
          <div class="stat-label">
            累计结算金额
          </div>
          <div class="stat-value">
            ¥{{ formatAmount(statistics.totalAmount) }}
          </div>
        </div>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div class="filter-bar">
      <div class="filter-left">
        <select v-model="filters.status" class="filter-select">
          <option value="all">
            全部状态
          </option>
          <option value="pending">
            待确认
          </option>
          <option value="completed">
            已完成
          </option>
          <option value="cancelled">
            已取消
          </option>
        </select>

        <select v-model="filters.type" class="filter-select">
          <option value="all">
            全部类型
          </option>
          <option value="manual">
            手动结算
          </option>
          <option value="auto">
            自动结算
          </option>
          <option value="optimized">
            优化结算
          </option>
        </select>
      </div>

      <div class="filter-right">
        <div class="search-box">
          <component :is="Search" class="search-icon" />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="搜索..."
            class="search-input"
          >
        </div>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-state">
      <div class="loading-spinner" />
      <p>加载中...</p>
    </div>

    <!-- 空状态 -->
    <div v-else-if="filteredRecords.length === 0" class="empty-state">
      <component :is="Inbox" class="empty-icon" />
      <p class="empty-text">
        暂无结算记录
      </p>
      <p class="empty-hint">
        创建第一笔结算记录吧
      </p>
    </div>

    <!-- 结算记录列表 -->
    <div v-else class="records-list">
      <div
        v-for="record in paginatedRecords"
        :key="record.serialNum"
        class="record-card"
        @click="handleViewDetail(record)"
      >
        <div class="record-header">
          <div class="record-info">
            <div class="record-title">
              {{ getTypeText(record.settlementType) }}
            </div>
            <div class="record-period">
              {{ formatDate(record.periodStart) }} ~ {{ formatDate(record.periodEnd) }}
            </div>
          </div>
          <span class="status-badge" :class="`status-${record.status}`">
            {{ getStatusText(record.status) }}
          </span>
        </div>

        <div class="record-body">
          <div class="record-detail">
            <div class="detail-item">
              <span class="detail-label">结算金额</span>
              <span class="detail-value">¥{{ formatAmount(record.totalAmount) }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">参与成员</span>
              <span class="detail-value">{{ record.participantMembers.length }}人</span>
            </div>
          </div>
        </div>

        <div class="record-footer">
          <span class="footer-info">发起人: {{ record.initiatedBy }}</span>
          <span class="footer-info">{{ formatTime(record.createdAt) }}</span>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="filteredRecords.length > pageSize" class="pagination">
      <button class="pagination-btn" :disabled="currentPage === 1" @click="currentPage--">
        上一页
      </button>
      <span class="pagination-info">
        第 {{ currentPage }} / {{ totalPages }} 页
      </span>
      <button class="pagination-btn" :disabled="currentPage === totalPages" @click="currentPage++">
        下一页
      </button>
    </div>
  </div>
</template>

<style scoped>
.settlement-record-list {
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
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
  gap: 0.75rem;
}

.stats-section {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1rem;
}

.stat-card {
  background: white;
  padding: 1.25rem;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  display: flex;
  align-items: center;
  gap: 1rem;
}

:global(.dark) .stat-card {
  background: #1f2937;
}

.stat-icon {
  width: 3rem;
  height: 3rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

.stat-icon-total {
  background: #dbeafe;
  color: #2563eb;
}

:global(.dark) .stat-icon-total {
  background: rgba(30,58,138,0.3);
  color: #60a5fa;
}

.stat-icon-completed {
  background: #d1fae5;
  color: #059669;
}

:global(.dark) .stat-icon-completed {
  background: rgba(6,95,70,0.3);
  color: #34d399;
}

.stat-icon-pending {
  background: #fef3c7;
  color: #d97706;
}

:global(.dark) .stat-icon-pending {
  background: rgba(120,53,15,0.3);
  color: #fbbf24;
}

.stat-icon-amount {
  background: #f3e8ff;
  color: #9333ea;
}

:global(.dark) .stat-icon-amount {
  background: rgba(107,33,168,0.3);
  color: #c084fc;
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

.filter-bar {
  background: white;
  padding: 1rem;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  display: flex;
  justify-content: space-between;
  gap: 1rem;
}

:global(.dark) .filter-bar {
  background: #1f2937;
}

.filter-left {
  display: flex;
  gap: 0.75rem;
}

.filter-select {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background: white;
  color: #111827;
}

:global(.dark) .filter-select {
  background: #374151;
  border-color: #4b5563;
  color: #f3f4f6;
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
  padding: 0.5rem 0.75rem 0.5rem 2.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background: white;
  color: #111827;
  width: 16rem;
}

:global(.dark) .search-input {
  background: #374151;
  border-color: #4b5563;
  color: #f3f4f6;
}

.loading-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 5rem 0;
  background: white;
  border-radius: 0.5rem;
}

:global(.dark) .loading-state,
:global(.dark) .empty-state {
  background: #1f2937;
}

.loading-spinner {
  width: 3rem;
  height: 3rem;
  border: 4px solid #3b82f6;
  border-top-color: transparent;
  border-radius: 9999px;
  animation: spin 1s linear infinite;
}

.empty-icon {
  width: 4rem;
  height: 4rem;
  color: #9ca3af;
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

.records-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.record-card {
  background: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  cursor: pointer;
  transition: all 0.2s;
}

.record-card:hover {
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
  transform: translateY(-2px);
}

:global(.dark) .record-card {
  background: #1f2937;
}

.record-header {
  padding: 1rem 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid #e5e7eb;
  background: #f9fafb;
}

:global(.dark) .record-header {
  border-color: #374151;
  background: rgba(17,24,39,0.5);
}

.record-title {
  font-weight: 600;
  color: #111827;
}

:global(.dark) .record-title {
  color: #f3f4f6;
}

.record-period {
  font-size: 0.875rem;
  color: #6b7280;
  margin-top: 0.25rem;
}

.status-badge {
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.status-pending {
  background: #fef3c7;
  color: #92400e;
}

:global(.dark) .status-pending {
  background: rgba(120,53,15,0.3);
  color: #fcd34d;
}

.status-completed {
  background: #d1fae5;
  color: #065f46;
}

:global(.dark) .status-completed {
  background: rgba(6,95,70,0.3);
  color: #6ee7b7;
}

.status-cancelled {
  background: #fee2e2;
  color: #991b1b;
}

:global(.dark) .status-cancelled {
  background: rgba(127,29,29,0.3);
  color: #fca5a5;
}

.record-body {
  padding: 1rem 1.5rem;
}

.record-detail {
  display: flex;
  gap: 2rem;
}

.detail-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.detail-label {
  font-size: 0.75rem;
  color: #6b7280;
}

.detail-value {
  font-size: 1.125rem;
  font-weight: 600;
  color: #111827;
}

:global(.dark) .detail-value {
  color: #f3f4f6;
}

.record-footer {
  padding: 0.75rem 1.5rem;
  display: flex;
  justify-content: space-between;
  border-top: 1px solid #e5e7eb;
  font-size: 0.875rem;
  color: #6b7280;
}

:global(.dark) .record-footer {
  border-color: #374151;
}

.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
}

.pagination-btn {
  padding: 0.5rem 1rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  background: white;
  color: #111827;
  cursor: pointer;
}

.pagination-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

:global(.dark) .pagination-btn {
  background: #1f2937;
  border-color: #4b5563;
  color: #f3f4f6;
}

.pagination-info {
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .pagination-info {
  color: #9ca3af;
}

.btn-primary {
  padding: 0.5rem 1rem;
  background: #2563eb;
  color: white;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  border: none;
}

.btn-primary:hover {
  background: #1d4ed8;
}

.btn-secondary {
  padding: 0.5rem 1rem;
  background: #f3f4f6;
  color: #111827;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  border: none;
}

.btn-secondary:hover {
  background: #e5e7eb;
}

:global(.dark) .btn-secondary {
  background: #374151;
  color: #f3f4f6;
}

:global(.dark) .btn-secondary:hover {
  background: #4b5563;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}
</style>
