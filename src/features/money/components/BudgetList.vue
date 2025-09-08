<script setup lang="ts">
import { Ban, Edit, Repeat, RotateCcw, StopCircle, Trash } from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { useSort } from '@/composables/useSortable';
import { CategorySchema, SortDirection } from '@/schema/common';
import { getRepeatTypeName } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { mapUIFiltersToAPIFilters, useBudgetFilters } from '../composables/useBudgetFilters';
import { formatCurrency } from '../utils/money';
import type { Category, PageQuery } from '@/schema/common';
import type { Budget } from '@/schema/money';
import type { BudgetFilters } from '@/services/money/budgets';

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
const loading = ref(false);
const budgets = computed<Budget[]>(() => moneyStore.budgets);

const { filters, resetFilters, filteredBudgets, pagination } = useBudgetFilters(
  () => budgets.value,
  4,
);

const { sortOptions } = useSort({
  sortBy: undefined,
  sortDir: SortDirection.Desc,
  desc: true,
  customOrderBy: undefined,
});

// 加载交易数据
async function loadBudgets() {
  loading.value = true;
  try {
    const params: PageQuery<BudgetFilters> = {
      currentPage: pagination.currentPage.value,
      pageSize: pagination.pageSize.value,
      sortOptions: sortOptions.value,
      filter: mapUIFiltersToAPIFilters(filters.value),
    };

    const result = await moneyStore.getPagedBudgets(params);
    pagination.totalItems.value = result.totalCount ?? 0;
    pagination.totalPages.value = result.totalPages ?? 1;

    // 可选：当前页超出总页数时重置
    if (pagination.currentPage.value > pagination.totalPages.value) {
      pagination.currentPage.value = pagination.totalPages.value || 1;
    }
  } catch (error) {
    pagination.totalItems.value = 0;
    pagination.totalPages.value = 0;
    Lg.e('Transaction', error);
  } finally {
    loading.value = false;
  }
}

// 获取唯一分类
const uniqueCategories = computed(() => {
  const categorySet = new Set<Category>();
  for (const budget of budgets.value) {
    for (const category of budget.categoryScope) {
      categorySet.add(category);
    }
  }
  const allCategories = CategorySchema.options;
  return Array.from(categorySet).sort((a, b) => allCategories.indexOf(a) - allCategories.indexOf(b));
});

const decoratedBudgets = computed<BudgetVM[]>(() =>
  pagination.paginatedItems.value.map(b => {
    const cats = Array.isArray(b.categoryScope) ? b.categoryScope : [];
    return {
      ...b,
      displayCategories: cats.slice(0, 2).join(', '),
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
    <div class="mb-5 p-4 rounded-lg bg-gray-50 flex flex-wrap gap-3 items-center justify-center">
      <div class="filter-flex-wrap">
        <label class="text-sm text-gray-700 font-medium show-on-desktop">{{ t('common.status.status') }}</label>
        <select
          v-model="filters.isActive"
          class="text-sm px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('common.actions.all') }}
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
        <label class="text-sm text-gray-700 font-medium show-on-desktop">{{ t('todos.repeat.periodType') }}</label>
        <select
          v-model="filters.repeatPeriod"
          class="text-sm px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
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
        <label class="text-sm text-gray-700 font-medium show-on-desktop"> {{ t('categories.category') }} </label>
        <select
          v-model="filters.category"
          class="text-sm px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option :value="null">
            {{ t('categories.allCategory') }}
          </option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ category }}
          </option>
        </select>
      </div>

      <button
        class="text-sm text-gray-700 px-3 py-1.5 rounded-md bg-gray-200 transition-colors hover:bg-gray-300"
        @click="resetFilters"
      >
        <RotateCcw class="mr-1 wh-5" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="text-gray-600 flex-justify-center h-25">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="pagination.paginatedItems.value.length === 0" class="text-#999 flex-justify-center flex-col h-25">
      <div class="text-sm mb-2 opacity-50">
        <i class="icon-target" />
      </div>
      <div class="text-sm">
        {{ filteredBudgets.length === 0 ? t('financial.messages.noBudget') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 预算网格 -->
    <div v-else class="budget-grid mb-6 gap-5 grid w-full">
      <div
        v-for="budget in decoratedBudgets" :key="budget.serialNum" class="p-1.5 border rounded-md bg-white transition-all hover:shadow-md" :class="[
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
              class="money-option-btn hover:(text-green-500 border-green-500)" :title="t('common.actions.edit')"
              @click="budget.isActive && emit('edit', budget)"
            >
              <Edit class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(text-blue-500 border-blue-500)"
              :title="budget.isActive ? t('common.status.stop') : t('common.status.enabled')"
              @click="emit('toggleActive', budget.serialNum, !budget.isActive)"
            >
              <component :is="budget.isActive ? Ban : StopCircle" class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(text-red-500 border-red-500)"
              :title="t('common.actions.delete')" @click="emit('delete', budget.serialNum)"
            >
              <Trash class="h-4 w-4" />
            </button>
          </div>
        </div>

        <!-- Period -->
        <div class="text-sm text-gray-600 mb-1 flex gap-1 items-center justify-end">
          <Repeat class="text-gray-600 h-4 w-4" />
          <span>{{ getRepeatTypeName(budget.repeatPeriod) }}</span>
        </div>

        <!-- Progress -->
        <div class="mb-2">
          <div class="flex gap-1 items-baseline">
            <span class="text-lg text-gray-800 font-semibold">{{ formatCurrency(budget.usedAmount) }}</span>
            <span class="text-sm text-gray-600">/ {{ formatCurrency(budget.amount) }}</span>
            <div class="mb-2 ml-auto p-1.5 rounded-md bg-gray-50 flex justify-end">
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
              {{ budget.displayCategories || '' }}
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
    <div v-if="filteredBudgets.length > pagination.pageSize.value" class="flex justify-center">
      <SimplePagination
        :current-page="pagination.currentPage.value"
        :total-pages="pagination.totalPages.value"
        :total-items="filteredBudgets.length"
        :page-size="pagination.pageSize.value"
        @page-change="pagination.setPage"
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
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}

.money-option-btn {
  @apply p-1.5 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-50 transition-colors;
}
</style>
