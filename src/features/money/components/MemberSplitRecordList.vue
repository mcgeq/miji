<script setup lang="ts">
import { LucideCheck, LucideClock, LucideFilter, LucideX } from 'lucide-vue-next';
import type { SplitRecord } from '@/schema/money';

interface Props {
  memberSerialNum: string;
}

const props = defineProps<Props>();

const splitRecords = ref<SplitRecord[]>([]);
const loading = ref(true);
const filterStatus = ref<'all' | 'Pending' | 'Confirmed' | 'Settled'>('all');

// 加载分摊记录
onMounted(async () => {
  await loadSplitRecords();
});

async function loadSplitRecords() {
  loading.value = true;
  try {
    // TODO: 替换为实际API调用
    // await splitStore.fetchSplitRecords({ memberSerialNum: props.memberSerialNum });
    // splitRecords.value = splitStore.currentLedgerSplitRecords;

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

  if (filterStatus.value !== 'all') {
    result = result.filter(record =>
      record.splitDetails.some(detail =>
        detail.memberSerialNum === props.memberSerialNum &&
        (detail.isPaid ? 'Settled' : 'Pending') === filterStatus.value,
      ),
    );
  }

  return result;
});

// 格式化日期
function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
  });
}

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 获取该成员的分摊详情
function getMemberSplitDetail(record: SplitRecord) {
  return record.splitDetails.find(detail => detail.memberSerialNum === props.memberSerialNum);
}
</script>

<template>
  <div class="member-split-record-list">
    <!-- 工具栏 -->
    <div class="toolbar">
      <div class="filter-group">
        <LucideFilter class="filter-icon" />
        <select v-model="filterStatus" class="filter-select">
          <option value="all">
            全部状态
          </option>
          <option value="Pending">
            待支付
          </option>
          <option value="Confirmed">
            已确认
          </option>
          <option value="Settled">
            已结算
          </option>
        </select>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-state">
      <div class="spinner" />
      <span>加载中...</span>
    </div>

    <!-- 分摊记录列表 -->
    <div v-else-if="filteredRecords.length > 0" class="split-record-list">
      <div
        v-for="record in filteredRecords"
        :key="record.serialNum"
        class="split-record-item"
      >
        <div class="record-header">
          <div class="record-info">
            <h4 class="record-title">
              交易分摊
            </h4>
            <span class="record-date">{{ formatDate(record.createdAt || '') }}</span>
          </div>
          <div v-if="getMemberSplitDetail(record)" class="record-status">
            <component
              :is="getMemberSplitDetail(record)!.isPaid ? LucideCheck : LucideClock"
              class="status-icon"
            />
            <span class="status-label" :class="[getMemberSplitDetail(record)!.isPaid ? 'settled' : 'pending']">
              {{ getMemberSplitDetail(record)!.isPaid ? '已支付' : '待支付' }}
            </span>
          </div>
        </div>

        <div class="record-details">
          <div class="detail-row">
            <span class="detail-label">分摊总额:</span>
            <span class="detail-value">{{ formatAmount(record.totalAmount) }}</span>
          </div>

          <div v-if="getMemberSplitDetail(record)" class="detail-row highlight">
            <span class="detail-label">我的分摊:</span>
            <span class="detail-value amount">
              {{ formatAmount(getMemberSplitDetail(record)!.amount) }}
            </span>
          </div>

          <div class="detail-row">
            <span class="detail-label">分摊方式:</span>
            <span class="detail-value">均摊</span>
          </div>

          <div class="detail-row">
            <span class="detail-label">参与人数:</span>
            <span class="detail-value">{{ record.splitDetails.length }} 人</span>
          </div>
        </div>

        <div v-if="getMemberSplitDetail(record)?.isPaid" class="payment-info">
          <LucideCheck class="paid-icon" />
          <span>已支付</span>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-else class="empty-state">
      <LucideX class="empty-icon" />
      <p>暂无分摊记录</p>
      <span class="empty-hint">参与家庭账本的分摊后，记录将显示在这里</span>
    </div>

    <!-- 统计信息 -->
    <div v-if="!loading && filteredRecords.length > 0" class="summary">
      <div class="summary-item">
        <label>总记录数</label>
        <strong>{{ filteredRecords.length }}</strong>
      </div>
      <div class="summary-item">
        <label>总分摊金额</label>
        <strong class="amount">
          {{ formatAmount(filteredRecords.reduce((sum, r) => {
            const detail = getMemberSplitDetail(r);
            return sum + (detail?.amount || 0);
          }, 0)) }}
        </strong>
      </div>
    </div>
  </div>
</template>

<style scoped>
.member-split-record-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* 工具栏 */
.toolbar {
  display: flex;
  justify-content: flex-end;
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.filter-icon {
  width: 18px;
  height: 18px;
  color: var(--color-gray-500);
}

.filter-select {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.filter-select:hover {
  border-color: var(--color-primary);
}

/* 加载状态 */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 0;
  color: var(--color-gray-500);
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

/* 分摊记录列表 */
.split-record-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.split-record-item {
  padding: 1.25rem;
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 12px;
  transition: all 0.2s;
}

.split-record-item:hover {
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
}

.record-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  padding-bottom: 0.75rem;
  border-bottom: 1px solid var(--color-base-200);
}

.record-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.record-title {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
}

.record-date {
  font-size: 0.875rem;
  color: var(--color-gray-500);
}

.record-status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.status-icon {
  width: 16px;
  height: 16px;
}

.status-label {
  font-size: 0.875rem;
  font-weight: 500;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
}

.status-label.pending {
  background: #fef3c7;
  color: #92400e;
}

.status-label.confirmed {
  background: #dbeafe;
  color: #1e40af;
}

.status-label.settled {
  background: #d1fae5;
  color: #065f46;
}

.record-details {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.875rem;
}

.detail-row.highlight {
  padding: 0.75rem;
  background: var(--color-base-100);
  border-radius: 6px;
  font-weight: 500;
}

.detail-label {
  color: var(--color-gray-600);
}

.detail-value {
  color: var(--color-gray-900);
}

.detail-value.amount {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-primary);
}

.payment-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-top: 1rem;
  padding: 0.75rem;
  background: #d1fae5;
  border-radius: 6px;
  color: #065f46;
  font-size: 0.875rem;
  font-weight: 500;
}

.paid-icon {
  width: 16px;
  height: 16px;
}

/* 空状态 */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
  padding: 3rem 0;
  text-align: center;
}

.empty-icon {
  width: 48px;
  height: 48px;
  color: var(--color-gray-300);
}

.empty-state p {
  margin: 0;
  font-size: 1rem;
  color: var(--color-gray-600);
}

.empty-hint {
  font-size: 0.875rem;
  color: var(--color-gray-400);
}

/* 统计信息 */
.summary {
  display: flex;
  gap: 2rem;
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 8px;
}

.summary-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.summary-item label {
  font-size: 0.875rem;
  color: var(--color-gray-500);
}

.summary-item strong {
  font-size: 1.25rem;
  font-weight: 600;
}

.summary-item .amount {
  color: var(--color-primary);
}

/* 响应式 */
@media (max-width: 768px) {
  .record-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .summary {
    flex-direction: column;
    gap: 1rem;
  }
}
</style>
