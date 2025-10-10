<script setup lang="ts">
import {
  AlertCircle,
  CheckCircle,
  Clock,
} from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { getRepeatTypeName, lowercaseFirstLetter } from '@/utils/common';
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
  <div class="reminder-container">
    <!-- 过滤器区域 -->
    <div class="screening-filtering">
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

      <button
        class="screening-filtering-select"
        @click="resetFilters"
      >
        <LucideRotateCcw class="wh-5 mr-1" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-container">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="pagination.paginatedItems.value.length === 0" class="empty-state-container">
      <div class="empty-state-icon">
        <i class="icon-bell" />
      </div>
      <div class="empty-state-text">
        {{ pagination.totalItems.value === 0 ? t('messages.noReminder') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 提醒网格 -->
    <div
      v-else
      class="reminder-grid"
      :class="[
        { 'grid-template-columns-320': !mediaQueries.isMobile },
      ]"
    >
      <div
        v-for="reminder in pagination.paginatedItems.value" :key="reminder.serialNum"
        class="reminder-card"
        :class="[
          {
            'reminder-card-overdue': isOverdue(reminder),
            'reminder-card-paid': reminder.isPaid,
          },
        ]"
      >
        <div class="reminder-header">
          <div class="reminder-title">
            {{ reminder.name }}
          </div>
          <div class="reminder-actions">
            <div
              class="status-badge" :class="[
                getStatusClass(reminder) === 'paid' ? 'status-badge-paid'
                : getStatusClass(reminder) === 'overdue' ? 'status-badge-overdue'
                  : 'status-badge-pending',
              ]"
            >
              <component :is="getStatusIcon(reminder)" class="status-icon" />
              <span>{{ getStatusText(reminder) }}</span>
            </div>
            <div class="action-buttons">
              <button
                v-if="!reminder.isPaid"
                class="money-option-btn money-option-ben-hover)"
                :title="t('financial.transaction.markPaid')"
                @click="emit('markPaid', reminder.serialNum, !reminder.isPaid)"
              >
                <LucideCheckCircle class="wh-4" />
              </button>
              <button
                class="money-option-btn money-option-edit-hover" :title="t('common.actions.edit')"
                @click="emit('edit', reminder)"
              >
                <LucideEdit class="wh-4" />
              </button>
              <button
                class="money-option-btn money-option-trash-hover"
                :title="t('common.actions.delete')" @click="emit('delete', reminder.serialNum)"
              >
                <LucideTrash class="wh-4" />
              </button>
            </div>
          </div>
        </div>

        <div
          v-if="reminder.amount"
          class="reminder-amount"
        >
          <span class="amount-value">
            {{ formatCurrency(reminder.amount) }}
          </span>
          <span
            v-if="reminder.currency"
            class="amount-currency"
          >
            {{ reminder.currency.code }}
          </span>
        </div>

        <div class="reminder-dates">
          <div v-if="reminder.billDate" class="date-row">
            <span class="date-label">{{ t('financial.billDate') }}</span>
            <span class="date-value">{{ DateUtils.formatDate(reminder.billDate) }}</span>
          </div>
          <div class="date-row">
            <span class="date-label">{{ t('date.reminderDate') }}</span>
            <span class="date-value">{{ DateUtils.formatDate(reminder.remindDate) }}</span>
          </div>
        </div>

        <div class="reminder-period">
          <LucideRepeat class="period-icon" />
          <span>{{ getRepeatTypeName(reminder.repeatPeriod) }}</span>
        </div>

        <div class="reminder-info">
          <div class="info-row">
            <span class="info-label"> {{ t('common.misc.types') }} </span>
            <span class="info-value">{{ t(`financial.reminder.types.${lowercaseFirstLetter(reminder.type)}`) }}</span>
          </div>
          <div class="info-row">
            <span class="info-label"> {{ t('date.createDate') }} </span>
            <span class="info-value">{{ DateUtils.formatDate(reminder.createdAt) }}</span>
          </div>
          <div v-if="reminder.description" class="info-row">
            <span class="info-label"> {{ t('common.misc.remark') }} </span>
            <span class="info-value">{{ reminder.description }}</span>
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
/* Container */
.reminder-container {
  min-height: 6.25rem;
}

/* Loading and Empty States */
.loading-container {
  color: #4b5563;
  height: 6.25rem;
  display: flex;
  justify-content: center;
  align-items: center;
}

.empty-state-container {
  color: #999;
  display: flex;
  flex-direction: column;
  height: 6.25rem;
  justify-content: center;
  align-items: center;
}

.empty-state-icon {
  font-size: 0.875rem;
  margin-bottom: 0.5rem;
  opacity: 0.5;
}

.empty-state-text {
  font-size: 0.875rem;
}

/* Reminder Grid */
.reminder-grid {
  margin-bottom: 0.5rem;
  gap: 0.5rem;
  display: grid;
  width: 100%;
}

/* Ensure grid-template-columns-320 works properly */
.reminder-grid.grid-template-columns-320 {
  grid-template-columns: repeat(auto-fit, minmax(20rem, 1fr));
}

/* Reminder Card */
.reminder-card {
  background-color: var(--color-base-100);
  padding: 0.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  transition: box-shadow 0.2s ease-in-out;
}

.reminder-card:hover {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

.reminder-card-overdue {
  border-color: #ef4444;
  background-color: #fef2f2;
}

.reminder-card-paid {
  opacity: 0.8;
  background-color: #f0fdf4;
  border-color: #4ade80;
}

/* Reminder Header */
.reminder-header {
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.reminder-title {
  font-size: 1.125rem;
  color: #1f2937;
  font-weight: 600;
}

.reminder-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

/* Status Badge */
.status-badge {
  font-size: 0.75rem;
  font-weight: 500;
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  display: inline-flex;
  gap: 0.375rem;
  align-items: center;
}

.status-badge-paid {
  background-color: #dcfce7;
  color: #16a34a;
}

.status-badge-overdue {
  background-color: #fee2e2;
  color: #dc2626;
}

.status-badge-pending {
  background-color: #dbeafe;
  color: #2563eb;
}

.status-icon {
  height: 1rem;
  width: 1rem;
}

/* Action Buttons */
.action-buttons {
  display: flex;
  gap: 0.25rem;
}

/* Reminder Amount */
.reminder-amount {
  margin-bottom: 1rem;
  display: flex;
  gap: 0.5rem;
  align-items: baseline;
}

.amount-value {
  font-size: 1.5rem;
  color: #1f2937;
  font-weight: 600;
}

.amount-currency {
  font-size: 0.875rem;
  color: #1f2937;
}

/* Reminder Dates */
.reminder-dates {
  margin-bottom: 0.5rem;
  gap: 0.5rem;
  display: flex;
  flex-direction: column;
}

.date-row {
  font-size: 0.875rem;
  display: flex;
  justify-content: space-between;
}

.date-label {
  color: #4b5563;
}

.date-value {
  color: #1f2937;
}

/* Reminder Period */
.reminder-period {
  font-size: 0.875rem;
  color: #4b5563;
  margin-bottom: 0.5rem;
  display: flex;
  gap: 0.5rem;
  align-items: center;
  justify-content: flex-end;
}

.period-icon {
  height: 1rem;
  width: 1rem;
}

/* Reminder Info */
.reminder-info {
  font-size: 0.875rem;
  padding-top: 1rem;
  border-top: 1px solid #e5e7eb;
  gap: 0.5rem;
  display: flex;
  flex-direction: column;
}

.info-row {
  display: flex;
  justify-content: space-between;
}

.info-label {
  color: #4b5563;
}

.info-value {
  color: #1f2937;
}
</style>
