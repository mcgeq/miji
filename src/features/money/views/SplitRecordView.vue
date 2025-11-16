<script setup lang="ts">
import {
  LucideCalendar,
  LucideCheck,
  LucideClock,
  LucideDownload,
  LucideFilter,
  LucideSearch,
  LucideUsers,
} from 'lucide-vue-next';
import type { SplitRecord } from '@/schema/money';

// 搜索和筛选
const searchKeyword = ref('');
const filterStatus = ref<'all' | 'pending' | 'completed'>('all');
const filterMember = ref<string>('');
const dateRange = ref<{ start: string; end: string }>({
  start: '',
  end: '',
});

// 显示筛选器
const showFilters = ref(false);

// 加载状态
const loading = ref(true);

// 分摊记录列表
const splitRecords = ref<SplitRecord[]>([]);

// 加载分摊记录
onMounted(async () => {
  await loadSplitRecords();
});

async function loadSplitRecords() {
  loading.value = true;
  try {
    // TODO: 调用 API 获取分摊记录
    // const records = await splitStore.fetchSplitRecords();
    // splitRecords.value = records;

    // 临时模拟数据
    splitRecords.value = [];
  } catch (error) {
    console.error('Failed to load split records:', error);
  } finally {
    loading.value = false;
  }
}

// 筛选后的记录
const filteredRecords = computed(() => {
  let result = splitRecords.value;

  // 按关键词搜索
  if (searchKeyword.value) {
    const keyword = searchKeyword.value.toLowerCase();
    result = result.filter(record =>
      record.serialNum.toLowerCase().includes(keyword),
    );
  }

  // 按状态筛选
  if (filterStatus.value !== 'all') {
    result = result.filter(record => {
      const allPaid = record.splitDetails.every(d => d.isPaid);
      return filterStatus.value === 'completed' ? allPaid : !allPaid;
    });
  }

  // 按成员筛选
  if (filterMember.value) {
    result = result.filter(record =>
      record.splitDetails.some(d => d.memberSerialNum === filterMember.value),
    );
  }

  // 按日期范围筛选
  if (dateRange.value.start && dateRange.value.end) {
    result = result.filter(record => {
      const recordDate = new Date(record.createdAt);
      const startDate = new Date(dateRange.value.start);
      const endDate = new Date(dateRange.value.end);
      return recordDate >= startDate && recordDate <= endDate;
    });
  }

  return result;
});

// 统计信息
const statistics = computed(() => {
  const total = filteredRecords.value.length;
  const completed = filteredRecords.value.filter(r =>
    r.splitDetails.every(d => d.isPaid),
  ).length;
  const pending = total - completed;
  const totalAmount = filteredRecords.value.reduce((sum, r) => sum + r.totalAmount, 0);

  return {
    total,
    completed,
    pending,
    totalAmount,
  };
});

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 格式化日期
function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

// 获取记录状态
function getRecordStatus(record: SplitRecord): 'completed' | 'pending' {
  return record.splitDetails.every(d => d.isPaid) ? 'completed' : 'pending';
}

// 导出数据
function exportData() {
  // TODO: 实现导出功能
  // eslint-disable-next-line no-console
  console.log('Exporting data...');
}

// 查看详情
function viewDetail(record: SplitRecord) {
  // TODO: 打开详情弹窗
  // eslint-disable-next-line no-console
  console.log('View detail:', record);
}

// 重置筛选
function resetFilters() {
  searchKeyword.value = '';
  filterStatus.value = 'all';
  filterMember.value = '';
  dateRange.value = { start: '', end: '' };
}
</script>

<template>
  <div class="split-record-view">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-content">
        <h1>分摊记录</h1>
        <p class="header-description">
          查看和管理所有费用分摊记录
        </p>
      </div>

      <button class="btn-export" @click="exportData">
        <LucideDownload class="icon" />
        导出数据
      </button>
    </div>

    <!-- 统计卡片 -->
    <div class="statistics-grid">
      <div class="stat-card">
        <LucideUsers class="stat-icon" />
        <div class="stat-info">
          <label>总记录数</label>
          <strong>{{ statistics.total }}</strong>
        </div>
      </div>

      <div class="stat-card completed">
        <LucideCheck class="stat-icon" />
        <div class="stat-info">
          <label>已完成</label>
          <strong>{{ statistics.completed }}</strong>
        </div>
      </div>

      <div class="stat-card pending">
        <LucideClock class="stat-icon" />
        <div class="stat-info">
          <label>进行中</label>
          <strong>{{ statistics.pending }}</strong>
        </div>
      </div>

      <div class="stat-card amount">
        <LucideCalendar class="stat-icon" />
        <div class="stat-info">
          <label>总金额</label>
          <strong>{{ formatAmount(statistics.totalAmount) }}</strong>
        </div>
      </div>
    </div>

    <!-- 搜索和筛选栏 -->
    <div class="toolbar">
      <div class="search-box">
        <LucideSearch class="search-icon" />
        <input
          v-model="searchKeyword"
          type="text"
          placeholder="搜索分摊记录..."
          class="search-input"
        >
      </div>

      <button
        class="btn-filter"
        :class="{ active: showFilters }"
        @click="showFilters = !showFilters"
      >
        <LucideFilter class="icon" />
        筛选
        <span v-if="filterStatus !== 'all' || filterMember" class="filter-badge">
          {{ (filterStatus !== 'all' ? 1 : 0) + (filterMember ? 1 : 0) }}
        </span>
      </button>
    </div>

    <!-- 筛选面板 -->
    <div v-if="showFilters" class="filter-panel">
      <div class="filter-group">
        <label class="filter-label">状态</label>
        <select v-model="filterStatus" class="filter-select">
          <option value="all">
            全部
          </option>
          <option value="pending">
            进行中
          </option>
          <option value="completed">
            已完成
          </option>
        </select>
      </div>

      <div class="filter-group">
        <label class="filter-label">日期范围</label>
        <div class="date-range">
          <input
            v-model="dateRange.start"
            type="date"
            class="date-input"
          >
          <span>至</span>
          <input
            v-model="dateRange.end"
            type="date"
            class="date-input"
          >
        </div>
      </div>

      <div class="filter-actions">
        <button class="btn-reset" @click="resetFilters">
          重置
        </button>
      </div>
    </div>

    <!-- 记录列表 -->
    <div v-if="loading" class="loading-state">
      <div class="spinner" />
      <span>加载中...</span>
    </div>

    <div v-else-if="filteredRecords.length > 0" class="records-list">
      <div
        v-for="record in filteredRecords"
        :key="record.serialNum"
        class="record-card"
        @click="viewDetail(record)"
      >
        <div class="record-header">
          <div class="record-info">
            <h3 class="record-title">
              分摊记录
            </h3>
            <span class="record-date">{{ formatDate(record.createdAt) }}</span>
          </div>
          <div class="record-status" :class="getRecordStatus(record)">
            <component
              :is="getRecordStatus(record) === 'completed' ? LucideCheck : LucideClock"
              class="status-icon"
            />
            <span>{{ getRecordStatus(record) === 'completed' ? '已完成' : '进行中' }}</span>
          </div>
        </div>

        <div class="record-body">
          <div class="record-amount">
            <label>总金额</label>
            <strong>{{ formatAmount(record.totalAmount) }}</strong>
          </div>

          <div class="record-members">
            <label>参与成员</label>
            <div class="member-avatars">
              <div
                v-for="(detail, index) in record.splitDetails.slice(0, 3)"
                :key="detail.memberSerialNum"
                class="member-avatar"
                :style="{ zIndex: 10 - index }"
              >
                {{ detail.memberSerialNum.charAt(0) }}
              </div>
              <div v-if="record.splitDetails.length > 3" class="member-more">
                +{{ record.splitDetails.length - 3 }}
              </div>
            </div>
          </div>

          <div class="record-progress">
            <label>支付进度</label>
            <div class="progress-bar">
              <div
                class="progress-fill"
                :style="{
                  width: `${(record.splitDetails.filter(d => d.isPaid).length / record.splitDetails.length) * 100}%`,
                }"
              />
            </div>
            <span class="progress-text">
              {{ record.splitDetails.filter(d => d.isPaid).length }} / {{ record.splitDetails.length }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="empty-state">
      <LucideUsers class="empty-icon" />
      <p>暂无分摊记录</p>
      <span class="empty-hint">创建交易并启用分摊后，记录将显示在这里</span>
    </div>
  </div>
</template>

<style scoped>
.split-record-view {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}

/* Page Header */
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.header-content h1 {
  margin: 0 0 0.5rem 0;
  font-size: 1.75rem;
  font-weight: 600;
}

.header-description {
  margin: 0;
  color: var(--color-gray-600);
  font-size: 0.875rem;
}

.btn-export {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-export:hover {
  background: var(--color-primary-dark);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.btn-export .icon {
  width: 18px;
  height: 18px;
}

/* Statistics */
.statistics-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 1rem;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1.5rem;
  background: white;
  border-radius: 12px;
  border: 2px solid var(--color-base-300);
  box-shadow: var(--shadow-sm);
}

.stat-card.completed {
  background: #d1fae5;
  border-color: #059669;
}

.stat-card.pending {
  background: #fef3c7;
  border-color: #f59e0b;
}

.stat-card.amount {
  background: #dbeafe;
  border-color: #3b82f6;
}

.stat-icon {
  width: 32px;
  height: 32px;
  flex-shrink: 0;
}

.stat-card.completed .stat-icon {
  color: #059669;
}

.stat-card.pending .stat-icon {
  color: #f59e0b;
}

.stat-card.amount .stat-icon {
  color: #3b82f6;
}

.stat-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.stat-info label {
  font-size: 0.875rem;
  color: var(--color-gray-600);
}

.stat-info strong {
  font-size: 1.5rem;
  font-weight: 600;
}

/* Toolbar */
.toolbar {
  display: flex;
  gap: 1rem;
  align-items: center;
}

.search-box {
  flex: 1;
  position: relative;
}

.search-icon {
  position: absolute;
  left: 1rem;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--color-gray-400);
}

.search-input {
  width: 100%;
  padding: 0.75rem 1rem 0.75rem 3rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
}

.search-input:focus {
  outline: none;
  border-color: var(--color-primary);
}

.btn-filter {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-filter:hover,
.btn-filter.active {
  background: var(--color-base-200);
  border-color: var(--color-primary);
}

.btn-filter .icon {
  width: 18px;
  height: 18px;
}

.filter-badge {
  position: absolute;
  top: -0.5rem;
  right: -0.5rem;
  width: 20px;
  height: 20px;
  background: var(--color-primary);
  color: white;
  border-radius: 50%;
  font-size: 0.75rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Filter Panel */
.filter-panel {
  display: flex;
  gap: 1rem;
  padding: 1.5rem;
  background: white;
  border-radius: 12px;
  border: 1px solid var(--color-base-300);
}

.filter-group {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.filter-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-gray-700);
}

.filter-select,
.date-input {
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 0.875rem;
}

.date-range {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.filter-actions {
  display: flex;
  align-items: flex-end;
}

.btn-reset {
  padding: 0.5rem 1rem;
  background: transparent;
  border: 1px solid var(--color-base-300);
  border-radius: 6px;
  font-size: 0.875rem;
  cursor: pointer;
}

.btn-reset:hover {
  background: var(--color-base-200);
}

/* Loading */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 3rem 0;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-base-300);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Records List */
.records-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.record-card {
  padding: 1.5rem;
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.record-card:hover {
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
}

.record-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.record-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.record-title {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
}

.record-date {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

.record-status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 500;
}

.record-status.completed {
  background: #d1fae5;
  color: #065f46;
}

.record-status.pending {
  background: #fef3c7;
  color: #92400e;
}

.status-icon {
  width: 14px;
  height: 14px;
}

.record-body {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 1.5rem;
}

.record-amount label,
.record-members label,
.record-progress label {
  display: block;
  margin-bottom: 0.5rem;
  font-size: 0.75rem;
  color: var(--color-gray-600);
}

.record-amount strong {
  font-size: 1.25rem;
  font-weight: 600;
  color: var(--color-primary);
}

.member-avatars {
  display: flex;
  align-items: center;
}

.member-avatar {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--color-primary);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.875rem;
  font-weight: 600;
  border: 2px solid white;
  margin-left: -0.5rem;
}

.member-avatar:first-child {
  margin-left: 0;
}

.member-more {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--color-base-300);
  color: var(--color-gray-700);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  font-weight: 600;
  border: 2px solid white;
  margin-left: -0.5rem;
}

.progress-bar {
  height: 8px;
  background: var(--color-base-300);
  border-radius: 4px;
  overflow: hidden;
  margin-bottom: 0.5rem;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--color-primary), #10b981);
  border-radius: 4px;
  transition: width 0.3s;
}

.progress-text {
  font-size: 0.75rem;
  color: var(--color-gray-600);
}

/* Empty State */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  padding: 4rem 0;
  text-align: center;
}

.empty-icon {
  width: 64px;
  height: 64px;
  color: var(--color-gray-300);
}

.empty-state p {
  margin: 0;
  font-size: 1.125rem;
  color: var(--color-gray-600);
}

.empty-hint {
  font-size: 0.875rem;
  color: var(--color-gray-400);
}

/* Responsive */
@media (max-width: 768px) {
  .split-record-view {
    padding: 1rem;
  }

  .page-header {
    flex-direction: column;
    gap: 1rem;
  }

  .btn-export {
    width: 100%;
    justify-content: center;
  }

  .statistics-grid {
    grid-template-columns: repeat(2, 1fr);
  }

  .toolbar {
    flex-direction: column;
  }

  .filter-panel {
    flex-direction: column;
  }

  .record-body {
    grid-template-columns: 1fr;
  }
}
</style>
