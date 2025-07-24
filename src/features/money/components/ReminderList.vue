<script setup lang="ts">
import {
  AlertCircle,
  CheckCircle,
  Clock,
  Edit,
  Repeat,
  RotateCcw,
  Trash,
} from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { getRepeatTypeName } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { formatCurrency } from '../utils/money';
import type { BilReminder } from '@/schema/money';

interface Props {
  reminders: BilReminder[];
  loading: boolean;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [reminder: BilReminder];
  delete: [serialNum: string];
  markPaid: [serialNum: string];
}>();

const { t } = useI18n();
// 过滤器状态
const filters = ref({
  status: '',
  period: '',
  category: '',
  dateRange: '',
});

// 分页状态
const currentPage = ref(1);
const pageSize = ref(4);

// 重置过滤器
function resetFilters() {
  filters.value = {
    status: '',
    period: '',
    category: '',
    dateRange: '',
  };
  currentPage.value = 1;
}

// 获取唯一分类
const uniqueCategories = computed(() => {
  const categories = props.reminders.map(reminder => reminder.category);
  return [...new Set(categories)].filter(Boolean);
});

// 日期范围过滤辅助函数
function isInDateRange(reminder: BilReminder, range: string): boolean {
  const now = new Date();
  const remindDate = new Date(reminder.remindDate);

  switch (range) {
    case 'today':
      return remindDate.toDateString() === now.toDateString();
    case 'week':
    {
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay());
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekStart.getDate() + 6);
      return remindDate >= weekStart && remindDate <= weekEnd;
    }
    case 'month':
      return (
        remindDate.getMonth() === now.getMonth()
        && remindDate.getFullYear() === now.getFullYear()
      );
    case 'overdue':
      return !reminder.isPaid && remindDate < now;
    default:
      return true;
  }
}

// 过滤后的提醒
const filteredReminders = computed(() => {
  let filtered = [...props.reminders];

  // 状态过滤
  if (filters.value.status) {
    filtered = filtered.filter(reminder => {
      const status = getStatusClass(reminder);
      return status === filters.value.status;
    });
  }

  // 周期类型过滤
  if (filters.value.period) {
    filtered = filtered.filter(
      reminder => reminder.repeatPeriod.type === filters.value.period,
    );
  }

  // 分类过滤
  if (filters.value.category) {
    filtered = filtered.filter(
      reminder => reminder.category === filters.value.category,
    );
  }

  // 日期范围过滤
  if (filters.value.dateRange) {
    filtered = filtered.filter(reminder =>
      isInDateRange(reminder, filters.value.dateRange),
    );
  }

  return filtered;
});

// 总页数
const totalPages = computed(() => {
  return Math.ceil(filteredReminders.value.length / pageSize.value);
});

// 当前页的提醒
const paginatedReminders = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  const end = start + pageSize.value;
  return filteredReminders.value.slice(start, end);
});

// 处理页码变化
function handlePageChange(page: number) {
  currentPage.value = page;
}

// 监听过滤器变化，重置到第一页
watch(
  filters,
  () => {
    currentPage.value = 1;
  },
  { deep: true },
);

// 原有的方法
function isOverdue(reminder: BilReminder) {
  if (reminder.isPaid)
    return false;
  const now = new Date();
  const remindDate = new Date(reminder.remindDate);
  return remindDate < now;
}

function getStatusClass(reminder: BilReminder) {
  if (reminder.isPaid)
    return 'paid';
  if (isOverdue(reminder))
    return 'overdue';
  return 'pending';
}

function getStatusIcon(reminder: BilReminder) {
  if (reminder.isPaid)
    return CheckCircle;
  if (isOverdue(reminder))
    return AlertCircle;
  return Clock;
}

function getStatusText(reminder: BilReminder) {
  if (reminder.isPaid)
    return t('common.status.paid');
  if (isOverdue(reminder))
    return t('common.status.overdue');
  return t('common.status.pending');
}
</script>

<template>
  <div class="min-h-25">
    <!-- 过滤器区域 -->
    <div class="mb-5 flex flex-wrap items-center justify-center gap-3 rounded-lg bg-gray-50 p-4">
      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('common.status.status') }}</label>
        <select
          v-model="filters.status"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('common.actions.all') }}
          </option>
          <option value="paid">
            {{ t('common.status.paid') }}
          </option>
          <option value="overdue">
            {{ t('common.status.overdue') }}
          </option>
          <option value="pending">
            {{ t('common.status.pending') }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('todos.repeat.periodType') }}</label>
        <select
          v-model="filters.period"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('common.actions.all') }}
          </option>
          <option value="None">
            {{ t('date.repeat.none') }}
          </option>
          <option value="Daily">
            {{ t('date.repeat.daily') }}
          </option>
          <option value="Weekly">
            {{ t('date.repeat.weekly') }}
          </option>
          <option value="Monthly">
            {{ t('date.repeat.monthly') }}
          </option>
          <option value="Yearly">
            {{ t('date.repeat.yearly') }}
          </option>
          <option value="Custom">
            {{ t('date.repeat.custom') }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium"> {{ t('categories.category') }} </label>
        <select
          v-model="filters.category"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('categories.allCategory') }}
          </option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ category }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('date.rangeDate') }}</label>
        <select
          v-model="filters.dateRange"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('common.actions.all') }}
          </option>
          <option value="today">
            {{ t('date.periods.today') }}
          </option>
          <option value="week">
            {{ t('date.periods.week') }}
          </option>
          <option value="month">
            {{ t('date.periods.month') }}
          </option>
          <option value="overdue">
            {{ t('common.status.overdue') }}
          </option>
        </select>
      </div>

      <button
        class="rounded-md bg-gray-200 px-3 py-1.5 text-sm text-gray-700 transition-colors hover:bg-gray-300"
        @click="resetFilters"
      >
        <RotateCcw class="mr-1 wh-5" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="h-25 flex-justify-center text-gray-600">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="paginatedReminders.length === 0" class="h-25 flex-justify-center flex-col text-#999">
      <div class="mb-2 text-sm opacity-50">
        <i class="icon-bell" />
      </div>
      <div class="text-sm">
        {{ filteredReminders.length === 0 ? t('messages.noReminder') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 提醒网格 -->
    <div v-else class="reminder-grid grid mb-6 w-full gap-5">
      <div
        v-for="reminder in paginatedReminders" :key="reminder.serialNum" class="reminder-card border rounded-lg bg-white p-5 shadow-md transition-shadow hover:shadow-lg" :class="[
          {
            'border-red-500 bg-red-50': isOverdue(reminder),
            'opacity-80 bg-green-50 border-green-400': reminder.isPaid,
          },
        ]"
      >
        <div class="mb-4 flex items-center justify-between">
          <div class="text-lg text-gray-800 font-semibold">
            {{ reminder.name }}
          </div>
          <div class="flex items-center gap-2">
            <div
              class="inline-flex items-center gap-1.5 rounded px-2 py-1 text-xs font-medium" :class="[
                getStatusClass(reminder) === 'paid' ? 'bg-green-100 text-green-600'
                : getStatusClass(reminder) === 'overdue' ? 'bg-red-100 text-red-600'
                  : 'bg-blue-100 text-blue-600',
              ]"
            >
              <component :is="getStatusIcon(reminder)" class="h-4 w-4" />
              <span>{{ getStatusText(reminder) }}</span>
            </div>
            <div class="flex gap-1">
              <button
                v-if="!reminder.isPaid" class="money-option-btn hover:(border-green-500 text-green-500)"
                :title="t('financial.transaction.markPaid')" @click="emit('markPaid', reminder.serialNum)"
              >
                <CheckCircle class="h-4 w-4" />
              </button>
              <button
                class="money-option-btn hover:(border-blue-500 text-blue-500)" :title="t('common.actions.edit')"
                @click="emit('edit', reminder)"
              >
                <Edit class="h-4 w-4" />
              </button>
              <button
                class="money-option-btn hover:(border-red-500 text-red-500)"
                :title="t('common.actions.delete')" @click="emit('delete', reminder.serialNum)"
              >
                <Trash class="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        <div class="mb-4 flex items-baseline gap-2">
          <span class="text-2xl text-gray-800 font-semibold">
            {{ formatCurrency(reminder.amount) }}
          </span>
          <span class="text-sm text-gray-800">
            {{ reminder.currency.code }}
          </span>
        </div>

        <div class="mb-2 space-y-2">
          <div class="flex justify-between text-sm">
            <span class="text-gray-600">{{ t('financial.billDate') }}</span>
            <span class="text-gray-800">{{ DateUtils.formatDate(reminder.billDate) }}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-gray-600">{{ t('date.reminderDate') }}</span>
            <span class="text-gray-800">{{ DateUtils.formatDateTime(reminder.remindDate) }}</span>
          </div>
        </div>

        <div class="mb-2 flex items-center justify-end gap-2 text-sm text-gray-600">
          <Repeat class="h-4 w-4" />
          <span>{{ getRepeatTypeName(reminder.repeatPeriod) }}</span>
        </div>

        <div class="border-t border-gray-200 pt-4 text-sm space-y-2">
          <div class="flex justify-between">
            <span class="text-gray-600"> {{ t('categories.category') }} </span>
            <span class="text-gray-800">{{ reminder.category }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-600"> {{ t('date.createDate') }} </span>
            <span class="text-gray-800">{{ DateUtils.formatDate(reminder.createdAt) }}</span>
          </div>
          <div v-if="reminder.description" class="flex justify-between">
            <span class="text-gray-600"> {{ t('common.misc.remark') }} </span>
            <span class="text-gray-800">{{ reminder.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="filteredReminders.length > pageSize" class="flex justify-center">
      <SimplePagination
        :current-page="currentPage" :total-pages="totalPages" :total-items="filteredReminders.length"
        :page-size="pageSize" @page-change="handlePageChange"
      />
    </div>
  </div>
</template>

<style scoped lang="postcss">
.reminder-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}

.money-option-btn {
  @apply p-1.5 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-50 transition-colors;
}
</style>
