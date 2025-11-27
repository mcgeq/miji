<script setup lang="ts">
import { BarChart3, MoreHorizontal, RotateCcw } from 'lucide-vue-next';
import { Pagination } from '@/components/ui';
import { useBudgetStore, useCategoryStore } from '@/stores/money';
import { getRepeatTypeName, lowercaseFirstLetter } from '@/utils/common';
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
const router = useRouter();
const budgetStore = useBudgetStore();
const categoryStore = useCategoryStore();
const budgets = computed(() => budgetStore.budgetsPaged);
const mediaQueries = useMediaQueriesStore();
// 移动端过滤展开状态
const showMoreFilters = ref(!mediaQueries.isMobile);

// 切换过滤器显示状态
function toggleFilters() {
  showMoreFilters.value = !showMoreFilters.value;
}

// 路由跳转到预算统计分析页面
function navigateToStats() {
  router.push('/budget-stats');
}

const { loading, filters, resetFilters, pagination, loadBudgets } = useBudgetFilters(
  () => budgets.value,
  4,
);

const categories = computed(() => categoryStore.subCategories);
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
      return 'grid-template-columns-single-50';
    } else {
      // 2个或更多项目时，强制每行最多2个项目
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
      <!-- 统计按钮组 - 移到最前面 -->
      <div class="stats-button-group">
        <button
          class="screening-filtering-select stats-button"
          :title="t('financial.budget.statsAndTrends')"
          @click="navigateToStats"
        >
          <BarChart3 class="wh-4" />
        </button>
      </div>

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
          :title="t('common.actions.moreFilters')"
          @click="toggleFilters"
        >
          <MoreHorizontal class="wh-4 mr-1" />
        </button>
        <button
          class="screening-filtering-select"
          :title="t('common.actions.reset')"
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
          borderColor: budget.color || 'var(--color-gray-200)',
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
              class="money-option-btn money-option-ben-hover"
              :title="budget.isActive ? t('common.status.stop') : t('common.status.enabled')"
              @click="emit('toggleActive', budget.serialNum, !budget.isActive)"
            >
              <LucideBan v-if="budget.isActive" class="wh-4" />
              <LucideStopCircle v-else class="wh-4" />
            </button>
            <!-- 禁用状态的预算不显示编辑、删除按钮 -->
            <template v-if="budget.isActive">
              <button
                class="money-option-btn money-option-edit-hover"
                :title="t('common.actions.edit')"
                @click="emit('edit', budget)"
              >
                <LucideEdit class="wh-4" />
              </button>
              <button
                class="money-option-btn money-option-trash-hover"
                :title="t('common.actions.delete')"
                @click="emit('delete', budget.serialNum)"
              >
                <LucideTrash class="wh-4" />
              </button>
            </template>
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
          <div v-if="budget.description" class="info-row info-row-last">
            <span class="info-label">{{ t('common.misc.remark') }}</span>
            <span class="info-value">{{ budget.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="pagination.totalItems.value > pagination.pageSize.value" class="pagination-container">
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
  color: var(--color-gray-600);
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

/* Budget Grid - 优化网格布局 */
.budget-grid {
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
  .budget-grid {
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
  .budget-grid {
    gap: 1rem;
    margin-bottom: 1rem;
  }

  .grid-template-columns-single-50 {
    grid-template-columns: 1fr;
    max-width: 50%;
  }

  .grid-template-columns-320-max2 {
    grid-template-columns: repeat(2, 1fr);
    max-width: none;
  }
}

/* Budget Card - 重新设计为更紧凑美观的卡片 */
.budget-card {
  background: linear-gradient(135deg, var(--color-base-100) 0%, var(--color-base-200) 100%);
  padding: 1rem;
  border: 1px solid var(--color-primary-soft);
  border-radius: 0.75rem;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  position: relative;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
}

.budget-card::before {
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

.budget-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-lg);
  border-color: var(--color-primary);
}

.budget-card:hover::before {
  opacity: 1;
}

.budget-card-inactive {
  opacity: 0.6;
  background: var(--color-gray-100);
  border-color: var(--color-gray-300);
}

.budget-card-inactive::before {
  background: var(--color-gray-400);
}

/* Budget Header - 更紧凑的布局 */
.budget-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  gap: 0.5rem;
}

.budget-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
  min-width: 0;
}

.budget-name {
  font-size: 1rem;
  color: var(--color-base-content);
  font-weight: 600;
  line-height: 1.2;
}

/* Status Tags */
.status-tag {
  font-size: 0.6875rem;
  padding: 0.125rem 0.375rem;
  border-radius: 0.375rem;
  font-weight: 500;
  white-space: nowrap;
}

.status-inactive {
  color: var(--color-gray-600);
  background-color: var(--color-gray-200);
}

.status-exceeded {
  color: var(--color-error);
  background-color: var(--color-error-soft);
}

.status-warning {
  color: var(--color-warning);
  background-color: var(--color-warning-soft);
}

/* Budget Actions - 更优雅的操作按钮 */
.budget-actions {
  display: flex;
  gap: 0.25rem;
  flex-shrink: 0;
}

/* Budget Period - 紧凑布局 */
.budget-period {
  font-size: 0.75rem;
  color: var(--color-gray-500);
  margin-bottom: 0.5rem;
  display: flex;
  gap: 0.375rem;
  align-items: center;
  justify-content: flex-end;
}

.period-icon {
  color: var(--color-gray-500);
  height: 0.875rem;
  width: 0.875rem;
  flex-shrink: 0;
}

/* Budget Progress - 优化进度条显示 */
.budget-progress {
  margin-bottom: 0.75rem;
}

.progress-header {
  display: flex;
  align-items: baseline;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.used-amount {
  font-size: 1.25rem;
  color: var(--color-base-content);
  font-weight: 700;
  line-height: 1;
  letter-spacing: -0.025em;
}

.total-amount {
  font-size: 0.875rem;
  color: var(--color-gray-500);
}

.remaining-amount-container {
  margin-left: auto;
  padding: 0.375rem 0.625rem;
  border-radius: 0.5rem;
  background: var(--color-base-200);
}

.remaining-amount {
  font-size: 0.9375rem;
  font-weight: 600;
}

.remaining-amount-success {
  color: var(--color-success);
}

.remaining-amount-error {
  color: var(--color-error);
}

.progress-bar {
  margin-bottom: 0.375rem;
  border-radius: 0.5rem;
  background-color: var(--color-gray-200);
  height: 0.5rem;
  width: 100%;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  transition: width 0.3s ease;
}

.progress-fill-primary {
  background-color: var(--color-primary);
}

.progress-fill-error {
  background-color: var(--color-error);
}

.progress-percentage {
  font-size: 0.875rem;
  text-align: center;
  font-weight: 600;
}

.progress-percentage-normal {
  color: var(--color-gray-600);
}

.progress-percentage-error {
  color: var(--color-error);
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
  background-color: var(--color-warning);
  color: var(--color-warning-content);
  border-color: var(--color-warning);
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

/* Budget Info Section - 紧凑布局 */
.budget-info-section {
  padding-top: 0.75rem;
  border-top: 1px solid var(--color-gray-200);
}

.info-row {
  font-size: 0.8125rem;
  margin-bottom: 0.375rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 0.75rem;
}

.info-row-last {
  margin-bottom: 0;
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

/* 统计按钮组样式 */
.stats-button-group {
  display: flex;
  gap: 8px;
  margin-right: 16px;
}

.stats-button {
  background-color: #1890ff;
  color: white;
  font-weight: 500;
  padding: 8px 12px;
  min-width: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.stats-button:hover {
  background-color: #40a9ff;
}

.filter-button-group {
  display: flex;
  gap: 0.25rem;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .budget-card {
    padding: 0.875rem;
  }

  .budget-header {
    margin-bottom: 0.625rem;
  }

  .budget-name {
    font-size: 0.9375rem;
  }

  .money-option-btn {
    width: 1.75rem;
    height: 1.75rem;
  }

  .used-amount {
    font-size: 1.125rem;
  }

  .budget-info-section {
    padding-top: 0.625rem;
  }

  .info-row {
    font-size: 0.75rem;
  }

  .budget-period {
    font-size: 0.6875rem;
  }
}
</style>
