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

// 卡片角色样式
const isDebtor = computed(() =>
  props.currentMemberSerialNum && props.relation.debtorMemberSerialNum === props.currentMemberSerialNum,
);
const isCreditor = computed(() =>
  props.currentMemberSerialNum && props.relation.creditorMemberSerialNum === props.currentMemberSerialNum,
);

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
  <div
    class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden transition-all duration-200"
    :class="[
      isDebtor && 'border-l-4 border-l-red-500',
      isCreditor && 'border-l-4 border-l-green-500',
      relation.status !== 'active' && 'opacity-60',
      clickable && 'cursor-pointer hover:shadow-md hover:scale-[1.02]',
    ]"
    @click="handleClick"
  >
    <!-- 卡片头部 -->
    <div class="p-4 flex items-center justify-between bg-gray-50 dark:bg-gray-900/50">
      <div class="flex items-center gap-4 flex-1">
        <!-- 债务人 -->
        <div class="flex items-center gap-3">
          <div
            class="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-base shadow-sm"
            :style="{ backgroundColor: debtorColor }"
          >
            {{ getInitials(relation.debtorMemberName) }}
          </div>
          <div class="flex flex-col">
            <div class="font-medium text-gray-900 dark:text-gray-100 text-sm">
              {{ relation.debtorMemberName }}
            </div>
            <div class="text-xs text-gray-500 dark:text-gray-400">
              债务人
            </div>
          </div>
        </div>

        <!-- 流向箭头 -->
        <div class="flex items-center gap-2 text-gray-400 dark:text-gray-600">
          <div class="w-8 h-0.5 bg-gray-300 dark:bg-gray-600" />
          <ArrowRight :size="20" />
        </div>

        <!-- 债权人 -->
        <div class="flex items-center gap-3">
          <div
            class="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-base shadow-sm"
            :style="{ backgroundColor: creditorColor }"
          >
            {{ getInitials(relation.creditorMemberName) }}
          </div>
          <div class="flex flex-col">
            <div class="font-medium text-gray-900 dark:text-gray-100 text-sm">
              {{ relation.creditorMemberName }}
            </div>
            <div class="text-xs text-gray-500 dark:text-gray-400">
              债权人
            </div>
          </div>
        </div>
      </div>

      <!-- 操作按钮 -->
      <div v-if="showActions" class="flex items-center gap-2" @click.stop>
        <button
          class="p-2 rounded-lg transition-colors text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-700"
          title="查看详情"
          @click="$emit('detail', relation)"
        >
          <Eye :size="16" />
        </button>
        <button
          v-if="relation.status === 'active'"
          class="p-2 rounded-lg transition-colors text-green-600 dark:text-green-400 hover:bg-green-50 dark:hover:bg-green-900/20"
          title="标记为已结算"
          @click="$emit('settle', relation)"
        >
          <CheckCircle2 :size="16" />
        </button>
        <button
          v-if="relation.status === 'active'"
          class="p-2 rounded-lg transition-colors text-orange-600 dark:text-orange-400 hover:bg-orange-50 dark:hover:bg-orange-900/20"
          title="发送提醒"
          @click="$emit('remind', relation)"
        >
          <Bell :size="16" />
        </button>
      </div>
    </div>

    <!-- 卡片主体 -->
    <div class="p-4 flex flex-col gap-4">
      <!-- 债务描述 -->
      <div class="text-sm text-gray-600 dark:text-gray-400">
        <span class="font-medium text-gray-900 dark:text-gray-100">{{ relation.debtorMemberName }}</span>
        <span class="mx-1">欠</span>
        <span class="font-medium text-gray-900 dark:text-gray-100">{{ relation.creditorMemberName }}</span>
      </div>

      <!-- 金额 -->
      <div class="flex flex-col gap-2">
        <div class="text-xs text-gray-500 dark:text-gray-400 uppercase tracking-wider">
          欠款金额
        </div>
        <div class="flex items-baseline gap-2">
          <span class="text-xl text-gray-500 dark:text-gray-400">￥</span>
          <span class="text-3xl font-bold text-gray-900 dark:text-gray-100">{{ formatAmount(relation.amount) }}</span>
          <span class="text-sm text-gray-500 dark:text-gray-400">{{ relation.currency }}</span>
        </div>
      </div>

      <!-- 进度条（可选） -->
      <div v-if="showProgress && relation.originalAmount" class="flex flex-col gap-2">
        <div class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-full overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-blue-500 to-green-500 transition-all duration-300"
            :style="{ width: `${paymentPercentage}%` }"
          />
        </div>
        <div class="text-xs text-gray-600 dark:text-gray-400">
          已还 {{ formatAmount(paidAmount) }} / {{ formatAmount(relation.originalAmount) }}
          ({{ paymentPercentage }}%)
        </div>
      </div>
    </div>

    <!-- 卡片底部 -->
    <div class="px-4 pb-4 flex items-center justify-between">
      <div class="flex items-center gap-2">
        <!-- 状态徽章 -->
        <span
          class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium"
          :class="[
            relation.status === 'active' && 'bg-blue-100 dark:bg-blue-900/30 text-blue-800 dark:text-blue-300',
            relation.status === 'settled' && 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300',
            relation.status === 'cancelled' && 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300',
          ]"
        >
          <component :is="getStatusIcon(relation.status)" :size="12" />
          <span>{{ getStatusText(relation.status) }}</span>
        </span>

        <!-- 优先级（可选） -->
        <span
          v-if="relation.priority"
          class="px-2 py-1 rounded text-xs font-medium"
          :class="[
            relation.priority === 'high' && 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300',
            relation.priority === 'medium' && 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300',
            relation.priority === 'low' && 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300',
          ]"
        >
          {{ getPriorityText(relation.priority) }}
        </span>
      </div>

      <div class="flex items-center gap-2">
        <!-- 时间信息 -->
        <div class="flex items-center gap-1 text-xs text-gray-500 dark:text-gray-400">
          <Clock :size="12" />
          <span>{{ formatTime(relation.lastCalculatedAt) }}</span>
        </div>
      </div>
    </div>

    <!-- 备注（可选） -->
    <div v-if="relation.notes && showNotes" class="px-4 pb-4 pt-2 flex items-start gap-2 text-sm text-gray-600 dark:text-gray-400 bg-gray-50 dark:bg-gray-900/30">
      <MessageSquare :size="16" />
      <span>{{ relation.notes }}</span>
    </div>
  </div>
</template>
