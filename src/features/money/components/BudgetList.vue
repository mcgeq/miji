<script setup lang="ts">
import { Ban, Edit, Repeat, RotateCcw, StopCircle, Trash } from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { CategorySchema, SortDirection } from '@/schema/common';
import { getRepeatTypeName } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { formatCurrency } from '../utils/money';
import type { Category, PageQuery, SortOptions } from '@/schema/common';
import type { Budget } from '@/schema/money';
import type { BudgetFilters } from '@/services/money/budgets';

const emit = defineEmits<{
  edit: [budget: Budget];
  delete: [serialNum: string];
  toggleActive: [serialNum: string, isActive: boolean];
}>();

const { t } = useI18n();
const moneyStore = useMoneyStore();

const loading = ref(false);
const budgets = computed<Budget[]>(() => moneyStore.budgets);
// 分页状态
const pagination = ref({
  currentPage: 1,
  totalPages: 1,
  totalItems: 0,
  pageSize: 20,
});

// 排序选项状态
const sortOptions = ref<SortOptions>({
  customOrderBy: undefined,
  sortBy: undefined,
  sortDir: SortDirection.Desc,
  desc: true,
});

// 初始 filters
const initialFilters: BudgetFilters = {
  category: null,
  accountSerialNum: '',
  name: '',
  amount: undefined,
  repeatPeriod: '',
  startDate: { start: undefined, end: undefined },
  endDate: { start: undefined, end: undefined },
  usedAmount: undefined,
  alertThreshold: '',
  isActive: undefined,
  alertEnabled: undefined,
};
// 过滤器状态
const filters = ref<BudgetFilters>({ ...initialFilters });

// 分页状态
const currentPage = ref(1);
const pageSize = ref(4);

// 重置过滤器
function resetFilters() {
  filters.value = JSON.parse(JSON.stringify(initialFilters));
  currentPage.value = 1;
}

// 加载交易数据
async function loadBudgets() {
  loading.value = true;
  try {
    const params: PageQuery<BudgetFilters> = {
      currentPage: pagination.value.currentPage,
      pageSize: pagination.value.pageSize,
      sortOptions: {
        customOrderBy: sortOptions.value?.customOrderBy,
        sortBy: sortOptions.value?.sortBy,
        desc: sortOptions.value?.desc,
        sortDir: sortOptions.value?.sortDir ?? SortDirection.Desc,
      },
      filter: {
        category: filters.value.category || undefined,
        accountSerialNum: filters.value.accountSerialNum || undefined,
        name: filters.value.name || undefined,
        amount: filters.value.amount || undefined,
        repeatPeriod: filters.value.repeatPeriod || undefined,
        startDate: filters.value.startDate?.start || filters.value.startDate?.end
          ? { ...filters.value.startDate }
          : undefined,
        endDate: filters.value.endDate?.start || filters.value.endDate?.end
          ? { ...filters.value.endDate }
          : undefined,
        usedAmount: filters.value.usedAmount || undefined,
        alertThreshold: filters.value.alertThreshold || undefined,
        isActive: filters.value.isActive,
        alertEnabled: filters.value.alertEnabled,
      },
    };

    const result = await moneyStore.getBudgets(params);

    pagination.value.totalItems = result.totalCount ?? 0;
    pagination.value.totalPages = result.totalPages ?? 1;

    // 可选：当前页超出总页数时重置
    if (pagination.value.currentPage > pagination.value.totalPages) {
      pagination.value.currentPage = pagination.value.totalPages || 1;
    }
  } catch (error) {
    pagination.value.totalItems = 0;
    pagination.value.totalPages = 0;
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

// 过滤后的预算
const filteredBudgets = computed(() => {
  let filtered = [...budgets.value];

  // 状态过滤
  if (filters.value.isActive) {
    filtered = filtered.filter(budget =>
      filters.value.isActive ? budget.isActive : !budget.isActive,
    );
  }

  // // 完成状态过滤
  // if (filters.value.completion) {
  //   filtered = filtered.filter(budget => {
  //     const isOver = isOverBudget(budget);
  //     const isLow = isLowOnBudget(budget);
  //
  //     switch (filters.value.completion) {
  //       case 'normal':
  //         return !isOver && !isLow;
  //       case 'warning':
  //         return isLow && !isOver;
  //       case 'exceeded':
  //         return isOver;
  //       default:
  //         return true;
  //     }
  //   });
  // }

  // 周期类型过滤 - 修复：比较 repeatPeriod.type 而不是 repeatPeriod 本身
  if (filters.value.repeatPeriod) {
    filtered = filtered.filter(
      budget => budget.repeatPeriod.type === filters.value.repeatPeriod,
    );
  }

  // 分类过滤
  if (filters.value.category) {
    const category = filters.value.category as Category;
    filtered = filtered.filter(
      budget => budget.categoryScope.includes(category),
    );
  }

  return filtered;
});

// 总页数
const totalPages = computed(() => {
  return Math.ceil(filteredBudgets.value.length / pageSize.value);
});

// 当前页的预算
const paginatedBudgets = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  const end = start + pageSize.value;
  return filteredBudgets.value.slice(start, end);
});

// 处理页码变化
function handlePageChange(page: number) {
  currentPage.value = page;
}

// 监听过滤器变化，重置到第一页
watch(
  filters,
  () => {
    currentPage.value = 1;
  },
  { deep: true },
);

// 原有的方法
function getProgressPercent(budget: Budget) {
  const used = budget.usedAmount;
  const total = budget.amount;
  return Math.min(Math.round((used / total) * 100), 100);
}

function isOverBudget(budget: Budget) {
  const used = budget.usedAmount;
  const total = budget.amount;
  return used > total;
}

function isLowOnBudget(budget: Budget) {
  const percent = getProgressPercent(budget);
  return percent > 70;
}

function shouldHighlightRed(budget: Budget) {
  return isOverBudget(budget) || isLowOnBudget(budget);
}

function getRemainingAmount(budget: Budget) {
  const used = budget.usedAmount;
  const total = budget.amount;
  return (total - used).toString();
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
    <div class="mb-5 flex flex-wrap items-center justify-center gap-3 rounded-lg bg-gray-50 p-4">
      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('common.status.status') }}</label>
        <select
          v-model="filters.isActive"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
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
        <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('todos.repeat.periodType') }}</label>
        <select
          v-model="filters.repeatPeriod"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
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
        <label class="show-on-desktop text-sm text-gray-700 font-medium"> {{ t('categories.category') }} </label>
        <select
          v-model="filters.category"
          class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            {{ t('categories.allCategory') }}
          </option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ category }}
          </option>
        </select>
      </div>

      <button
        class="rounded-md bg-gray-200 px-3 py-1.5 text-sm text-gray-700 transition-colors hover:bg-gray-300"
        @click="resetFilters"
      >
        <RotateCcw class="mr-1 wh-5" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="h-25 flex-justify-center text-gray-600">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="paginatedBudgets.length === 0" class="h-25 flex-justify-center flex-col text-#999">
      <div class="mb-2 text-sm opacity-50">
        <i class="icon-target" />
      </div>
      <div class="text-sm">
        {{ filteredBudgets.length === 0 ? t('financial.messages.noBudget') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 预算网格 -->
    <div v-else class="budget-grid grid mb-6 w-full gap-5">
      <div
        v-for="budget in paginatedBudgets" :key="budget.serialNum" class="border rounded-md bg-white p-1.5 transition-all hover:shadow-md" :class="[
          { 'opacity-60 bg-gray-100': !budget.isActive },
        ]" :style="{
          borderColor: budget.color || '#E5E7EB',
        }"
      >
        <!-- Header -->
        <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
          <!-- 左侧预算名称 -->
          <div class="flex items-center text-gray-800">
            <span class="text-lg font-semibold">{{ budget.name }}</span>
            <!-- 状态标签 -->
            <span v-if="!budget.isActive" class="ml-2 rounded bg-gray-200 px-2 py-0.5 text-xs text-gray-600">
              {{ t('optionsAndStatus.inactive') }}
            </span>
            <span v-else-if="isOverBudget(budget)" class="ml-2 rounded bg-red-100 px-2 py-0.5 text-xs text-red-600">
              {{ t('optionsAndStatus.exceeded') }}
            </span>
            <span
              v-else-if="isLowOnBudget(budget)"
              class="ml-2 rounded bg-yellow-100 px-2 py-0.5 text-xs text-yellow-600"
            >
              {{ t('common.status.warning') }}
            </span>
          </div>

          <!-- 右侧按钮组 -->
          <div class="flex items-center gap-1 md:self-end">
            <button
              class="money-option-btn hover:(border-green-500 text-green-500)" :title="t('common.actions.edit')"
              @click="emit('edit', budget)"
            >
              <Edit class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(border-blue-500 text-blue-500)"
              :title="budget.isActive ? t('common.status.stop') : t('generalOperations.enabled')"
              @click="emit('toggleActive', budget.serialNum, !budget.isActive)"
            >
              <component :is="budget.isActive ? Ban : StopCircle" class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(border-red-500 text-red-500)"
              :title="t('common.actions.delete')" @click="emit('delete', budget.serialNum)"
            >
              <Trash class="h-4 w-4" />
            </button>
          </div>
        </div>

        <!-- Period -->
        <div class="mb-1 flex items-center justify-end gap-1 text-sm text-gray-600">
          <Repeat class="h-4 w-4 text-gray-600" />
          <span>{{ getRepeatTypeName(budget.repeatPeriod) }}</span>
        </div>

        <!-- Progress -->
        <div class="mb-2">
          <div class="flex items-baseline gap-1">
            <span class="text-lg text-gray-800 font-semibold">{{ formatCurrency(budget.usedAmount) }}</span>
            <span class="text-sm text-gray-600">/ {{ formatCurrency(budget.amount) }}</span>
            <div class="mb-2 ml-auto flex justify-end rounded-md bg-gray-50 p-1.5">
              <div
                class="text-lg font-semibold" :class="[
                  shouldHighlightRed(budget) ? 'text-red-500' : 'text-green-500',
                ]"
              >
                {{ formatCurrency(getRemainingAmount(budget)) }}
              </div>
            </div>
          </div>
          <div class="mb-1 h-1 w-full overflow-hidden rounded-md bg-gray-200">
            <div
              class="h-full transition-[width] duration-300" :style="{ width: `${getProgressPercent(budget)}%` }"
              :class="isOverBudget(budget) ? 'bg-red-500' : 'bg-blue-500'"
            />
          </div>
          <div class="text-center text-lg" :class="shouldHighlightRed(budget) ? 'text-red-500' : 'text-gray-600'">
            {{ getProgressPercent(budget) }}%
          </div>
        </div>

        <!-- Info -->
        <div class="border-t border-gray-200 pt-2">
          <div class="mb-1 flex justify-between text-sm">
            <span class="text-gray-600 font-medium"> {{ t('categories.category') }} </span>
            <span class="text-gray-800 font-medium">{{ budget.categoryScope }}</span>
          </div>
          <div class="mb-1 flex justify-between text-sm">
            <span class="text-gray-600"> {{ t('date.createDate') }} </span>
            <span class="text-gray-800">{{ DateUtils.formatDate(budget.createdAt) }}</span>
          </div>
          <div v-if="budget.description" class="mb-1 flex justify-between text-sm last:mb-0">
            <span class="text-gray-600">{{ t('common.misc.remark') }}</span>
            <span class="text-gray-800">{{ budget.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="filteredBudgets.length > pageSize" class="flex justify-center">
      <SimplePagination
        :current-page="currentPage" :total-pages="totalPages" :total-items="filteredBudgets.length"
        :page-size="pageSize" @page-change="handlePageChange"
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
