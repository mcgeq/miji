<script setup lang="ts">
import { listen } from '@tauri-apps/api/event';
import {
  AlertCircle,
  CheckCircle,
  Clock,
  MoreHorizontal,
  RotateCcw,
} from 'lucide-vue-next';
import { Pagination } from '@/components/ui';
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

onMounted(() => {
  loadReminders();
},
);

// 根据项目数量决定网格布局
const gridLayoutClass = computed(() => {
  const itemCount = pagination.paginatedItems.value.length;

  if (mediaQueries.isMobile) {
    // 移动端布局：一行一个，100%宽度
    return 'grid-template-columns-mobile-single';
  } else {
    // 桌面端布局
    if (itemCount === 1) {
      return 'grid-template-columns-single-50';
    } else {
      // 2个或更多项目时，强制每行最多2个项目
      return 'grid-template-columns-320-max2';
    }
  }
});

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadReminders,
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
      :class="gridLayoutClass"
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
              <!-- 稍后提醒（+1小时） -->
              <button
                class="money-option-btn money-option-edit-hover"
                :title="t('financial.reminder.snooze')"
                @click="$emit('edit', { ...reminder, snoozeUntil: DateUtils.getLocalISODateTimeWithOffset({ hours: 1 }) })"
              >
                <LucideClock class="wh-4" />
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
          <div v-if="reminder.lastReminderSentAt" class="date-row">
            <span class="date-label">{{ t('financial.reminder.lastReminderSentAt') }}</span>
            <span class="date-value">{{ DateUtils.formatDateTime(reminder.lastReminderSentAt) }}</span>
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
      class="pagination-container"
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

<style scoped lang="postcss">
/* Container */
.reminder-container {
  min-height: 6.25rem;
}

/* 移动端滚动优化 */
@media (max-width: 768px) {
  .reminder-container {
    min-height: auto; /* 移动端允许内容自适应高度 */
    padding-bottom: 1rem; /* 额外的底部空间 */
  }
}

/* Loading and Empty States */
.loading-container {
  color: var(--color-gray-600);
  height: 6.25rem;
  display: flex;
  justify-content: center;
  align-items: center;
}

.empty-state-container {
  color: var(--color-gray-400);
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

/* Reminder Grid - 优化网格布局 */
.reminder-grid {
  margin-bottom: 1rem;
  gap: 1rem;
  display: grid;
}

/* 网格布局类 - 响应式设计 */
.grid-template-columns-mobile-single {
  grid-template-columns: 1fr;
}

/* 桌面端单个项目占50%宽度 */
.grid-template-columns-single-50 {
  grid-template-columns: 1fr;
  max-width: 50%;
}

/* 桌面端布局 */
.grid-template-columns-320-two-items,
.grid-template-columns-320-max2 {
  grid-template-columns: repeat(2, 1fr);
}

/* 移动端优化 */
@media (max-width: 768px) {
  .reminder-grid {
    gap: 0.75rem;
    margin-bottom: 0.75rem;
  }

  .grid-template-columns-mobile-single,
  .grid-template-columns-single-50,
  .grid-template-columns-320-two-items,
  .grid-template-columns-320-max2 {
    grid-template-columns: 1fr;
    max-width: 100%;
  }
}

/* 桌面端优化 */
@media (min-width: 769px) {
  .reminder-grid {
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .grid-template-columns-single-50 {
    grid-template-columns: 1fr;
    max-width: 50%;
  }

  .grid-template-columns-320-two-items,
  .grid-template-columns-320-max2 {
    grid-template-columns: repeat(2, 1fr);
    max-width: none;
  }
}

/* Reminder Card - 重新设计为更紧凑美观的卡片 */
.reminder-card {
  background: linear-gradient(135deg, var(--color-base-100) 0%, var(--color-base-200) 100%);
  padding: 1rem;
  border: 1px solid var(--color-primary-soft);
  border-radius: 0.75rem;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
}

.reminder-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: var(--color-primary-gradient);
  opacity: 0;
  transition: opacity 0.3s ease;
}

.reminder-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-lg);
  border-color: var(--color-primary);
}

.reminder-card:hover::before {
  opacity: 1;
}

.reminder-card-overdue {
  opacity: 0.9;
  border-color: var(--color-error);
  background: linear-gradient(135deg, var(--color-error-50) 0%, var(--color-error-100) 100%);
}

.reminder-card-overdue::before {
  background: var(--color-error);
  opacity: 0;
}

.reminder-card-overdue:hover::before {
  opacity: 1;
}

.reminder-card-paid {
  opacity: 0.8;
  background: linear-gradient(135deg, var(--color-success-50) 0%, var(--color-success-100) 100%);
  border-color: var(--color-success);
}

.reminder-card-paid::before {
  background: var(--color-success);
  opacity: 0;
}

.reminder-card-paid:hover::before {
  opacity: 1;
}

/* Reminder Header - 更紧凑的布局 */
.reminder-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  gap: 0.5rem;
}

.reminder-title {
  font-size: 1rem;
  color: var(--color-base-content);
  font-weight: 600;
  line-height: 1.2;
  flex: 1;
  min-width: 0;
}

.reminder-actions {
  display: flex;
  gap: 0.25rem;
  flex-shrink: 0;
  align-items: center;
}

/* Status Badge */
.status-badge {
  font-size: 0.6875rem;
  font-weight: 500;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  display: inline-flex;
  gap: 0.25rem;
  align-items: center;
  white-space: nowrap;
}

.status-badge-paid {
  background-color: var(--color-success-soft);
  color: var(--color-success);
}

.status-badge-overdue {
  background-color: var(--color-error-soft);
  color: var(--color-error);
}

.status-badge-pending {
  background-color: var(--color-info-soft);
  color: var(--color-info);
}

.status-icon {
  height: 0.875rem;
  width: 0.875rem;
  flex-shrink: 0;
}

/* Action Buttons - 更优雅的按钮 */
.action-buttons {
  display: flex;
  gap: 0.25rem;
}

/* Reminder Amount - 突出显示 */
.reminder-amount {
  margin-bottom: 0.75rem;
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
}

.amount-value {
  font-size: 1.375rem;
  color: var(--color-base-content);
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.025em;
}

.amount-currency {
  font-size: 0.8125rem;
  color: var(--color-gray-500);
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

/* Reminder Dates - 紧凑布局 */
.reminder-dates {
  margin-bottom: 0.5rem;
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.date-row {
  font-size: 0.8125rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
}

.date-label {
  color: var(--color-gray-500);
  font-weight: 500;
  flex-shrink: 0;
}

.date-value {
  color: var(--color-base-content);
  font-weight: 500;
  text-align: right;
}

/* Reminder Period - 紧凑布局 */
.reminder-period {
  font-size: 0.75rem;
  color: var(--color-gray-500);
  margin-bottom: 0.5rem;
  display: flex;
  gap: 0.375rem;
  align-items: center;
  justify-content: flex-end;
}

.period-icon {
  height: 0.875rem;
  width: 0.875rem;
  flex-shrink: 0;
  color: var(--color-gray-500);
}

/* Reminder Info - 紧凑布局 */
.reminder-info {
  padding-top: 0.75rem;
  border-top: 1px solid var(--color-gray-200);
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.info-row {
  font-size: 0.8125rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
}

.info-label {
  color: var(--color-gray-500);
  font-weight: 500;
  flex-shrink: 0;
}

.info-value {
  color: var(--color-base-content);
  font-weight: 500;
  text-align: right;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Additional utility styles */
.filter-button-group {
  display: flex;
  gap: 0.25rem;
}

/* 操作按钮样式 - 与 AccountList 一致 */
.money-option-btn {
  width: 2rem;
  height: 2rem;
  border-radius: 0.5rem;
  border: 1px solid var(--color-gray-200);
  background: var(--color-base-100);
  color: var(--color-gray-600);
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease;
  cursor: pointer;
  position: relative;
  overflow: hidden;
}

.money-option-btn::before {
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: var(--color-primary);
  opacity: 0;
  transition: opacity 0.2s ease;
}

.money-option-btn:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
  transform: scale(1.05);
}

.money-option-btn:hover::before {
  opacity: 0.1;
}

.money-option-btn:active {
  transform: scale(0.95);
}

.money-option-ben-hover:hover {
  background-color: var(--color-success);
  color: var(--color-success-content);
  border-color: var(--color-success);
}

.money-option-edit-hover:hover {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border-color: var(--color-primary);
}

.money-option-trash-hover:hover {
  background-color: var(--color-error);
  color: var(--color-error-content);
  border-color: var(--color-error);
}

.pagination-container {
  display: flex;
  justify-content: center;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .reminder-card {
    padding: 0.875rem;
  }

  .reminder-header {
    margin-bottom: 0.625rem;
  }

  .reminder-title {
    font-size: 0.9375rem;
  }

  .money-option-btn {
    width: 1.75rem;
    height: 1.75rem;
  }

  .amount-value {
    font-size: 1.25rem;
  }

  .reminder-info {
    padding-top: 0.625rem;
  }

  .info-row {
    font-size: 0.75rem;
  }

  .date-row {
    font-size: 0.75rem;
  }

  .reminder-period {
    font-size: 0.6875rem;
  }

  .pagination-container {
    margin-bottom: 4rem; /* 为底部导航栏预留空间 */
    padding-bottom: 1rem; /* 额外的底部内边距 */
  }
}
</style>
