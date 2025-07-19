<template>
  <div class="min-h-25">
    <!-- 过滤器区域 -->
    <div class="flex flex-wrap justify-center items-center gap-3 mb-5 p-4 bg-gray-50 rounded-lg">
      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">{{ t('common.status.status') }}</label>
        <select v-model="filters.status"
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">{{ t('common.actions.all') }}</option>
          <option value="active">{{ t('common.status.active') }}</option>
          <option value="inactive">{{ t('common.status.inactive') }}</option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700"> {{ t('common.status.completed') }}{{
          t('common.status.status') }} </label>
        <select v-model="filters.completion"
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">{{ t('common.actions.all') }}</option>
          <option value="normal"> {{ t('common.status.normal') }} </option>
          <option value="warning">{{ t('common.status.warning') }}(>70%)</option>
          <option value="exceeded"> {{ t('common.status.exceeded') }} </option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700">{{ t('todos.repeat.periodType') }}</label>
        <select v-model="filters.period"
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value="">{{ t('common.actions.all') }}</option>
          <option value="None">{{ t('date.repeat.none') }}</option>
          <option value="Daily">{{ t('date.repeat.daily') }}</option>
          <option value="Weekly">{{ t('date.repeat.weekly') }}</option>
          <option value="Monthly">{{ t('date.repeat.monthly') }}</option>
          <option value="Yearly">{{ t('date.repeat.yearly') }}</option>
          <option value="Custom">{{ t('date.repeat.custom') }}</option>
        </select>
      </div>

      <div class="filter-flex-wrap">
        <label class="show-on-desktop text-sm font-medium text-gray-700"> {{ t('categories.category') }} </label>
        <select v-model="filters.category"
          class="px-3 py-1.5 border border-gray-300 rounded-md text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
          <option value=""> {{ t('categories.allCategory') }} </option>
          <option v-for="category in uniqueCategories" :key="category" :value="category">
            {{ category }}
          </option>
        </select>
      </div>

      <button @click="resetFilters"
        class="px-3 py-1.5 bg-gray-200 text-gray-700 rounded-md text-sm hover:bg-gray-300 transition-colors">
        <RotateCcw class="wh-5 mr-1" />
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex-justify-center h-25 text-gray-600">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="paginatedBudgets.length === 0" class="flex-justify-center flex-col h-25 text-#999">
      <div class="text-sm mb-2 opacity-50">
        <i class="icon-target"></i>
      </div>
      <div class="text-sm">
        {{ filteredBudgets.length === 0 ? t('financial.noBudget') : t('messages.noPatternResult') }}
      </div>
    </div>

    <!-- 预算网格 -->
    <div v-else class="budget-grid grid gap-5 w-full mb-6">
      <div v-for="budget in paginatedBudgets" :key="budget.serialNum" :class="[
        'bg-white border rounded-md p-1.5 transition-all hover:shadow-md',
        { 'opacity-60 bg-gray-100': !budget.isActive }
      ]" :style="{
        borderColor: budget.color || '#E5E7EB'
      }">
        <!-- Header -->
        <div class="flex flex-wrap justify-between items-center mb-2 gap-2">
          <!-- 左侧预算名称 -->
          <div class="flex items-center text-gray-800">
            <span class="text-lg font-semibold">{{ budget.name }}</span>
            <!-- 状态标签 -->
            <span v-if="!budget.isActive" class="ml-2 px-2 py-0.5 bg-gray-200 text-gray-600 text-xs rounded">
              {{ t('optionsAndStatus.inactive') }}
            </span>
            <span v-else-if="isOverBudget(budget)" class="ml-2 px-2 py-0.5 bg-red-100 text-red-600 text-xs rounded">
              {{ t('optionsAndStatus.exceeded') }}
            </span>
            <span v-else-if="isLowOnBudget(budget)"
              class="ml-2 px-2 py-0.5 bg-yellow-100 text-yellow-600 text-xs rounded">
              {{ t('common.status.warning') }}
            </span>
          </div>

          <!-- 右侧按钮组 -->
          <div class="flex items-center gap-1 md:self-end">
            <button class="money-option-btn hover:(border-green-500 text-green-500)" @click="emit('edit', budget)"
              :title="t('common.actions.edit')">
              <Edit class="w-4 h-4" />
            </button>
            <button class="money-option-btn hover:(border-blue-500 text-blue-500)"
              @click="emit('toggle-active', budget.serialNum)"
              :title="budget.isActive ? t('common.status.stop') : t('generalOperations.enabled')">
              <component :is="budget.isActive ? Ban : StopCircle" class="w-4 h-4" />
            </button>
            <button class="money-option-btn hover:(border-red-500 text-red-500)"
              @click="emit('delete', budget.serialNum)" :title="t('common.actions.delete')">
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>

        <!-- Period -->
        <div class="flex justify-end items-center gap-1 mb-1 text-gray-600 text-sm">
          <Repeat class="w-4 h-4 text-gray-600" />
          <span>{{ getRepeatTypeName(budget.repeatPeriod) }}</span>
        </div>

        <!-- Progress -->
        <div class="mb-2">
          <div class="flex items-baseline gap-1">
            <span class="text-lg font-semibold text-gray-800">{{ formatCurrency(budget.usedAmount) }}</span>
            <span class="text-sm text-gray-600">/ {{ formatCurrency(budget.amount) }}</span>
            <div class="ml-auto flex justify-end mb-2 p-1.5 bg-gray-50 rounded-md">
              <div :class="[
                'text-lg font-semibold',
                shouldHighlightRed(budget) ? 'text-red-500' : 'text-green-500'
              ]">
                {{ formatCurrency(getRemainingAmount(budget)) }}
              </div>
            </div>
          </div>
          <div class="w-full h-1 bg-gray-200 rounded-md overflow-hidden mb-1">
            <div class="h-full transition-[width] duration-300" :style="{ width: `${getProgressPercent(budget)}%` }"
              :class="isOverBudget(budget) ? 'bg-red-500' : 'bg-blue-500'"></div>
          </div>
          <div class="text-center text-lg" :class="shouldHighlightRed(budget) ? 'text-red-500' : 'text-gray-600'">
            {{ getProgressPercent(budget) }}%
          </div>
        </div>

        <!-- Info -->
        <div class="border-t border-gray-200 pt-2">
          <div class="flex justify-between mb-1 text-sm">
            <span class="font-medium text-gray-600"> {{ t('categories.category') }} </span>
            <span class="font-medium text-gray-800">{{ budget.category }}</span>
          </div>
          <div class="flex justify-between mb-1 text-sm">
            <span class="text-gray-600"> {{ t('date.createDate') }} </span>
            <span class="text-gray-800">{{ formatDate(budget.createdAt) }}</span>
          </div>
          <div v-if="budget.description" class="flex justify-between mb-1 text-sm last:mb-0">
            <span class="text-gray-600">{{ t('common.misc.remark') }}</span>
            <span class="text-gray-800">{{ budget.description }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="filteredBudgets.length > pageSize" class="flex justify-center">
      <SimplePagination :current-page="currentPage" :total-pages="totalPages" :total-items="filteredBudgets.length"
        :page-size="pageSize" @page-change="handlePageChange" />
    </div>
  </div>
</template>

<script setup lang="ts">
import { Ban, Edit, Repeat, RotateCcw, StopCircle, Trash } from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { Budget } from '@/schema/money';
import { getRepeatTypeName } from '@/utils/common';
import { formatDate } from '@/utils/date';
import { formatCurrency } from '../utils/money';

interface Props {
  budgets: Budget[];
  loading: boolean;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [budget: Budget];
  delete: [serialNum: string];
  'toggle-active': [serialNum: string];
}>();

const { t } = useI18n();

// 过滤器状态
const filters = ref({
  status: '',
  completion: '',
  period: '',
  category: '',
});

// 分页状态
const currentPage = ref(1);
const pageSize = ref(4);

// 重置过滤器
const resetFilters = () => {
  filters.value = {
    status: '',
    completion: '',
    period: '',
    category: '',
  };
  currentPage.value = 1;
};

// 获取唯一分类
const uniqueCategories = computed(() => {
  const categories = props.budgets.map((budget) => budget.category);
  return [...new Set(categories)].filter(Boolean);
});

// 过滤后的预算
const filteredBudgets = computed(() => {
  let filtered = [...props.budgets];

  // 状态过滤
  if (filters.value.status) {
    filtered = filtered.filter((budget) =>
      filters.value.status === 'active' ? budget.isActive : !budget.isActive,
    );
  }

  // 完成状态过滤
  if (filters.value.completion) {
    filtered = filtered.filter((budget) => {
      const isOver = isOverBudget(budget);
      const isLow = isLowOnBudget(budget);

      switch (filters.value.completion) {
        case 'normal':
          return !isOver && !isLow;
        case 'warning':
          return isLow && !isOver;
        case 'exceeded':
          return isOver;
        default:
          return true;
      }
    });
  }

  // 周期类型过滤 - 修复：比较 repeatPeriod.type 而不是 repeatPeriod 本身
  if (filters.value.period) {
    filtered = filtered.filter(
      (budget) => budget.repeatPeriod.type === filters.value.period,
    );
  }

  // 分类过滤
  if (filters.value.category) {
    filtered = filtered.filter(
      (budget) => budget.category === filters.value.category,
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
const handlePageChange = (page: number) => {
  currentPage.value = page;
};

// 监听过滤器变化，重置到第一页
watch(
  filters,
  () => {
    currentPage.value = 1;
  },
  { deep: true },
);

// 原有的方法
const getProgressPercent = (budget: Budget) => {
  const used = parseFloat(budget.usedAmount);
  const total = parseFloat(budget.amount);
  return Math.min(Math.round((used / total) * 100), 100);
};

const isOverBudget = (budget: Budget) => {
  const used = parseFloat(budget.usedAmount);
  const total = parseFloat(budget.amount);
  return used > total;
};

const isLowOnBudget = (budget: Budget) => {
  const percent = getProgressPercent(budget);
  return percent > 70;
};

const shouldHighlightRed = (budget: Budget) => {
  return isOverBudget(budget) || isLowOnBudget(budget);
};

const getRemainingAmount = (budget: Budget) => {
  const used = parseFloat(budget.usedAmount);
  const total = parseFloat(budget.amount);
  return (total - used).toString();
};
</script>

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
