<script setup lang="ts">
import {
  AlertCircle,
  CheckCircle,
  Clock,
} from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { getRepeatTypeName } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { useBilReminderFilters } from '../composables/useBilReminderFilters';
import { formatCurrency } from '../utils/money';
import type { BilReminder } from '@/schema/money';

const emit = defineEmits<{
  edit: [reminder: BilReminder];
  delete: [serialNum: string];
  markPaid: [serialNum: string, isPaid: boolean];
}>();

const { t } = useI18n();
const moneyStore = useMoneyStore();
const reminders = computed(() => moneyStore.remindersPaged);
const mediaQueries = useMediaQueriesStore();
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

watch(filters, async () => {
  await handlePageChange(1);
}, { deep: true });

watch(() => filters.value.repeatPeriodType, repeatPeriodType => {
  if (repeatPeriodType === 'undefined') {
    filters.value.repeatPeriodType = undefined;
  }
});

onMounted(() => {
  loadReminders();
},
);

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadReminders,
});
</script>

<template>
  <div class="min-h-25">
    <!-- 过滤器区域 -->
    <div class="mb-5 p-4 rounded-lg bg-gray-50 flex flex-wrap gap-3 items-center justify-center">
      <div class="filter-flex-wrap">
        <select
          v-model="filters.status"
          class="text-sm px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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

      <div class="filter-flex-wrap">
        <select
          v-model="filters.repeatPeriodType"
          class="text-sm px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
          class="text-sm px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
          class="text-sm px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
        class="text-sm text-gray-700 px-3 py-1.5 rounded-md bg-gray-200 transition-colors hover:bg-gray-300"
        @click="resetFilters"
      >
        <LucideRotateCcw class="wh-5 mr-1" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="text-gray-600 h-25 flex-justify-center">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="pagination.paginatedItems.value.length === 0" class="text-#999 flex-col h-25 flex-justify-center">
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
      class="reminder-grid mb-6 gap-5 grid w-full"
      :class="[
        { 'grid-template-columns-320': !mediaQueries.isMobile },
      ]"
    >
      <div
        v-for="reminder in pagination.paginatedItems.value" :key="reminder.serialNum" class="reminder-card p-5 border rounded-lg bg-white shadow-md transition-shadow hover:shadow-lg" :class="[
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
          <div class="flex gap-2 items-center">
            <div
              class="text-xs font-medium px-2 py-1 rounded inline-flex gap-1.5 items-center" :class="[
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
                v-if="!reminder.isPaid" class="money-option-btn hover:(text-green-500 border-green-500)"
                :title="t('financial.transaction.markPaid')" @click="emit('markPaid', reminder.serialNum, !reminder.isPaid)"
              >
                <LucideCheckCircle class="h-4 w-4" />
              </button>
              <button
                class="money-option-btn hover:(text-blue-500 border-blue-500)" :title="t('common.actions.edit')"
                @click="emit('edit', reminder)"
              >
                <LucideEdit class="h-4 w-4" />
              </button>
              <button
                class="money-option-btn hover:(text-red-500 border-red-500)"
                :title="t('common.actions.delete')" @click="emit('delete', reminder.serialNum)"
              >
                <LucideTrash class="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>

        <div
          v-if="reminder.amount"
          class="mb-4 flex gap-2 items-baseline"
        >
          <span class="text-2xl text-gray-800 font-semibold">
            {{ formatCurrency(reminder.amount) }}
          </span>
          <span
            v-if="reminder.currency"
            class="text-sm text-gray-800"
          >
            {{ reminder.currency.code }}
          </span>
        </div>

        <div class="mb-2 space-y-2">
          <div v-if="reminder.billDate" class="text-sm flex justify-between">
            <span class="text-gray-600">{{ t('financial.billDate') }}</span>
            <span class="text-gray-800">{{ DateUtils.formatDate(reminder.billDate) }}</span>
          </div>
          <div class="text-sm flex justify-between">
            <span class="text-gray-600">{{ t('date.reminderDate') }}</span>
            <span class="text-gray-800">{{ DateUtils.formatDateTime(reminder.remindDate) }}</span>
          </div>
        </div>

        <div class="text-sm text-gray-600 mb-2 flex gap-2 items-center justify-end">
          <LucideRepeat class="h-4 w-4" />
          <span>{{ getRepeatTypeName(reminder.repeatPeriod) }}</span>
        </div>

        <div class="text-sm pt-4 border-t border-gray-200 space-y-2">
          <div class="flex justify-between">
            <span class="text-gray-600"> {{ t('common.misc.types') }} </span>
            <span class="text-gray-800">{{ reminder.type }}</span>
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
    <div
      v-if="pagination.totalItems.value > pagination.pageSize.value"
      class="flex justify-center"
    >
      <SimplePagination
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

<style scoped lang="postcss">
.reminder-grid {
  display: grid;
  gap: 20px;
}

.money-option-btn {
  @apply p-1.5 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-50 transition-colors;
}
</style>
