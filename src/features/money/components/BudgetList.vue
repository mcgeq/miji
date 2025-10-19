<script setup lang="ts">
import { MoreHorizontal, RotateCcw } from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { getRepeatTypeName, lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { useBudgetFilters } from '../composables/useBudgetFilters';
import { formatCurrency } from '../utils/money';
import type { Budget } from '@/schema/money';

type BudgetVM = Budget & {
  displayCategories: string;
  tooltipCategories: string;
};

const emit = defineEmits<{
  edit: [budget: Budget];
  delete: [serialNum: string];
  toggleActive: [serialNum: string, isActive: boolean];
}>();

const { t } = useI18n();
const moneyStore = useMoneyStore();
const budgets = computed(() => moneyStore.budgetsPaged);
const mediaQueries = useMediaQueriesStore();
// 移动端过滤展开状态
const showMoreFilters = ref(!mediaQueries.isMobile);

// 切换过滤器显示状态
function toggleFilters() {
  showMoreFilters.value = !showMoreFilters.value;
}

const { loading, filters, resetFilters, pagination, loadBudgets } = useBudgetFilters(
  () => budgets.value,
  4,
);

const categories = computed(() => moneyStore.subCategories);
// 获取唯一分类
const uniqueCategories = computed(() => {
  const allCategories = [...new Set(categories.value.map(item => item.categoryName))];
  return allCategories;
});

const decoratedBudgets = computed<BudgetVM[]>(() =>
  pagination.paginatedItems.value.map(b => {
    const cats = Array.isArray(b.categoryScope) ? b.categoryScope : [];
    return {
      ...b,
      displayCategories: parseSubCategories(cats),
      tooltipCategories: cats.join(', '),
    };
  }),
);

// 原有的方法
function getProgressPercent(budget: Budget) {
  const progress = Number(budget.progress ?? 0);
  return progress;
}

function isOverBudget(budget: Budget) {
  return Number(budget.usedAmount) > Number(budget.amount);
}

function isLowOnBudget(budget: Budget) {
  const percent = getProgressPercent(budget);
  return percent > 70;
}

function shouldHighlightRed(budget: Budget) {
  return isOverBudget(budget) || isLowOnBudget(budget);
}

function getRemainingAmount(budget: Budget) {
  return (Number(budget.amount) - Number(budget.usedAmount)).toString();
}
async function handlePageChange(page: number) {
  pagination.setPage(page);
}

function handlePageSizeChange(size: number) {
  pagination.pageSize.value = size;
}

function parseSubCategories(sub: string[]) {
  if (!sub)
    return '';
  const s = sub.map(item => item.trim());
  const translated = s.map(item => {
    const key = lowercaseFirstLetter(item);
    return t(`common.categories.${key}`);
  });
  return translated.join(',');
}

// 组件挂载时加载数据
onMounted(() => {
  loadBudgets();
});

// 根据项目数量决定网格布局
const gridLayoutClass = computed(() => {
  const itemCount = pagination.paginatedItems.value.length;

  if (mediaQueries.isMobile) {
    // 移动端布局：一行一个，100%宽度
    return 'grid-template-columns-mobile-single';
  } else {
    // 桌面端布局
    if (itemCount === 1) {
      return 'grid-template-columns-320-single';
    } else if (itemCount === 2) {
      return 'grid-template-columns-320-two-items';
    } else {
      // 3个或更多项目时，强制每行最多2个项目
      return 'grid-template-columns-320-max2';
    }
  }
});

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadBudgets,
});
</script>

<template>
  <div class="budget-container">
    <!-- 过滤器区域 -->
    <div class="screening-filtering">
      <div class="filter-flex-wrap">
        <select
          v-model="filters.isActive"
          class="screening-filtering-select"
        >
          <option value="">
            {{ t('common.actions.all') }}{{ t('common.status.status') }}
          </option>
          <option value="active">
            {{ t('common.status.active') }}
          </option>
          <option value="inactive">
            {{ t('common.status.inactive') }}
          </option>
        </select>
      </div>

      <!-- <div class="filter-flex-wrap"> -->
      <!--   <label class="show-on-desktop text-sm text-gray-700 font-medium"> {{ t('common.status.completed') }}{{ -->
      <!--     t('common.status.status') }} </label> -->
      <!--   <select -->
      <!--     v-model="filters.completion" -->
      <!--     class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500" -->
      <!--   > -->
      <!--     <option value=""> -->
      <!--       {{ t('common.actions.all') }} -->
      <!--     </option> -->
      <!--     <option value="normal"> -->
      <!--       {{ t('common.status.normal') }} -->
      <!--     </option> -->
      <!--     <option value="warning"> -->
      <!--       {{ t('common.status.warning') }}(>70%) -->
      <!--     </option> -->
      <!--     <option value="exceeded"> -->
      <!--       {{ t('common.status.exceeded') }} -->
      <!--     </option> -->
      <!--   </select> -->
      <!-- </div> -->

      <template v-if="showMoreFilters">
        <div class="filter-flex-wrap">
          <select
            v-model="filters.repeatPeriodType"
            class="screening-filtering-select"
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
          <select
            v-model="filters.category"
            class="screening-filtering-select"
          >
            <option :value="null">
              {{ t('categories.allCategory') }}
            </option>
            <option v-for="category in uniqueCategories" :key="category" :value="category">
              {{ t(`common.categories.${lowercaseFirstLetter(category)}`) }}
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
        <i class="icon-target" />
      </div>
      <div class="empty-state-text">
        {{ pagination.totalItems.value === 0 ? t('financial.messages.noBudget') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 预算网格 -->
    <div
      v-else
      class="budget-grid"
      :class="gridLayoutClass"
    >
      <div
        v-for="budget in decoratedBudgets"
        :key="budget.serialNum"
        class="budget-card"
        :class="[
          { 'budget-card-inactive': !budget.isActive },
        ]" :style="{
          borderColor: budget.color || '#E5E7EB',
        }"
      >
        <!-- Header -->
        <div class="budget-header">
          <!-- 左侧预算名称 -->
          <div class="budget-info">
            <span class="budget-name">{{ budget.name }}</span>
            <!-- 状态标签 -->
            <span v-if="!budget.isActive" class="status-tag status-inactive">
              {{ t('common.status.inactive') }}
            </span>
            <span v-else-if="isOverBudget(budget)" class="status-tag status-exceeded">
              {{ t('common.status.exceeded') }}
            </span>
            <span
              v-else-if="isLowOnBudget(budget)"
              class="status-tag status-warning"
            >
              {{ t('common.status.warning') }}
            </span>
          </div>

          <!-- 右侧按钮组 -->
          <div class="budget-actions">
            <button
              class="money-option-btn money-option-edit-hover" :title="t('common.actions.edit')"
              @click="budget.isActive && emit('edit', budget)"
            >
              <LucideEdit class="wh-4" />
            </button>
            <button
              class="money-option-btn money-option-ben-hover"
              :title="budget.isActive ? t('common.status.stop') : t('common.status.enabled')"
              @click="emit('toggleActive', budget.serialNum, !budget.isActive)"
            >
              <LucideBan v-if="budget.isActive" class="wh-4" />
              <LucideStopCircle v-else class="wh-4" />
            </button>
            <button
              class="money-option-btn money-option-trash-hover"
              :title="t('common.actions.delete')" @click="emit('delete', budget.serialNum)"
            >
              <LucideTrash class="wh-4" />
            </button>
          </div>
        </div>

        <!-- Period -->
        <div class="budget-period">
          <LucideRepeat class="period-icon" />
          <span>{{ getRepeatTypeName(budget.repeatPeriod) }}</span>
        </div>

        <!-- Progress -->
        <div class="budget-progress">
          <div class="progress-header">
            <span class="used-amount">{{ formatCurrency(budget.usedAmount) }}</span>
            <span class="total-amount">/ {{ formatCurrency(budget.amount) }}</span>
            <div class="remaining-amount-container">
              <div
                class="remaining-amount" :class="[
                  shouldHighlightRed(budget) ? 'remaining-amount-error' : 'remaining-amount-success',
                ]"
              >
                {{ formatCurrency(getRemainingAmount(budget)) }}
              </div>
            </div>
          </div>
          <div class="progress-bar">
            <div
              class="progress-fill" :style="{ width: `${getProgressPercent(budget)}%` }"
              :class="isOverBudget(budget) ? 'progress-fill-error' : 'progress-fill-primary'"
            />
          </div>
          <div class="progress-percentage" :class="shouldHighlightRed(budget) ? 'progress-percentage-error' : 'progress-percentage-normal'">
            {{ getProgressPercent(budget) }}%
          </div>
        </div>

        <!-- Info -->
        <div class="budget-info-section">
          <div class="info-row">
            <span class="info-label"> {{ t('categories.category') }} </span>
            <span
              class="info-value"
              :title="budget.tooltipCategories"
            >
              {{ budget.displayCategories }}
            </span>
          </div>
          <div class="info-row">
            <span class="info-label"> {{ t('date.createDate') }} </span>
            <span class="info-value">{{ DateUtils.formatDate(budget.createdAt) }}</span>
          </div>
          <div v-if="budget.description" class="info-row info-row-last">
            <span class="info-label">{{ t('common.misc.remark') }}</span>
            <span class="info-value">{{ budget.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="pagination.totalItems.value > pagination.pageSize.value" class="pagination-container">
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
.budget-container {
  min-height: 6.25rem;
}

/* 移动端滚动优化 */
@media (max-width: 768px) {
  .budget-container {
    min-height: auto; /* 移动端允许内容自适应高度 */
    padding-bottom: 1rem; /* 额外的底部空间 */
  }
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

/* Budget Grid */
.budget-grid {
  margin-bottom: 0.5rem;
  gap: 0.5rem;
  display: grid;
}

/* Budget Card */
.budget-card {
  background-color: var(--color-base-100);
  padding: 0.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.375rem;
  transition: all 0.2s ease-in-out;
}

.budget-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.budget-card-inactive {
  opacity: 0.6;
  background-color: #f3f4f6;
}

/* Budget Header */
.budget-header {
  margin-bottom: 0.5rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  justify-content: space-between;
}

.budget-info {
  color: #1f2937;
  display: flex;
  align-items: center;
}

.budget-name {
  font-size: 1.125rem;
  font-weight: 600;
}

/* Status Tags */
.status-tag {
  font-size: 0.75rem;
  margin-left: 0.5rem;
  padding: 0.125rem 0.5rem;
  border-radius: 0.25rem;
}

.status-inactive {
  color: #4b5563;
  background-color: #e5e7eb;
}

.status-exceeded {
  color: #dc2626;
  background-color: #fee2e2;
}

.status-warning {
  color: #d97706;
  background-color: #fef3c7;
}

/* Budget Actions */
.budget-actions {
  display: flex;
  gap: 0.25rem;
  align-items: center;
}

@media (min-width: 768px) {
  .budget-actions {
    align-self: flex-end;
  }
}

/* Budget Period */
.budget-period {
  font-size: 0.875rem;
  color: #4b5563;
  margin-bottom: 0.25rem;
  display: flex;
  gap: 0.25rem;
  align-items: center;
  justify-content: flex-end;
}

.period-icon {
  color: #4b5563;
  height: 1rem;
  width: 1rem;
}

/* Budget Progress */
.budget-progress {
  margin-bottom: 0.5rem;
}

.progress-header {
  display: flex;
  gap: 0.25rem;
  align-items: baseline;
}

.used-amount {
  font-size: 1.125rem;
  color: #1f2937;
  font-weight: 600;
}

.total-amount {
  font-size: 0.875rem;
  color: #4b5563;
}

.remaining-amount-container {
  background-color: var(--color-base-200);
  margin-bottom: 0.5rem;
  margin-left: auto;
  padding: 0.375rem;
  border-radius: 0.375rem;
  display: flex;
  justify-content: flex-end;
}

.remaining-amount {
  font-size: 1.125rem;
  font-weight: 600;
}

.progress-bar {
  margin-bottom: 0.25rem;
  border-radius: 0.375rem;
  background-color: #e5e7eb;
  height: 0.25rem;
  width: 100%;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  transition: width 0.3s ease;
}

.progress-percentage {
  font-size: 1.125rem;
  text-align: center;
}

/* Budget Info Section */
.budget-info-section {
  padding-top: 0.5rem;
  border-top: 1px solid #e5e7eb;
}

.info-row {
  font-size: 0.875rem;
  margin-bottom: 0.25rem;
  display: flex;
  justify-content: space-between;
}

.info-row-last {
  margin-bottom: 0;
}

.info-label {
  color: #4b5563;
  font-weight: 500;
}

.info-value {
  color: #1f2937;
  font-weight: 500;
}

/* Additional utility styles */
.pagination-container {
  display: flex;
  justify-content: center;
}

/* 移动端分页组件底部安全间距 */
@media (max-width: 768px) {
  .pagination-container {
    margin-bottom: 4rem; /* 为底部导航栏预留空间 */
    padding-bottom: 1rem; /* 额外的底部内边距 */
  }
}

.progress-fill-error {
  background-color: #ef4444;
}

.progress-fill-primary {
  background-color: #3b82f6;
}

.remaining-amount-error {
  color: #ef4444;
}

.remaining-amount-success {
  color: #16a34a;
}

.progress-percentage-error {
  color: #ef4444;
}

.progress-percentage-normal {
  color: #4b5563;
}

.filter-button-group {
  display: flex;
  gap: 0.25rem;
}
</style>
