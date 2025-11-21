<script setup lang="ts">
import {
  ArrowRight,
  ArrowRightLeft,
  DollarSign,
  Users,
} from 'lucide-vue-next';
import BaseModal from '@/components/common/BaseModal.vue';

// ==================== Props & Emits ====================

interface TransferSuggestion {
  from: string;
  fromName: string;
  to: string;
  toName: string;
  amount: number;
  currency: string;
}

interface SettlementRecord {
  serialNum: string;
  familyLedgerSerialNum: string;
  settlementType: 'manual' | 'auto' | 'optimized';
  periodStart: string;
  periodEnd: string;
  totalAmount: number;
  currency: string;
  participantMembers: string[];
  settlementDetails: any;
  optimizedTransfers: any;
  status: 'pending' | 'completed' | 'cancelled';
  initiatedBy: string;
  completedBy?: string;
  completedAt?: string;
  createdAt: string;
}

interface Props {
  record: SettlementRecord;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  close: [];
}>();

// ==================== 计算属性 ====================

const optimizedTransfers = computed<TransferSuggestion[]>(() => {
  if (Array.isArray(props.record.optimizedTransfers)) {
    return props.record.optimizedTransfers;
  }
  return [];
});

// ==================== 方法 ====================

function handleClose() {
  emit('close');
}

function getTypeText(type: string): string {
  const typeMap: Record<string, string> = {
    manual: '手动结算',
    auto: '自动结算',
    optimized: '优化结算',
  };
  return typeMap[type] || type;
}

function getMemberColor(memberName: string): string {
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
  const index = memberName.charCodeAt(0) % colors.length;
  return colors[index];
}

function getInitials(name: string): string {
  return name.charAt(0).toUpperCase();
}

function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString('zh-CN');
}

function formatDateTime(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleString('zh-CN');
}
</script>

<template>
  <BaseModal
    title="结算详情"
    size="lg"
    :show-footer="false"
    @close="handleClose"
  >
    <div>
      <!-- 基本信息 -->
      <div class="info-section">
        <h3 class="section-title">
          基本信息
        </h3>
        <div class="info-grid">
          <div class="info-item">
            <span class="info-label">结算序号</span>
            <span class="info-value">{{ record.serialNum }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">结算类型</span>
            <span class="info-value">{{ getTypeText(record.settlementType) }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">结算周期</span>
            <span class="info-value">
              {{ formatDate(record.periodStart) }} ~ {{ formatDate(record.periodEnd) }}
            </span>
          </div>
          <div class="info-item">
            <span class="info-label">结算金额</span>
            <span class="info-value amount">¥{{ formatAmount(record.totalAmount) }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">发起人</span>
            <span class="info-value">{{ record.initiatedBy }}</span>
          </div>
          <div class="info-item">
            <span class="info-label">发起时间</span>
            <span class="info-value">{{ formatDateTime(record.createdAt) }}</span>
          </div>
          <div v-if="record.completedAt" class="info-item">
            <span class="info-label">完成时间</span>
            <span class="info-value">{{ formatDateTime(record.completedAt) }}</span>
          </div>
          <div v-if="record.completedBy" class="info-item">
            <span class="info-label">完成人</span>
            <span class="info-value">{{ record.completedBy }}</span>
          </div>
        </div>
      </div>

      <!-- 参与成员 -->
      <div class="members-section">
        <h3 class="section-title">
          参与成员
          <span class="count-badge">{{ record.participantMembers.length }}人</span>
        </h3>
        <div class="members-grid">
          <div
            v-for="(member, index) in record.participantMembers"
            :key="index"
            class="member-card"
          >
            <div
              class="member-avatar"
              :style="{ backgroundColor: getMemberColor(member) }"
            >
              {{ getInitials(member) }}
            </div>
            <span class="member-name">{{ member }}</span>
          </div>
        </div>
      </div>

      <!-- 转账明细 -->
      <div v-if="optimizedTransfers.length > 0" class="transfers-section">
        <h3 class="section-title">
          转账明细
          <span class="count-badge">{{ optimizedTransfers.length }}笔</span>
        </h3>
        <div class="transfers-list">
          <div
            v-for="(transfer, index) in optimizedTransfers"
            :key="index"
            class="transfer-item"
          >
            <div class="transfer-index">
              {{ index + 1 }}
            </div>
            <div class="transfer-content">
              <div class="transfer-members">
                <div class="transfer-member">
                  <div
                    class="mini-avatar"
                    :style="{ backgroundColor: getMemberColor(transfer.fromName) }"
                  >
                    {{ getInitials(transfer.fromName) }}
                  </div>
                  <span>{{ transfer.fromName }}</span>
                </div>
                <component :is="ArrowRight" class="arrow-icon" />
                <div class="transfer-member">
                  <div
                    class="mini-avatar"
                    :style="{ backgroundColor: getMemberColor(transfer.toName) }"
                  >
                    {{ getInitials(transfer.toName) }}
                  </div>
                  <span>{{ transfer.toName }}</span>
                </div>
              </div>
              <div class="transfer-amount">
                ¥{{ formatAmount(transfer.amount) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 统计信息 -->
      <div class="stats-section">
        <div class="stat-card">
          <component :is="Users" class="stat-icon" />
          <div class="stat-content">
            <span class="stat-label">参与成员</span>
            <span class="stat-value">{{ record.participantMembers.length }}人</span>
          </div>
        </div>
        <div class="stat-card">
          <component :is="ArrowRightLeft" class="stat-icon" />
          <div class="stat-content">
            <span class="stat-label">转账次数</span>
            <span class="stat-value">{{ optimizedTransfers.length }}笔</span>
          </div>
        </div>
        <div class="stat-card">
          <component :is="DollarSign" class="stat-icon" />
          <div class="stat-content">
            <span class="stat-label">结算金额</span>
            <span class="stat-value">¥{{ formatAmount(record.totalAmount) }}</span>
          </div>
        </div>
      </div>
    </div>
  </BaseModal>
</template>

<style scoped>
/* 模态框遮罩 */
.modal-overlay {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  padding: 1rem;
}

/* 模态框容器 */
.modal-container {
  background-color: white;
  border-radius: 0.75rem;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
  max-width: 48rem;
  width: 100%;
  max-height: 90vh;
  display: flex;
  flex-direction: column;
}

:global(.dark) .modal-container {
  background-color: #1f2937;
}

/* 模态框头部 */
.modal-header {
  padding: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #e5e7eb;
}

:global(.dark) .modal-header {
  border-bottom-color: #374151;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.modal-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .modal-title {
  color: #f3f4f6;
}

.close-btn {
  padding: 0.5rem;
  border-radius: 0.375rem;
  color: #6b7280;
  transition: background-color 0.15s;
}

.close-btn:hover {
  background-color: #f3f4f6;
}

:global(.dark) .close-btn:hover {
  background-color: #374151;
}

/* 状态徽章 */
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

.status-completed {
  background-color: #d1fae5;
  color: #065f46;
}

:global(.dark) .status-completed {
  background-color: rgba(6, 95, 70, 0.3);
  color: #6ee7b7;
}

.status-cancelled {
  background-color: #fee2e2;
  color: #991b1b;
}

:global(.dark) .status-cancelled {
  background-color: rgba(127, 29, 29, 0.3);
  color: #fca5a5;
}

/* 模态框主体 */
.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 区域标题 */
.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: #111827;
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

:global(.dark) .section-title {
  color: #f3f4f6;
}

.count-badge {
  padding: 0.125rem 0.5rem;
  background-color: #dbeafe;
  color: #1d4ed8;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

:global(.dark) .count-badge {
  background-color: rgba(30, 58, 138, 0.3);
  color: #93c5fd;
}

/* 基本信息 */
.info-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1rem;
}

@media (max-width: 640px) {
  .info-grid {
    grid-template-columns: repeat(1, minmax(0, 1fr));
  }
}

.info-item {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.info-label {
  font-size: 0.75rem;
  color: #6b7280;
}

.info-value {
  font-size: 0.875rem;
  font-weight: 500;
  color: #111827;
}

:global(.dark) .info-value {
  color: #f3f4f6;
}

.info-value.amount {
  font-size: 1.25rem;
  font-weight: 700;
  color: #2563eb;
}

:global(.dark) .info-value.amount {
  color: #60a5fa;
}

/* 参与成员 */
.members-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 0.75rem;
}

.member-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background-color: #f9fafb;
  border-radius: 0.5rem;
}

:global(.dark) .member-card {
  background-color: rgba(17, 24, 39, 0.5);
}

.member-avatar {
  width: 3rem;
  height: 3rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 1.125rem;
}

.member-name {
  font-size: 0.875rem;
  color: #111827;
  font-weight: 500;
}

:global(.dark) .member-name {
  color: #f3f4f6;
}

/* 转账明细 */
.transfers-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.transfer-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
  background-color: #f9fafb;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
}

:global(.dark) .transfer-item {
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
  flex-shrink: 0;
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
  gap: 0.75rem;
}

.transfer-member {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #111827;
}

:global(.dark) .transfer-member {
  color: #f3f4f6;
}

.mini-avatar {
  width: 1.75rem;
  height: 1.75rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 700;
  font-size: 0.75rem;
  flex-shrink: 0;
}

.arrow-icon {
  width: 1.25rem;
  height: 1.25rem;
  color: #3b82f6;
  flex-shrink: 0;
}

:global(.dark) .arrow-icon {
  color: #60a5fa;
}

.transfer-amount {
  font-size: 1rem;
  font-weight: 700;
  color: #111827;
  flex-shrink: 0;
}

:global(.dark) .transfer-amount {
  color: #f3f4f6;
}

/* 统计卡片 */
.stats-section {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
}

@media (max-width: 640px) {
  .stats-section {
    grid-template-columns: repeat(1, minmax(0, 1fr));
  }
}

.stat-card {
  padding: 1rem;
  background-color: #f9fafb;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

:global(.dark) .stat-card {
  background-color: rgba(17, 24, 39, 0.5);
}

.stat-icon {
  width: 2.5rem;
  height: 2.5rem;
  padding: 0.5rem;
  background-color: #dbeafe;
  color: #2563eb;
  border-radius: 0.5rem;
  flex-shrink: 0;
}

:global(.dark) .stat-icon {
  background-color: rgba(30, 58, 138, 0.3);
  color: #60a5fa;
}

.stat-content {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.stat-label {
  font-size: 0.75rem;
  color: #6b7280;
}

.stat-value {
  font-size: 1.125rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .stat-value {
  color: #f3f4f6;
}

/* 模态框底部 */
.modal-footer {
  padding: 1.5rem;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.75rem;
  border-top: 1px solid #e5e7eb;
}

:global(.dark) .modal-footer {
  border-top-color: #374151;
}

/* 按钮 */
.btn-primary {
  padding: 0.5rem 1rem;
  background-color: #2563eb;
  color: white;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: background-color 0.15s;
  border: none;
  cursor: pointer;
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
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: background-color 0.15s;
  border: none;
  cursor: pointer;
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
</style>
