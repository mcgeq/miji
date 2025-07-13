<template>
  <div class="min-h-25">
    <div v-if="loading" class="flex justify-center items-center h-25 text-gray-600">
      加载中...
    </div>
    <div v-else-if="reminders.length === 0" class="flex flex-col items-center justify-center h-[200px] text-gray-400">
      <div class="text-lg mb-4 opacity-50">
        <i class="icon-bell"></i>
      </div>
      <div class="text-base">暂无提醒</div>
    </div>
    <div v-else class="reminder-grid">
      <div
        v-for="reminder in reminders"
        :key="reminder.serialNum"
        :class="[
          'reminder-card bg-white border rounded-lg p-5 transition-shadow',
          {
            'border-red-500 bg-red-50': isOverdue(reminder),
            'opacity-80 bg-green-50 border-green-400': reminder.isPaid,
            'shadow-md hover:shadow-lg': true,
          }
        ]"
      >
        <div class="flex justify-between items-center mb-4">
          <div class="text-lg font-semibold text-gray-800">
            {{ reminder.name }}
          </div>
          <div class="flex gap-2">
            <button
              v-if="!reminder.isPaid"
              class="w-8 h-8 rounded flex items-center justify-center cursor-pointer transition-colors hover:border-green-600 hover:text-green-600"
              @click="emit('mark-paid', reminder.serialNum)"
              title="标记已付"
            >
              <CheckCircle class="w-4 h-4" />
            </button>
            <button
              class="w-8 h-8 rounded flex items-center justify-center cursor-pointer transition-colors hover:border-blue-600 hover:text-blue-600"
              @click="emit('edit', reminder)"
              title="编辑"
            >
              <Edit class="w-4 h-4" />
            </button>
            <button
              class="danger w-8 h-8 rounded flex items-center justify-center cursor-pointer transition-colors hover:border-red-600 hover:text-red-600"
              @click="emit('delete', reminder.serialNum)"
              title="删除"
            >
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>
        <div class="mb-4">
          <div
            :class="[
              'inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs font-medium',
              getStatusClass(reminder) === 'paid' ? 'bg-green-100 text-green-600' :
              getStatusClass(reminder) === 'overdue' ? 'bg-red-100 text-red-600' :
              'bg-blue-100 text-blue-600'
            ]"
          >
            <i :class="getStatusIcon(reminder)"></i>
            <span>{{ getStatusText(reminder) }}</span>
          </div>
        </div>
        <div class="flex items-baseline gap-2 mb-4">
          <span class="amount-value text-2xl font-semibold text-gray-800">
            {{ formatCurrency(reminder.amount) }}
          </span>
          <span class="amount-currency text-sm text-gray-800">
            {{ reminder.currency.code }}
          </span>
        </div>
        <div class="mb-4 space-y-2">
          <div class="date-item flex justify-between text-sm text-gray-600">
            <span class="date-label">账单日期：</span>
            <span class="date-value font-medium text-gray-800">{{ formatDate(reminder.billDate) }}</span>
          </div>
          <div class="date-item flex justify-between text-sm text-gray-600">
            <span class="date-label">提醒时间：</span>
            <span class="date-value font-medium text-gray-800">{{ formatDate(reminder.remindDate) }}</span>
          </div>
        </div>
        <div class="flex items-center gap-2 mb-4 text-gray-600 text-sm">
          <i class="icon-repeat"></i>
          <span>{{ getRepeatTypeName(reminder.repeatPeriod) }}</span>
        </div>
        <div class="border-t border-gray-200 pt-4 space-y-2 text-sm">
          <div class="info-item flex justify-between text-gray-600">
            <span class="info-label">分类：</span>
            <span class="info-value text-gray-800">{{ reminder.category }}</span>
          </div>
          <div class="info-item flex justify-between text-gray-600">
            <span class="info-label">创建时间：</span>
            <span class="info-value text-gray-800">{{ formatDate(reminder.createdAt) }}</span>
          </div>
          <div v-if="reminder.description" class="info-item flex justify-between text-gray-600">
            <span class="info-label">备注：</span>
            <span class="info-value text-gray-800">{{ reminder.description }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Trash, Edit, CheckCircle } from 'lucide-vue-next';
import { RepeatPeriod } from '@/schema/common';
import { BilReminder } from '@/schema/money';
import { formatDate } from '@/utils/date';

interface Props {
  reminders: BilReminder[];
  loading: boolean;
}

defineProps<Props>();

const emit = defineEmits<{
  edit: [reminder: BilReminder];
  delete: [serialNum: string];
  'mark-paid': [serialNum: string];
}>();

const isOverdue = (reminder: BilReminder) => {
  if (reminder.isPaid) return false;
  const now = new Date();
  const remindDate = new Date(reminder.remindDate);
  return remindDate < now;
};

const getStatusClass = (reminder: BilReminder) => {
  if (reminder.isPaid) return 'paid';
  if (isOverdue(reminder)) return 'overdue';
  return 'pending';
};

const getStatusIcon = (reminder: BilReminder) => {
  if (reminder.isPaid) return 'icon-check-circle';
  if (isOverdue(reminder)) return 'icon-alert-circle';
  return 'icon-clock';
};

const getStatusText = (reminder: BilReminder) => {
  if (reminder.isPaid) return '已付款';
  if (isOverdue(reminder)) return '已逾期';
  return '待付款';
};

const getRepeatTypeName = (period: RepeatPeriod): string => {
  switch (period.type) {
    case 'None':
      return '无周期';
    case 'Daily':
      return period.interval > 1 ? `每${period.interval}天` : '每日预算';
    case 'Weekly':
      return period.interval > 1
        ? `每${period.interval}周 (${period.daysOfWeek.join(',')})`
        : `每周 (${period.daysOfWeek.join(',')})`;
    case 'Monthly':
      const day = period.day === 'last' ? '最后一天' : `第${period.day}天`;
      return period.interval > 1
        ? `每${period.interval}月，${day}`
        : `每月，${day}`;
    case 'Yearly':
      return period.interval > 1
        ? `每${period.interval}年，${period.month}月${period.day}日`
        : `${period.month}月${period.day}日`;
    case 'Custom':
      return period.description;
    default:
      return '未知周期';
  }
};

const formatCurrency = (amount: string) => {
  const num = parseFloat(amount);
  return num.toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
};
</script>

<style scoped>
.reminder-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}
</style>
