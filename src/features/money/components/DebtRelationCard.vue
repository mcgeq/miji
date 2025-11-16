<script setup lang="ts">
import {
  AlertCircle,
  ArrowRight,
  Bell,
  CheckCircle,
  CheckCircle2,
  Clock,
  Eye,
  MessageSquare,
  XCircle,
} from 'lucide-vue-next';
import { computed } from 'vue';

// ==================== Props ====================

interface DebtRelation {
  serialNum: string;
  familyLedgerSerialNum: string;
  creditorMemberSerialNum: string;
  creditorMemberName: string;
  debtorMemberSerialNum: string;
  debtorMemberName: string;
  amount: number;
  currency: string;
  status: 'active' | 'settled' | 'cancelled';
  lastCalculatedAt: string;
  notes?: string;
  priority?: 'high' | 'medium' | 'low';
  originalAmount?: number; // 原始金额（用于显示进度）
}

interface Props {
  relation: DebtRelation;
  currentMemberSerialNum?: string;
  showActions?: boolean;
  showProgress?: boolean;
  showNotes?: boolean;
  clickable?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  showActions: true,
  showProgress: false,
  showNotes: false,
  clickable: true,
});

// ==================== Emits ====================

const emit = defineEmits<{
  click: [relation: DebtRelation];
  detail: [relation: DebtRelation];
  settle: [relation: DebtRelation];
  remind: [relation: DebtRelation];
}>();

// ==================== 计算属性 ====================

// 卡片样式类
const cardClass = computed(() => {
  const classes = [];

  // 根据当前用户角色添加样式
  if (props.currentMemberSerialNum) {
    if (props.relation.debtorMemberSerialNum === props.currentMemberSerialNum) {
      classes.push('card-debtor');
    } else if (props.relation.creditorMemberSerialNum === props.currentMemberSerialNum) {
      classes.push('card-creditor');
    }
  }

  // 状态样式
  if (props.relation.status !== 'active') {
    classes.push('card-inactive');
  }

  // 可点击样式
  if (props.clickable) {
    classes.push('card-clickable');
  }

  return classes;
});

// 成员颜色
const debtorColor = computed(() => getMemberColor(props.relation.debtorMemberSerialNum));
const creditorColor = computed(() => getMemberColor(props.relation.creditorMemberSerialNum));

// 支付进度
const paidAmount = computed(() => {
  if (!props.relation.originalAmount) return 0;
  return props.relation.originalAmount - props.relation.amount;
});

const paymentPercentage = computed(() => {
  if (!props.relation.originalAmount) return 0;
  return Math.round((paidAmount.value / props.relation.originalAmount) * 100);
});

// ==================== 方法 ====================

function handleClick() {
  if (props.clickable) {
    emit('click', props.relation);
  }
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

// 格式化时间
function formatTime(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));

  if (days === 0) return '今天';
  if (days === 1) return '昨天';
  if (days < 7) return `${days}天前`;
  if (days < 30) return `${Math.floor(days / 7)}周前`;
  return date.toLocaleDateString();
}

// 获取状态文本
function getStatusText(status: string): string {
  const statusMap: Record<string, string> = {
    active: '活跃',
    settled: '已结算',
    cancelled: '已取消',
  };
  return statusMap[status] || status;
}

// 获取状态图标
function getStatusIcon(status: string) {
  const iconMap: Record<string, any> = {
    active: AlertCircle,
    settled: CheckCircle,
    cancelled: XCircle,
  };
  return iconMap[status] || AlertCircle;
}

// 获取优先级文本
function getPriorityText(priority: string): string {
  const priorityMap: Record<string, string> = {
    high: '高',
    medium: '中',
    low: '低',
  };
  return priorityMap[priority] || priority;
}
</script>

<template>
  <div class="debt-relation-card" :class="cardClass" @click="handleClick">
    <!-- 卡片头部 -->
    <div class="card-header">
      <div class="member-flow">
        <!-- 债务人 -->
        <div class="member-info">
          <div class="member-avatar" :style="{ backgroundColor: debtorColor }">
            {{ getInitials(relation.debtorMemberName) }}
          </div>
          <div class="member-details">
            <div class="member-name">
              {{ relation.debtorMemberName }}
            </div>
            <div class="member-role">
              债务人
            </div>
          </div>
        </div>

        <!-- 流向箭头 -->
        <div class="flow-arrow">
          <div class="arrow-line" />
          <component :is="ArrowRight" class="arrow-icon" />
        </div>

        <!-- 债权人 -->
        <div class="member-info">
          <div class="member-avatar" :style="{ backgroundColor: creditorColor }">
            {{ getInitials(relation.creditorMemberName) }}
          </div>
          <div class="member-details">
            <div class="member-name">
              {{ relation.creditorMemberName }}
            </div>
            <div class="member-role">
              债权人
            </div>
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div v-if="showActions" class="card-actions" @click.stop>
        <button
          class="action-btn"
          title="查看详情"
          @click="$emit('detail', relation)"
        >
          <component :is="Eye" class="w-4 h-4" />
        </button>
        <button
          v-if="relation.status === 'active'"
          class="action-btn action-btn-primary"
          title="标记为已结算"
          @click="$emit('settle', relation)"
        >
          <component :is="CheckCircle2" class="w-4 h-4" />
        </button>
        <button
          v-if="relation.status === 'active'"
          class="action-btn action-btn-warning"
          title="发送提醒"
          @click="$emit('remind', relation)"
        >
          <component :is="Bell" class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- 卡片主体 -->
    <div class="card-body">
      <!-- 债务描述 -->
      <div class="debt-description">
        <span class="text-highlight">{{ relation.debtorMemberName }}</span>
        <span class="text-muted">欠</span>
        <span class="text-highlight">{{ relation.creditorMemberName }}</span>
      </div>

      <!-- 金额 -->
      <div class="debt-amount-section">
        <div class="amount-label">
          欠款金额
        </div>
        <div class="amount-value">
          <span class="currency-symbol">¥</span>
          <span class="amount-number">{{ formatAmount(relation.amount) }}</span>
          <span class="currency-code">{{ relation.currency }}</span>
        </div>
      </div>

      <!-- 进度条（可选） -->
      <div v-if="showProgress && relation.originalAmount" class="payment-progress">
        <div class="progress-bar">
          <div
            class="progress-fill"
            :style="{ width: `${paymentPercentage}%` }"
          />
        </div>
        <div class="progress-text">
          已还 {{ formatAmount(paidAmount) }} / {{ formatAmount(relation.originalAmount) }}
          ({{ paymentPercentage }}%)
        </div>
      </div>
    </div>

    <!-- 卡片底部 -->
    <div class="card-footer">
      <div class="footer-left">
        <!-- 状态徽章 -->
        <span class="status-badge" :class="`status-${relation.status}`">
          <component :is="getStatusIcon(relation.status)" class="w-3 h-3" />
          <span>{{ getStatusText(relation.status) }}</span>
        </span>

        <!-- 优先级（可选） -->
        <span v-if="relation.priority" class="priority-badge" :class="`priority-${relation.priority}`">
          {{ getPriorityText(relation.priority) }}
        </span>
      </div>

      <div class="footer-right">
        <!-- 时间信息 -->
        <div class="time-info">
          <component :is="Clock" class="w-3 h-3" />
          <span>{{ formatTime(relation.lastCalculatedAt) }}</span>
        </div>
      </div>
    </div>

    <!-- 备注（可选） -->
    <div v-if="relation.notes && showNotes" class="card-notes">
      <component :is="MessageSquare" class="w-4 h-4" />
      <span>{{ relation.notes }}</span>
    </div>
  </div>
</template>

<style scoped>
/* 卡片容器 */
.debt-relation-card {
  background-color: white;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  border: 1px solid #e5e7eb;
  overflow: hidden;
  transition: all 0.2s;
}

:global(.dark) .debt-relation-card {
  background-color: #1f2937;
  border-color: #374151;
}

.card-clickable {
  cursor: pointer;
}

.card-clickable:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  transform: scale(1.02);
}

.card-debtor {
  border-left: 4px solid #ef4444;
}

.card-creditor {
  border-left: 4px solid #10b981;
}

.card-inactive {
  opacity: 0.6;
}

/* 卡片头部 */
.card-header {
  padding: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background-color: #f9fafb;
}

:global(.dark) .card-header {
  background-color: rgba(17, 24, 39, 0.5);
}

.member-flow {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex: 1;
}

.member-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
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
  font-size: 1rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
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

.flow-arrow {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #9ca3af;
  position: relative;
}

:global(.dark) .flow-arrow {
  color: #4b5563;
}

.arrow-line {
  width: 2rem;
  height: 0.125rem;
  background-color: #d1d5db;
}

:global(.dark) .arrow-line {
  background-color: #4b5563;
}

.arrow-icon {
  width: 1.25rem;
  height: 1.25rem;
}

/* 操作按钮 */
.card-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.action-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  transition: background-color 0.15s, color 0.15s;
  color: #4b5563;
}

.action-btn:hover {
  background-color: #f3f4f6;
}

:global(.dark) .action-btn {
  color: #9ca3af;
}

:global(.dark) .action-btn:hover {
  background-color: #374151;
}

.action-btn-primary {
  color: #059669;
}

.action-btn-primary:hover {
  background-color: #f0fdf4;
}

:global(.dark) .action-btn-primary {
  color: #34d399;
}

:global(.dark) .action-btn-primary:hover {
  background-color: rgba(6, 78, 59, 0.2);
}

.action-btn-warning {
  color: #ea580c;
}

.action-btn-warning:hover {
  background-color: #fff7ed;
}

:global(.dark) .action-btn-warning {
  color: #fb923c;
}

:global(.dark) .action-btn-warning:hover {
  background-color: rgba(124, 45, 18, 0.2);
}

/* 卡片主体 */
.card-body {
  padding: 1rem;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.debt-description {
  font-size: 0.875rem;
  color: #4b5563;
}

:global(.dark) .debt-description {
  color: #9ca3af;
}

.text-highlight {
  font-weight: 500;
  color: #111827;
}

:global(.dark) .text-highlight {
  color: #f3f4f6;
}

.text-muted {
  margin-left: 0.25rem;
  margin-right: 0.25rem;
}

/* 金额部分 */
.debt-amount-section {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.amount-label {
  font-size: 0.75rem;
  color: #6b7280;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.amount-value {
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
}

.currency-symbol {
  color: #6b7280;
  font-size: 1.25rem;
}

.amount-number {
  font-size: 1.875rem;
  font-weight: 700;
  color: #111827;
}

:global(.dark) .amount-number {
  color: #f3f4f6;
}

.currency-code {
  font-size: 0.875rem;
  color: #6b7280;
}

/* 支付进度 */
.payment-progress {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.progress-bar {
  width: 100%;
  height: 0.5rem;
  background-color: #e5e7eb;
  border-radius: 9999px;
  overflow: hidden;
}

:global(.dark) .progress-bar {
  background-color: #374151;
}

.progress-fill {
  height: 100%;
  background: linear-gradient(to right, #3b82f6, #10b981);
  transition: all 0.3s;
}

.progress-text {
  font-size: 0.75rem;
  color: #4b5563;
}

:global(.dark) .progress-text {
  color: #9ca3af;
}

/* 卡片底部 */
.card-footer {
  padding-left: 1rem;
  padding-right: 1rem;
  padding-bottom: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.footer-left,
.footer-right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* 状态徽章 */
.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.625rem;
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

/* 优先级徽章 */
.priority-badge {
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  font-size: 0.75rem;
  font-weight: 500;
}

.priority-high {
  background-color: #fee2e2;
  color: #991b1b;
}

:global(.dark) .priority-high {
  background-color: rgba(127, 29, 29, 0.3);
  color: #fca5a5;
}

.priority-medium {
  background-color: #fef3c7;
  color: #92400e;
}

:global(.dark) .priority-medium {
  background-color: rgba(120, 53, 15, 0.3);
  color: #fcd34d;
}

.priority-low {
  background-color: #d1fae5;
  color: #065f46;
}

:global(.dark) .priority-low {
  background-color: rgba(6, 95, 70, 0.3);
  color: #6ee7b7;
}

/* 时间信息 */
.time-info {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  font-size: 0.75rem;
  color: #6b7280;
}

/* 备注 */
.card-notes {
  padding-left: 1rem;
  padding-right: 1rem;
  padding-bottom: 1rem;
  padding-top: 0.5rem;
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #4b5563;
  background-color: #f9fafb;
}

:global(.dark) .card-notes {
  color: #9ca3af;
  background-color: rgba(17, 24, 39, 0.3);
}
</style>
