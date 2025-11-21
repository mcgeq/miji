<script setup lang="ts">
import {
  LucideCheck,
  LucideClock,
  LucideCoins,
  LucideEqual,
  LucidePercent,
  LucideScale,
  LucideUsers,
} from 'lucide-vue-next';
import BaseModal from '@/components/common/BaseModal.vue';
import type { SplitRuleType } from '@/schema/money';

interface SplitDetail {
  memberSerialNum: string;
  memberName: string;
  amount: number;
  isPaid: boolean;
  percentage?: number;
  paidAt?: string;
}

interface Props {
  transactionSerialNum: string;
  transactionAmount: number;
  splitType: SplitRuleType;
  splitDetails: SplitDetail[];
  transactionDate?: string;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  updateStatus: [memberSerialNum: string, isPaid: boolean];
}>();

// 获取分摊类型信息
const splitTypeInfo = computed(() => {
  const typeMap = {
    EQUAL: {
      label: '均等分摊',
      icon: LucideEqual,
      color: '#3b82f6',
      description: '所有成员平均分摊费用',
    },
    PERCENTAGE: {
      label: '按比例分摊',
      icon: LucidePercent,
      color: '#10b981',
      description: '根据设定的比例分摊费用',
    },
    FIXED_AMOUNT: {
      label: '固定金额',
      icon: LucideCoins,
      color: '#f59e0b',
      description: '为每个成员指定固定的分摊金额',
    },
    WEIGHTED: {
      label: '按权重分摊',
      icon: LucideScale,
      color: '#8b5cf6',
      description: '根据权重比例分摊费用',
    },
  };
  return typeMap[props.splitType] || typeMap.EQUAL;
});

// 统计信息
const statistics = computed(() => {
  const total = props.splitDetails.length;
  const paid = props.splitDetails.filter(d => d.isPaid).length;
  const unpaid = total - paid;
  const totalAmount = props.splitDetails.reduce((sum, d) => sum + d.amount, 0);
  const paidAmount = props.splitDetails.filter(d => d.isPaid).reduce((sum, d) => sum + d.amount, 0);
  const unpaidAmount = totalAmount - paidAmount;

  return {
    total,
    paid,
    unpaid,
    totalAmount,
    paidAmount,
    unpaidAmount,
    paidPercentage: total > 0 ? (paid / total) * 100 : 0,
  };
});

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 格式化日期
function formatDate(dateStr?: string): string {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

// 切换支付状态
function togglePaymentStatus(detail: SplitDetail) {
  emit('updateStatus', detail.memberSerialNum, !detail.isPaid);
}

// 关闭
function close() {
  emit('close');
}
</script>

<template>
  <BaseModal
    title="分摊详情"
    size="lg"
    :show-footer="false"
    @close="close"
  >
    <div>
      <!-- 统计卡片 -->
      <div class="statistics-grid">
        <div class="stat-card">
          <LucideUsers class="stat-icon" />
          <div class="stat-info">
            <label>参与人数</label>
            <strong>{{ statistics.total }} 人</strong>
          </div>
        </div>

        <div class="stat-card paid">
          <LucideCheck class="stat-icon" />
          <div class="stat-info">
            <label>已支付</label>
            <strong>{{ statistics.paid }} 人</strong>
          </div>
        </div>

        <div class="stat-card unpaid">
          <LucideClock class="stat-icon" />
          <div class="stat-info">
            <label>待支付</label>
            <strong>{{ statistics.unpaid }} 人</strong>
          </div>
        </div>

        <div class="stat-card amount">
          <LucideCoins class="stat-icon" />
          <div class="stat-info">
            <label>总金额</label>
            <strong>{{ formatAmount(statistics.totalAmount) }}</strong>
          </div>
        </div>
      </div>

      <!-- 进度条 -->
      <div class="progress-section">
        <div class="progress-header">
          <span>支付进度</span>
          <span class="progress-text">{{ statistics.paidPercentage.toFixed(0) }}%</span>
        </div>
        <div class="progress-bar">
          <div
            class="progress-fill"
            :style="{ width: `${statistics.paidPercentage}%` }"
          />
        </div>
        <div class="progress-amounts">
          <span class="amount-paid">已支付: {{ formatAmount(statistics.paidAmount) }}</span>
          <span class="amount-unpaid">待支付: {{ formatAmount(statistics.unpaidAmount) }}</span>
        </div>
      </div>

      <!-- 分摊明细列表 -->
      <div class="details-section">
        <h4 class="section-title">
          分摊明细
        </h4>

        <div class="details-list">
          <div
            v-for="detail in splitDetails"
            :key="detail.memberSerialNum"
            class="detail-item"
            :class="{ paid: detail.isPaid }"
          >
            <div class="detail-header">
              <div class="member-info">
                <div class="member-avatar">
                  {{ detail.memberName.charAt(0) }}
                </div>
                <div class="member-details">
                  <span class="member-name">{{ detail.memberName }}</span>
                  <span v-if="detail.percentage" class="member-percentage">
                    {{ detail.percentage.toFixed(1) }}%
                  </span>
                </div>
              </div>

              <div class="detail-status">
                <strong class="detail-amount">{{ formatAmount(detail.amount) }}</strong>
                <button
                  class="status-badge"
                  :class="{ paid: detail.isPaid }"
                  @click="togglePaymentStatus(detail)"
                >
                  <component :is="detail.isPaid ? LucideCheck : LucideClock" class="status-icon" />
                  <span>{{ detail.isPaid ? '已支付' : '待支付' }}</span>
                </button>
              </div>
            </div>

            <div v-if="detail.isPaid && detail.paidAt" class="detail-footer">
              <span class="paid-date">支付时间: {{ formatDate(detail.paidAt) }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- 交易信息 -->
      <div class="transaction-info">
        <div class="info-row">
          <label>交易金额</label>
          <strong>{{ formatAmount(transactionAmount) }}</strong>
        </div>
        <div v-if="transactionDate" class="info-row">
          <label>交易日期</label>
          <span>{{ formatDate(transactionDate) }}</span>
        </div>
        <div class="info-row">
          <label>分摊方式</label>
          <span>{{ splitTypeInfo.description }}</span>
        </div>
      </div>
    </div>
  </BaseModal>
</template>

<style scoped>
.split-detail-modal {
  position: fixed;
  inset: 0;
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-overlay {
  position: absolute;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
}

.modal-container {
  position: relative;
  width: 90%;
  max-width: 700px;
  max-height: 90vh;
  background: white;
  border-radius: 16px;
  box-shadow: 0 20px 25px -5px rgb(0 0 0 / 0.1);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* Header */
.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 1.5rem;
  border-bottom: 1px solid var(--color-base-200);
  background: var(--color-base-100);
}

.header-content {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.header-content h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.split-type-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: var(--type-color);
  color: white;
  border-radius: 20px;
  font-size: 0.875rem;
  font-weight: 500;
}

.type-icon {
  width: 16px;
  height: 16px;
}

.btn-close {
  padding: 0.5rem;
  background: transparent;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-close:hover {
  background: var(--color-base-200);
}

.btn-close .icon {
  width: 20px;
  height: 20px;
}

/* Content */
.modal-content {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
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
  gap: 0.75rem;
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 12px;
  border: 2px solid var(--color-base-300);
}

.stat-card.paid {
  background: #d1fae5;
  border-color: #059669;
}

.stat-card.unpaid {
  background: #fef3c7;
  border-color: #f59e0b;
}

.stat-card.amount {
  background: #dbeafe;
  border-color: #3b82f6;
}

.stat-icon {
  width: 24px;
  height: 24px;
  flex-shrink: 0;
}

.stat-card.paid .stat-icon {
  color: #059669;
}

.stat-card.unpaid .stat-icon {
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
  font-size: 0.75rem;
  color: var(--color-gray-600);
}

.stat-info strong {
  font-size: 1rem;
  font-weight: 600;
}

/* Progress */
.progress-section {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 12px;
}

.progress-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.875rem;
  font-weight: 500;
}

.progress-text {
  color: var(--color-primary);
  font-weight: 600;
}

.progress-bar {
  height: 12px;
  background: var(--color-base-300);
  border-radius: 6px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--color-primary), #10b981);
  border-radius: 6px;
  transition: width 0.3s ease;
}

.progress-amounts {
  display: flex;
  justify-content: space-between;
  font-size: 0.75rem;
}

.amount-paid {
  color: #059669;
}

.amount-unpaid {
  color: #f59e0b;
}

/* Details */
.details-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.section-title {
  margin: 0;
  font-size: 1rem;
  font-weight: 600;
}

.details-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.detail-item {
  padding: 1rem;
  background: white;
  border: 2px solid var(--color-base-300);
  border-radius: 12px;
  transition: all 0.2s;
}

.detail-item.paid {
  border-color: #059669;
  background: #f0fdf4;
}

.detail-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
}

.member-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.member-avatar {
  width: 40px;
  height: 40px;
  border-radius: 50%;
  background: var(--color-primary);
  color: white;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 1rem;
}

.member-details {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.member-name {
  font-size: 0.875rem;
  font-weight: 500;
}

.member-percentage {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

.detail-status {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.detail-amount {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-primary);
}

.status-badge {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: #fef3c7;
  border: 1px solid #f59e0b;
  color: #92400e;
  border-radius: 20px;
  font-size: 0.75rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.status-badge:hover {
  background: #fde68a;
}

.status-badge.paid {
  background: #d1fae5;
  border-color: #059669;
  color: #065f46;
}

.status-badge.paid:hover {
  background: #a7f3d0;
}

.status-icon {
  width: 14px;
  height: 14px;
}

.detail-footer {
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--color-base-200);
}

.paid-date {
  font-size: 0.75rem;
  color: var(--color-gray-500);
}

/* Transaction Info */
.transaction-info {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 12px;
}

.info-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.875rem;
}

.info-row label {
  color: var(--color-gray-600);
}

.info-row strong {
  font-weight: 600;
  color: var(--color-gray-900);
}

/* Footer */
.modal-footer {
  padding: 1.5rem;
  border-top: 1px solid var(--color-base-200);
  background: var(--color-base-100);
}

.btn-close-footer {
  width: 100%;
  padding: 0.75rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-close-footer:hover {
  background: var(--color-primary-dark);
}

/* Responsive */
@media (max-width: 768px) {
  .modal-container {
    width: 100%;
    max-width: 100%;
    height: 100vh;
    max-height: 100vh;
    border-radius: 0;
  }

  .statistics-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>
