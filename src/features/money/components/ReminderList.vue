<template>
  <div class="min-h-25">
    <div v-if="loading" class="flex-justify-center h-25 text-gray-600">
      加载中...
    </div>
    <div v-else-if="reminders.length === 0" class="flex-justify-center flex-col h-[200px] text-gray-400">
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
          <div
            :class="[
              'inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs font-medium',
              getStatusClass(reminder) === 'paid' ? 'bg-green-100 text-green-600' :
              getStatusClass(reminder) === 'overdue' ? 'bg-red-100 text-red-600' :
              'bg-blue-100 text-blue-600'              ]"
          >
            <component :is="getStatusIcon(reminder)" class="w-4 h-4" />
            <span>{{ getStatusText(reminder) }}</span>
          </div>
          <div class="flex gap-1">
            <button
              v-if="!reminder.isPaid"
              class="money-option-btn hover:(border-green-500 text-green-500)"
              @click="emit('mark-paid', reminder.serialNum)"
              title="标记已付"
            >
              <CheckCircle class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-blue-500 text-blue-500)"
              @click="emit('edit', reminder)"
              title="编辑"
            >
              <Edit class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-red-500 text-red-500)"
              @click="emit('delete', reminder.serialNum)"
              title="删除"
            >
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>
        <div class="flex items-baseline gap-2 mb-4">
          <span class="text-2xl font-semibold text-gray-800">
            {{ formatCurrency(reminder.amount) }}
          </span>
          <span class="text-sm text-gray-800">
            {{ reminder.currency.code }}
          </span>
        </div>
        <div class="mb-2 space-y-2">
          <div class="flex justify-between text-sm">
            <span class="text-gray-600">账单日期：</span>
            <span class="text-gray-800">{{ formatDate(reminder.billDate) }}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-gray-600">提醒时间：</span>
            <span class="text-gray-800">{{ formatDateTime(reminder.remindDate) }}</span>
          </div>
        </div>
        <div class="flex justify-end items-center gap-2 mb-2 text-gray-600 text-sm">
          <Repeat class="w-4 h-4" />
          <span>{{ getRepeatTypeName(reminder.repeatPeriod) }}</span>
        </div>
        <div class="border-t border-gray-200 pt-4 space-y-2 text-sm">
          <div class="flex justify-between">
            <span class="text-gray-600">分类：</span>
            <span class="text-gray-800">{{ reminder.category }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-600">创建时间：</span>
            <span class="text-gray-800">{{ formatDate(reminder.createdAt) }}</span>
          </div>
          <div v-if="reminder.description" class="flex justify-between">
            <span class="text-gray-600">备注：</span>
            <span class="text-gray-800">{{ reminder.description }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Trash,
  Edit,
  CheckCircle,
  Repeat,
  AlertCircle,
  Clock,
} from 'lucide-vue-next';
import {BilReminder} from '@/schema/money';
import {formatDate, formatDateTime} from '@/utils/date';
import {formatCurrency} from '../utils/money';
import {getRepeatTypeName} from '@/utils/common';

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
  if (reminder.isPaid) return CheckCircle;
  if (isOverdue(reminder)) return AlertCircle;
  return Clock;
};

const getStatusText = (reminder: BilReminder) => {
  if (reminder.isPaid) return '已付款';
  if (isOverdue(reminder)) return '已逾期';
  return '待付款';
};
</script>

<style scoped>
.reminder-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}
</style>
