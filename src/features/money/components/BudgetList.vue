<script setup lang="ts">
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

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadBudgets,
});
</script>

<template>
  <div class="min-h-25">
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

      <button
        class="screening-filtering-select"
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
        <i class="icon-target" />
      </div>
      <div class="text-sm">
        {{ pagination.totalItems.value === 0 ? t('financial.messages.noBudget') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 预算网格 -->
    <div
      v-else
      class="budget-grid mb-6 gap-5 grid w-full"
      :class="[
        { 'grid-template-columns-320': !mediaQueries.isMobile },
      ]"
    >
      <div
        v-for="budget in decoratedBudgets"
        :key="budget.serialNum"
        class="bg-base-100 p-1.5 border rounded-md bg-white transition-all hover:shadow-md"
        :class="[
          { 'opacity-60 bg-gray-100': !budget.isActive },
        ]" :style="{
          borderColor: budget.color || '#E5E7EB',
        }"
      >
        <!-- Header -->
        <div class="mb-2 flex flex-wrap gap-2 items-center justify-between">
          <!-- 左侧预算名称 -->
          <div class="text-gray-800 flex items-center">
            <span class="text-lg font-semibold">{{ budget.name }}</span>
            <!-- 状态标签 -->
            <span v-if="!budget.isActive" class="text-xs text-gray-600 ml-2 px-2 py-0.5 rounded bg-gray-200">
              {{ t('common.status.inactive') }}
            </span>
            <span v-else-if="isOverBudget(budget)" class="text-xs text-red-600 ml-2 px-2 py-0.5 rounded bg-red-100">
              {{ t('common.status.exceeded') }}
            </span>
            <span
              v-else-if="isLowOnBudget(budget)"
              class="text-xs text-yellow-600 ml-2 px-2 py-0.5 rounded bg-yellow-100"
            >
              {{ t('common.status.warning') }}
            </span>
          </div>

          <!-- 右侧按钮组 -->
          <div class="flex gap-1 items-center md:self-end">
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
              <!-- <component :is="budget.isActive ? Ban : StopCircle" class="h-4 w-4" /> -->

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
        <div class="text-sm text-gray-600 mb-1 flex gap-1 items-center justify-end">
          <LucideRepeat class="text-gray-600 h-4 w-4" />
          <span>{{ getRepeatTypeName(budget.repeatPeriod) }}</span>
        </div>

        <!-- Progress -->
        <div class="mb-2">
          <div class="flex gap-1 items-baseline">
            <span class="text-lg text-gray-800 font-semibold">{{ formatCurrency(budget.usedAmount) }}</span>
            <span class="text-sm text-gray-600">/ {{ formatCurrency(budget.amount) }}</span>
            <div class="bg-base-200 mb-2 ml-auto p-1.5 rounded-md bg-gray-50 flex justify-end">
              <div
                class="text-lg font-semibold" :class="[
                  shouldHighlightRed(budget) ? 'text-red-500' : 'text-green-500',
                ]"
              >
                {{ formatCurrency(getRemainingAmount(budget)) }}
              </div>
            </div>
          </div>
          <div class="mb-1 rounded-md bg-gray-200 h-1 w-full overflow-hidden">
            <div
              class="h-full transition-[width] duration-300" :style="{ width: `${getProgressPercent(budget)}%` }"
              :class="isOverBudget(budget) ? 'bg-red-500' : 'bg-blue-500'"
            />
          </div>
          <div class="text-lg text-center" :class="shouldHighlightRed(budget) ? 'text-red-500' : 'text-gray-600'">
            {{ getProgressPercent(budget) }}%
          </div>
        </div>

        <!-- Info -->
        <div class="pt-2 border-t border-gray-200">
          <div class="text-sm mb-1 flex justify-between">
            <span class="text-gray-600 font-medium"> {{ t('categories.category') }} </span>
            <span
              class="text-gray-800 font-medium"
              :title="budget.tooltipCategories"
            >
              {{ budget.displayCategories }}
            </span>
          </div>
          <div class="text-sm mb-1 flex justify-between">
            <span class="text-gray-600"> {{ t('date.createDate') }} </span>
            <span class="text-gray-800">{{ DateUtils.formatDate(budget.createdAt) }}</span>
          </div>
          <div v-if="budget.description" class="text-sm mb-1 flex justify-between last:mb-0">
            <span class="text-gray-600">{{ t('common.misc.remark') }}</span>
            <span class="text-gray-800">{{ budget.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="pagination.totalItems.value > pagination.pageSize.value" class="flex justify-center">
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
.loading {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 200px;
  color: #666;
}

.budget-grid {
  display: grid;
  gap: 20px;
}
</style>
