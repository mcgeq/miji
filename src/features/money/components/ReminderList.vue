<script setup lang="ts">
import { listen } from '@tauri-apps/api/event';
import {
  AlertCircle,
  CheckCircle,
  Clock,
  MoreHorizontal,
  RotateCcw,
} from 'lucide-vue-next';
import { Card, Pagination, Spinner } from '@/components/ui';
import { useReminderStore } from '@/stores/money';
import { getRepeatTypeName, lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { toast } from '@/utils/toast';
import { useBilReminderFilters } from '../composables/useBilReminderFilters';
import { formatCurrency } from '../utils/money';
import type { BilReminder } from '@/schema/money';

const emit = defineEmits<{
  edit: [reminder: BilReminder];
  delete: [serialNum: string];
  markPaid: [serialNum: string, isPaid: boolean];
}>();

const { t } = useI18n();
const reminderStore = useReminderStore();
const reminders = computed(() => reminderStore.remindersPaged);
const mediaQueries = useMediaQueriesStore();
// 移动端过滤展开状态
const showMoreFilters = ref(!mediaQueries.isMobile);

// 切换过滤器显示状态
function toggleFilters() {
  showMoreFilters.value = !showMoreFilters.value;
}
const {
  loading,
  filters,
  resetFilters,
  uniqueCategories,
  pagination,
  getStatusClass,
  isOverdue,
  loadReminders,
} = useBilReminderFilters(() => reminders.value, 4);

function handlePageSizeChange(size: number) {
  pagination.pageSize.value = size;
}

async function handlePageChange(page: number) {
  pagination.setPage(page);
  await loadReminders();
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

watch(() => filters.value.repeatPeriodType, repeatPeriodType => {
  if (repeatPeriodType === 'undefined') {
    filters.value.repeatPeriodType = undefined;
  }
});

// 监听后端账单提醒事件，自动刷新列表（防抖）
let unlistenBilReminder: (() => void) | null = null;
function useDebounceFn<T extends (...args: any[]) => any>(fn: T, wait: number) {
  let timer: any;
  return (...args: Parameters<T>) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), wait);
  };
}
const debouncedRefresh = useDebounceFn(async () => {
  await loadReminders();
}, 500);

onMounted(async () => {
  unlistenBilReminder = await listen('bil-reminder-fired', async () => {
    debouncedRefresh();
    toast.info('收到系统账单提醒，列表已刷新');
  });
});

onUnmounted(() => {
  try {
    unlistenBilReminder && unlistenBilReminder();
  } catch (_) {

  }
});

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadReminders,
});
</script>

<template>
  <div class="min-h-[100px]">
    <!-- 过滤器区域 -->
    <div class="screening-filtering mb-4">
      <div class="filter-flex-wrap">
        <select
          v-model="filters.status"
          class="screening-filtering-select"
        >
          <option value="">
            {{ t('common.actions.all') }}{{ t('common.status.status') }}
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

      <template v-if="showMoreFilters">
        <div class="filter-flex-wrap">
          <select
            v-model="filters.repeatPeriodType"
            class="screening-filtering-select"
          >
            <option value="undefined">
              {{ t('common.actions.all') }}{{ t('todos.repeat.periodType') }}
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
          <select
            v-model="filters.category"
            class="screening-filtering-select"
          >
            <option value="undefined">
              {{ t('categories.allCategory') }}
            </option>
            <option
              v-for="category in uniqueCategories"
              :key="category"
              :value="category"
            >
              {{ category }}
            </option>
          </select>
        </div>

        <div class="filter-flex-wrap">
          <select
            v-model="filters.dateRange"
            class="screening-filtering-select"
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
      </template>

      <div class="filter-button-group">
        <button
          class="screening-filtering-select"
          @click="toggleFilters"
        >
          <MoreHorizontal class="wh-4 mr-1" />
        </button>
        <button
          class="screening-filtering-select"
          @click="resetFilters"
        >
          <RotateCcw class="wh-4 mr-1" />
        </button>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex flex-col items-center justify-center h-[100px] text-gray-600 dark:text-gray-400">
      <Spinner size="lg" />
      <span class="mt-2">{{ t('common.loading') }}</span>
    </div>

    <!-- 空状态 -->
    <div v-else-if="pagination.paginatedItems.value.length === 0" class="flex flex-col items-center justify-center h-[100px] text-gray-400 dark:text-gray-500">
      <div class="text-sm mb-2 opacity-50">
        <i class="icon-bell" />
      </div>
      <div class="text-sm">
        {{ pagination.totalItems.value === 0 ? t('messages.noReminder') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 提醒网格 -->
    <div
      v-else
      class="grid gap-4 mb-4"
      :class="[
        mediaQueries.isMobile ? 'grid-cols-1'
        : pagination.paginatedItems.value.length === 1 ? 'grid-cols-1 max-w-[50%]'
          : 'grid-cols-1 lg:grid-cols-2',
      ]"
    >
      <Card
        v-for="reminder in pagination.paginatedItems.value" :key="reminder.serialNum"
        padding="md"
        class="relative overflow-hidden transition-all hover:-translate-y-0.5 hover:shadow-lg"
        :class="[
          isOverdue(reminder) ? 'opacity-90 border-2 border-red-500 dark:border-red-600 bg-gradient-to-br from-red-50 to-red-100 dark:from-red-900/20 dark:to-red-900/30'
          : reminder.isPaid ? 'opacity-80 border-2 border-green-500 dark:border-green-600 bg-gradient-to-br from-green-50 to-green-100 dark:from-green-900/20 dark:to-green-900/30'
            : 'border border-blue-200 dark:border-blue-800 bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800',
        ]"
      >
        <div class="flex items-start justify-between mb-3 gap-2">
          <div class="text-base font-semibold text-gray-900 dark:text-white leading-tight flex-1 min-w-0">
            {{ reminder.name }}
          </div>
          <div class="flex gap-1 shrink-0 items-center">
            <div
              class="text-xs font-medium px-2 py-1 rounded-md inline-flex gap-1 items-center whitespace-nowrap"
              :class="[
                getStatusClass(reminder) === 'paid' ? 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300'
                : getStatusClass(reminder) === 'overdue' ? 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300'
                  : 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300',
              ]"
            >
              <component :is="getStatusIcon(reminder)" :size="14" class="shrink-0" />
              <span>{{ getStatusText(reminder) }}</span>
            </div>
            <div class="flex gap-1">
              <button
                v-if="!reminder.isPaid"
                class="w-8 h-8 rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-400 flex items-center justify-center transition-all hover:scale-105 active:scale-95 hover:bg-green-500 hover:text-white hover:border-green-500 dark:hover:bg-green-600 dark:hover:border-green-600"
                :title="t('financial.transaction.markPaid')"
                @click="emit('markPaid', reminder.serialNum, !reminder.isPaid)"
              >
                <LucideCheckCircle :size="16" />
              </button>
              <!-- 稍后提醒（+1小时） -->
              <button
                class="w-8 h-8 rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-400 flex items-center justify-center transition-all hover:scale-105 active:scale-95 hover:bg-blue-500 hover:text-white hover:border-blue-500 dark:hover:bg-blue-600 dark:hover:border-blue-600"
                :title="t('financial.reminder.snooze')"
                @click="$emit('edit', { ...reminder, snoozeUntil: DateUtils.getLocalISODateTimeWithOffset({ hours: 1 }) })"
              >
                <LucideClock :size="16" />
              </button>
              <button
                class="w-8 h-8 rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-400 flex items-center justify-center transition-all hover:scale-105 active:scale-95 hover:bg-blue-500 hover:text-white hover:border-blue-500 dark:hover:bg-blue-600 dark:hover:border-blue-600"
                :title="t('common.actions.edit')"
                @click="emit('edit', reminder)"
              >
                <LucideEdit :size="16" />
              </button>
              <button
                class="w-8 h-8 rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-gray-600 dark:text-gray-400 flex items-center justify-center transition-all hover:scale-105 active:scale-95 hover:bg-red-500 hover:text-white hover:border-red-500 dark:hover:bg-red-600 dark:hover:border-red-600"
                :title="t('common.actions.delete')"
                @click="emit('delete', reminder.serialNum)"
              >
                <LucideTrash :size="16" />
              </button>
            </div>
          </div>
        </div>

        <div
          v-if="reminder.amount"
          class="mb-3 flex items-baseline gap-2"
        >
          <span class="text-2xl font-bold text-gray-900 dark:text-white leading-none tracking-tight">
            {{ formatCurrency(reminder.amount) }}
          </span>
          <span
            v-if="reminder.currency"
            class="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
          >
            {{ reminder.currency.code }}
          </span>
        </div>

        <div class="mb-2 flex flex-col gap-1">
          <div v-if="reminder.billDate" class="text-xs flex justify-between items-center gap-3">
            <span class="text-gray-500 dark:text-gray-400 font-medium shrink-0">{{ t('financial.billDate') }}</span>
            <span class="text-gray-900 dark:text-white font-medium text-right">{{ DateUtils.formatDate(reminder.billDate) }}</span>
          </div>
          <div class="text-xs flex justify-between items-center gap-3">
            <span class="text-gray-500 dark:text-gray-400 font-medium shrink-0">{{ t('date.reminderDate') }}</span>
            <span class="text-gray-900 dark:text-white font-medium text-right">{{ DateUtils.formatDate(reminder.remindDate) }}</span>
          </div>
          <div v-if="reminder.lastReminderSentAt" class="text-xs flex justify-between items-center gap-3">
            <span class="text-gray-500 dark:text-gray-400 font-medium shrink-0">{{ t('financial.reminder.lastReminderSentAt') }}</span>
            <span class="text-gray-900 dark:text-white font-medium text-right">{{ DateUtils.formatDateTime(reminder.lastReminderSentAt) }}</span>
          </div>
        </div>

        <div class="text-xs text-gray-500 dark:text-gray-400 mb-2 flex gap-1.5 items-center justify-end">
          <LucideRepeat :size="14" class="shrink-0" />
          <span>{{ getRepeatTypeName(reminder.repeatPeriod) }}</span>
        </div>

        <div class="pt-3 border-t border-gray-200 dark:border-gray-700 flex flex-col gap-1">
          <div class="text-xs flex justify-between items-center gap-3">
            <span class="text-gray-500 dark:text-gray-400 font-medium shrink-0"> {{ t('common.misc.types') }} </span>
            <span class="text-gray-900 dark:text-white font-medium text-right">{{ t(`financial.reminder.types.${lowercaseFirstLetter(reminder.type)}`) }}</span>
          </div>
          <div v-if="reminder.description" class="text-xs flex justify-between items-center gap-3">
            <span class="text-gray-500 dark:text-gray-400 font-medium shrink-0"> {{ t('common.misc.remark') }} </span>
            <span class="text-gray-900 dark:text-white font-medium text-right truncate">{{ reminder.description }}</span>
          </div>
        </div>
      </Card>
    </div>

    <!-- 分页组件 -->
    <div
      v-if="pagination.totalItems.value > pagination.pageSize.value"
      class="flex justify-center mb-16 lg:mb-4 pb-4"
    >
      <Pagination
        :current-page="pagination.currentPage.value"
        :total-pages="pagination.totalPages.value"
        :total-items="pagination.totalItems.value"
        :page-size="pagination.pageSize.value"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
    </div>
  </div>
</template>
