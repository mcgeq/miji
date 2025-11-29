<script setup lang="ts">
import { Ban, BarChart3, Edit, Repeat, StopCircle, Trash } from 'lucide-vue-next';
import FilterBar from '@/components/common/FilterBar.vue';
import { Button, Card, EmptyState, LoadingState, Pagination } from '@/components/ui';
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

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadBudgets,
});
</script>

<template>
  <div class="space-y-4 w-full">
    <!-- 过滤器区域 -->
    <FilterBar
      :show-more-filters="showMoreFilters"
      @toggle-filters="toggleFilters"
      @reset="resetFilters"
    >
      <template #primary>
        <!-- 统计按钮 -->
        <Button
          variant="primary"
          size="sm"
          :icon="BarChart3"
          :title="t('financial.budget.statsAndTrends')"
          @click="navigateToStats"
        />
      </template>

      <template #secondary>
        <select
          v-model="filters.isActive"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
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

        <!-- 更多过滤器 -->
        <select
          v-model="filters.repeatPeriodType"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
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

        <select
          v-model="filters.category"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        >
          <option :value="null">
            {{ t('categories.allCategory') }}
          </option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ t(`common.categories.${lowercaseFirstLetter(category)}`) }}
          </option>
        </select>
      </template>
    </FilterBar>

    <!-- 加载状态 -->
    <LoadingState v-if="loading" :message="t('common.loading')" />

    <!-- 空状态 -->
    <EmptyState
      v-else-if="pagination.paginatedItems.value.length === 0"
      icon="🎯"
      :message="pagination.totalItems.value === 0 ? t('financial.messages.noBudget') : t('messages.noPatternResult')"
    />

    <!-- 预算网格 -->
    <div
      v-else
      class="grid gap-4 mb-4"
      :class="mediaQueries.isMobile ? 'grid-cols-1' : 'grid-cols-1 lg:grid-cols-2'"
    >
      <Card
        v-for="budget in decoratedBudgets"
        :key="budget.serialNum"
        padding="md"
        hoverable
        class="relative overflow-hidden transition-all duration-300"
        :class="{
          'opacity-60': !budget.isActive,
        }"
        :style="{
          borderLeftColor: budget.color || '#e5e7eb',
          borderLeftWidth: '4px',
        }"
      >
        <!-- Header -->
        <div class="flex items-start justify-between mb-3 gap-2">
          <!-- 预算名称和状态 -->
          <div class="flex items-center gap-2 flex-1 min-w-0">
            <span class="font-semibold text-gray-900 dark:text-white truncate">{{ budget.name }}</span>
            <!-- 状态标签 -->
            <span v-if="!budget.isActive" class="text-[11px] px-1.5 py-0.5 rounded-md font-medium whitespace-nowrap bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-400">
              {{ t('common.status.inactive') }}
            </span>
            <span v-else-if="isOverBudget(budget)" class="text-[11px] px-1.5 py-0.5 rounded-md font-medium whitespace-nowrap bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400">
              {{ t('common.status.exceeded') }}
            </span>
            <span v-else-if="isLowOnBudget(budget)" class="text-[11px] px-1.5 py-0.5 rounded-md font-medium whitespace-nowrap bg-yellow-100 dark:bg-yellow-900/30 text-yellow-600 dark:text-yellow-400">
              {{ t('common.status.warning') }}
            </span>
          </div>

          <!-- 操作按钮组 -->
          <div class="flex gap-1 shrink-0">
            <button
              class="w-8 h-8 flex items-center justify-center rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:border-yellow-500 hover:text-yellow-600 dark:hover:text-yellow-400 hover:bg-yellow-50 dark:hover:bg-yellow-900/20 transition-all active:scale-95"
              :title="budget.isActive ? t('common.status.stop') : t('common.status.enabled')"
              @click="emit('toggleActive', budget.serialNum, !budget.isActive)"
            >
              <Ban v-if="budget.isActive" :size="16" />
              <StopCircle v-else :size="16" />
            </button>
            <template v-if="budget.isActive">
              <button
                class="w-8 h-8 flex items-center justify-center rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:border-blue-500 hover:text-blue-600 dark:hover:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-all active:scale-95"
                :title="t('common.actions.edit')"
                @click="emit('edit', budget)"
              >
                <Edit :size="16" />
              </button>
              <button
                class="w-8 h-8 flex items-center justify-center rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-600 dark:text-gray-400 hover:border-red-500 hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all active:scale-95"
                :title="t('common.actions.delete')"
                @click="emit('delete', budget.serialNum)"
              >
                <Trash :size="16" />
              </button>
            </template>
          </div>
        </div>

        <!-- Period -->
        <div class="text-xs text-gray-500 dark:text-gray-400 mb-2 flex gap-1.5 items-center justify-end">
          <Repeat :size="14" />
          <span>{{ getRepeatTypeName(budget.repeatPeriod) }}</span>
        </div>

        <!-- Progress -->
        <div class="mb-3">
          <div class="flex items-baseline gap-2 mb-2">
            <span class="text-xl font-bold text-gray-900 dark:text-white tracking-tight">{{ formatCurrency(budget.usedAmount) }}</span>
            <span class="text-sm text-gray-500 dark:text-gray-400">/ {{ formatCurrency(budget.amount) }}</span>
            <div class="ml-auto px-2.5 py-1.5 rounded-lg bg-gray-100 dark:bg-gray-700">
              <div
                class="text-[15px] font-semibold"
                :class="shouldHighlightRed(budget) ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400'"
              >
                {{ formatCurrency(getRemainingAmount(budget)) }}
              </div>
            </div>
          </div>
          <div class="mb-1.5 rounded-lg bg-gray-200 dark:bg-gray-700 h-2 w-full overflow-hidden">
            <div
              class="h-full transition-all duration-300"
              :style="{ width: `${getProgressPercent(budget)}%` }"
              :class="isOverBudget(budget) ? 'bg-red-500 dark:bg-red-600' : 'bg-blue-500 dark:bg-blue-600'"
            />
          </div>
          <div class="text-sm text-center font-semibold" :class="shouldHighlightRed(budget) ? 'text-red-600 dark:text-red-400' : 'text-gray-600 dark:text-gray-400'">
            {{ getProgressPercent(budget) }}%
          </div>
        </div>

        <!-- Info -->
        <div class="pt-3 border-t border-gray-200 dark:border-gray-700">
          <div class="text-[13px] mb-1.5 flex justify-between items-center gap-3">
            <span class="text-gray-500 dark:text-gray-400 font-medium shrink-0">{{ t('categories.category') }}</span>
            <span
              class="text-gray-900 dark:text-white font-medium text-right truncate"
              :title="budget.tooltipCategories"
            >
              {{ budget.displayCategories }}
            </span>
          </div>
          <div v-if="budget.description" class="text-[13px] flex justify-between items-center gap-3">
            <span class="text-gray-500 dark:text-gray-400 font-medium shrink-0">{{ t('common.misc.remark') }}</span>
            <span class="text-gray-900 dark:text-white font-medium text-right truncate">{{ budget.description }}</span>
          </div>
        </div>
      </Card>
    </div>

    <!-- 分页组件 -->
    <div v-if="pagination.totalItems.value > pagination.pageSize.value" class="flex justify-center" :class="mediaQueries.isMobile && 'mb-16 pb-4'">
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
