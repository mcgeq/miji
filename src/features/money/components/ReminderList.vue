<template>
  <div class="min-h-25">
    <!-- 过滤器区域 -->
    <div class="flex flex-wrap justify-center items-center gap-3 mb-5 p-4 bg-gray-50 rounded-lg">
      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">{{ t('optionsAndStatus.status') }}</label>
        <select 
          v-model="filters.status" 
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value=""> {{ t('generalOperations.all') }} </option>
          <option value="paid">{{ t('optionsAndStatus.paid') }}</option>
          <option value="overdue">{{ t('optionsAndStatus.overdue') }}</option>
          <option value="pending">{{ t('optionsAndStatus.pending') }}</option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">{{ t('others.periodType') }}</label>
        <select 
          v-model="filters.period" 
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">{{ t('generalOperations.all') }}</option>
          <option value="None">{{ t('date.none') }}</option>
          <option value="Daily">{{ t('date.daily') }}</option>
          <option value="Weekly">{{ t('date.weekly') }}</option>
          <option value="Monthly">{{ t('date.monthly') }}</option>
          <option value="Yearly">{{ t('date.yearly') }}</option>
          <option value="Custom">{{ t('date.custom') }}</option>

      </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700"> {{ t('categories.category') }} </label>
        <select
          v-model="filters.category" 
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value=""> {{ t('categories.allCategory') }} </option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ category }}
          </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">{{ t('date.rangeDate') }}</label>
        <select 
          v-model="filters.dateRange" 
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">{{ t('generalOperations.all') }}</option>
          <option value="today">{{ t('date.today') }}</option>
          <option value="week">{{ t('date.week') }}</option>
          <option value="month">{{ t('date.month') }}</option>
          <option value="overdue">{{ t('optionsAndStatus.overdue') }}</option>
        </select>
      </div>

      <button 
        @click="resetFilters"
        class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded-md text-sm hover:bg-gray-300 transition-colors"
      >
          <RotateCcw class="wh-5 mr-1" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading"
      class="flex-justify-center h-25 text-gray-600">
      {{ t('loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="paginatedReminders.length === 0" class="flex-justify-center flex-col h-25 text-#999">
      <div class="text-sm mb-2 opacity-50">
        <i class="icon-bell"></i>
      </div>
      <div class="text-sm">
        {{ filteredReminders.length === 0 ? t('optionsAndStatus.noReminder') : t('optionsAndStatus.noPatternResult') }}
      </div>
    </div>

    <!-- 提醒网格 -->
    <div v-else class="reminder-grid grid gap-5 w-full mb-6">
      <div
        v-for="reminder in paginatedReminders"
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
          <div class="flex items-center gap-2">
            <div
              :class="[
                'inline-flex items-center gap-1.5 px-2 py-1 rounded text-xs font-medium',
                getStatusClass(reminder) === 'paid' ? 'bg-green-100 text-green-600' :
                getStatusClass(reminder) === 'overdue' ? 'bg-red-100 text-red-600' :
                'bg-blue-100 text-blue-600'
              ]"
            >
              <component :is="getStatusIcon(reminder)" class="w-4 h-4" />
              <span>{{ getStatusText(reminder) }}</span>
            </div>
            <div class="flex gap-1">
              <button
                v-if="!reminder.isPaid"
                class="money-option-btn hover:(border-green-500 text-green-500)"
                @click="emit('mark-paid', reminder.serialNum)"
                :title="t('optionsAndStatus.markPaid')"
              >
                <CheckCircle class="w-4 h-4" />
              </button>
              <button
                class="money-option-btn hover:(border-blue-500 text-blue-500)"
                @click="emit('edit', reminder)"
                :title="t('generalOperations.edit')"
              >
                <Edit class="w-4 h-4" />
              </button>
              <button
                class="money-option-btn hover:(border-red-500 text-red-500)"
                @click="emit('delete', reminder.serialNum)"
                :title="t('generalOperations.delete')"
              >
                <Trash class="w-4 h-4" />
              </button>
            </div>
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
            <span class="text-gray-600">{{ t('moneys.billDate') }}</span>
            <span class="text-gray-800">{{ formatDate(reminder.billDate) }}</span>
          </div>
          <div class="flex justify-between text-sm">
            <span class="text-gray-600">{{ t('date.reminderDate') }}</span>
            <span class="text-gray-800">{{ formatDateTime(reminder.remindDate) }}</span>
          </div>
        </div>

        <div class="flex justify-end items-center gap-2 mb-2 text-gray-600 text-sm">
          <Repeat class="w-4 h-4" />
          <span>{{ getRepeatTypeName(reminder.repeatPeriod) }}</span>
        </div>

        <div class="border-t border-gray-200 pt-4 space-y-2 text-sm">
          <div class="flex justify-between">
            <span class="text-gray-600"> {{ t('categories.category') }} </span>
            <span class="text-gray-800">{{ reminder.category }}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-600"> {{ t('date.createDate') }} </span>
            <span class="text-gray-800">{{ formatDate(reminder.createdAt) }}</span>
          </div>
          <div v-if="reminder.description" class="flex justify-between">
            <span class="text-gray-600"> {{ t('others.remark') }} </span>
            <span class="text-gray-800">{{ reminder.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="filteredReminders.length > pageSize" class="flex justify-center">
      <SimplePagination 
        :current-page="currentPage"
        :total-pages="totalPages"
        :total-items="filteredReminders.length"
        :page-size="pageSize"
        @page-change="handlePageChange"
      />
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
  RotateCcw,
} from 'lucide-vue-next';
import {BilReminder} from '@/schema/money';
import {formatDate, formatDateTime} from '@/utils/date';
import {formatCurrency} from '../utils/money';
import {getRepeatTypeName} from '@/utils/common';
import SimplePagination from '@/components/common/SimplePagination.vue';

interface Props {
  reminders: BilReminder[];
  loading: boolean;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [reminder: BilReminder];
  delete: [serialNum: string];
  'mark-paid': [serialNum: string];
}>();

const {t} = useI18n();
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
const resetFilters = () => {
  filters.value = {
    status: '',
    period: '',
    category: '',
    dateRange: '',
  };
  currentPage.value = 1;
};

// 获取唯一分类
const uniqueCategories = computed(() => {
  const categories = props.reminders.map((reminder) => reminder.category);
  return [...new Set(categories)].filter(Boolean);
});

// 日期范围过滤辅助函数
const isInDateRange = (reminder: BilReminder, range: string): boolean => {
  const now = new Date();
  const remindDate = new Date(reminder.remindDate);

  switch (range) {
    case 'today':
      return remindDate.toDateString() === now.toDateString();
    case 'week':
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay());
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekStart.getDate() + 6);
      return remindDate >= weekStart && remindDate <= weekEnd;
    case 'month':
      return (
        remindDate.getMonth() === now.getMonth() &&
        remindDate.getFullYear() === now.getFullYear()
      );
    case 'overdue':
      return !reminder.isPaid && remindDate < now;
    default:
      return true;
  }
};

// 过滤后的提醒
const filteredReminders = computed(() => {
  let filtered = [...props.reminders];

  // 状态过滤
  if (filters.value.status) {
    filtered = filtered.filter((reminder) => {
      const status = getStatusClass(reminder);
      return status === filters.value.status;
    });
  }

  // 周期类型过滤
  if (filters.value.period) {
    filtered = filtered.filter(
      (reminder) => reminder.repeatPeriod.type === filters.value.period,
    );
  }

  // 分类过滤
  if (filters.value.category) {
    filtered = filtered.filter(
      (reminder) => reminder.category === filters.value.category,
    );
  }

  // 日期范围过滤
  if (filters.value.dateRange) {
    filtered = filtered.filter((reminder) =>
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
const handlePageChange = (page: number) => {
  currentPage.value = page;
};

// 监听过滤器变化，重置到第一页
watch(
  filters,
  () => {
    currentPage.value = 1;
  },
  {deep: true},
);

// 原有的方法
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
  if (reminder.isPaid) return t('optionsAndStatus.paid');
  if (isOverdue(reminder)) return t('optionsAndStatus.overdue');
  return t('optionsAndStatus.pending');
};
</script>

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
