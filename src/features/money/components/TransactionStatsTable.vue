<script setup lang="ts">
  import Button from '@/components/ui/Button.vue';
  import Spinner from '@/components/ui/Spinner.vue';
  import type { Category } from '@/schema/money/category';
  import { useCategoryStore } from '@/stores/money';
  import { lowercaseFirstLetter } from '@/utils/string';

  interface TopCategory {
    category: string;
    amount: number;
    count: number;
    percentage: number;
  }

  interface Props {
    topCategories: TopCategory[];
    topIncomeCategories?: TopCategory[];
    topTransferCategories?: TopCategory[];
    transactionType?: string;
    loading: boolean;
  }

  const props = defineProps<Props>();

  const { t } = useI18n();
  const categoryStore = useCategoryStore();

  // 分类类型切换
  const categoryType = ref<'expense' | 'income' | 'transfer'>('expense');

  // 监听transactionType变化，自动同步categoryType
  watch(
    () => props.transactionType,
    newTransactionType => {
      if (newTransactionType === 'Income') {
        categoryType.value = 'income';
      } else if (newTransactionType === 'Transfer') {
        categoryType.value = 'transfer';
      } else if (newTransactionType === 'Expense') {
        categoryType.value = 'expense';
      } else {
        // 如果transactionType为空或'全部'，重置为默认值'支出'
        categoryType.value = 'expense';
      }
    },
    { immediate: true },
  );

  // 根据分类类型获取相应的分类数据
  const currentCategories = computed(() => {
    switch (categoryType.value) {
      case 'income':
        return props.topIncomeCategories || [];
      case 'transfer':
        return props.topTransferCategories || [];
      default:
        return props.topCategories;
    }
  });

  // 获取分类类型的显示名称
  const categoryTypeName = computed(() => {
    switch (categoryType.value) {
      case 'income':
        return '收入';
      case 'transfer':
        return '转账';
      default:
        return '支出';
    }
  });

  // 计算属性
  const sortedCategories = computed(() => {
    return [...currentCategories.value].sort((a, b) => b.amount - a.amount);
  });

  const totalAmount = computed(() => {
    return currentCategories.value.reduce((sum, category) => sum + category.amount, 0);
  });

  const totalCount = computed(() => {
    return currentCategories.value.reduce((sum, category) => sum + category.count, 0);
  });

  // 方法
  function formatAmount(amount: number) {
    return amount.toFixed(2);
  }

  function formatPercentage(amount: number) {
    if (totalAmount.value === 0) return '0.00';
    return ((amount / totalAmount.value) * 100).toFixed(2);
  }

  function getCategoryIcon(category: string) {
    // 从MoneyStore中获取分类数据，转换为Record<string, string>格式
    const iconMap: Record<string, string> = categoryStore.categories.reduce(
      (acc, categoryItem: Category) => {
        acc[categoryItem.name] = categoryItem.icon;
        return acc;
      },
      {} as Record<string, string>,
    );

    return iconMap[category] || '📦';
  }
</script>

<template>
  <div
    class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden"
  >
    <div
      class="flex flex-wrap justify-between items-center px-4 md:px-6 py-4 bg-gray-50 dark:bg-gray-700 border-b border-gray-200 dark:border-gray-600 gap-4"
    >
      <h3
        class="text-base md:text-lg font-semibold text-gray-900 dark:text-white whitespace-nowrap shrink-0"
      >
        {{ categoryTypeName }}分类详细统计
      </h3>
      <div class="flex items-center shrink-0">
        <div class="flex items-center gap-2">
          <label class="text-sm text-gray-500 dark:text-gray-400 font-medium hidden md:inline">
            交易类型:
          </label>
          <select
            v-model="categoryType"
            class="px-2 md:px-3 py-1 md:py-1.5 text-xs md:text-sm border border-gray-300 dark:border-gray-600 rounded bg-white dark:bg-gray-700 text-gray-900 dark:text-white cursor-pointer transition-all hover:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 min-w-[80px] md:min-w-0"
          >
            <option value="expense">支出</option>
            <option value="income">收入</option>
            <option value="transfer">转账</option>
          </select>
        </div>
      </div>
      <div class="flex gap-4 items-center ml-auto shrink-0">
        <div class="flex items-center gap-2 whitespace-nowrap">
          <span class="text-xs md:text-sm text-gray-500 dark:text-gray-400">总金额:</span>
          <span class="text-xs md:text-sm font-semibold text-gray-900 dark:text-white"
            >¥{{ formatAmount(totalAmount) }}</span
          >
        </div>
        <div class="flex items-center gap-2 whitespace-nowrap">
          <span class="text-xs md:text-sm text-gray-500 dark:text-gray-400">总笔数:</span>
          <span class="text-xs md:text-sm font-semibold text-gray-900 dark:text-white"
            >{{ totalCount }}笔</span
          >
        </div>
      </div>
    </div>

    <div class="min-h-[400px]">
      <div v-if="loading" class="flex flex-col items-center justify-center h-[400px] gap-4">
        <Spinner size="lg" />
        <div class="text-gray-500 dark:text-gray-400 text-sm">加载中...</div>
      </div>

      <div
        v-else-if="currentCategories.length === 0"
        class="flex flex-col items-center justify-center h-[400px] gap-4"
      >
        <div class="text-5xl opacity-50">📊</div>
        <div class="text-gray-500 dark:text-gray-400 text-sm">暂无统计数据</div>
      </div>

      <div
        v-else
        class="overflow-x-auto scrollbar-thin scrollbar-thumb-gray-300 dark:scrollbar-thumb-gray-600 scrollbar-track-transparent"
      >
        <table class="w-full border-collapse">
          <thead>
            <tr>
              <th
                class="bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm font-semibold text-center px-4 py-3 border-b border-gray-200 dark:border-gray-600 w-[60px]"
              >
                排名
              </th>
              <th
                class="bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm font-semibold text-left px-4 py-3 border-b border-gray-200 dark:border-gray-600 min-w-[120px]"
              >
                分类
              </th>
              <th
                class="bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm font-semibold text-right px-4 py-3 border-b border-gray-200 dark:border-gray-600 min-w-[100px]"
              >
                金额
              </th>
              <th
                class="bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm font-semibold text-left px-4 py-3 border-b border-gray-200 dark:border-gray-600 min-w-[120px] hidden md:table-cell"
              >
                占比
              </th>
              <th
                class="bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm font-semibold text-center px-4 py-3 border-b border-gray-200 dark:border-gray-600 min-w-[80px]"
              >
                笔数
              </th>
              <th
                class="bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm font-semibold text-right px-4 py-3 border-b border-gray-200 dark:border-gray-600 min-w-[100px] hidden md:table-cell"
              >
                平均
              </th>
              <th
                class="bg-gray-50 dark:bg-gray-700 text-gray-500 dark:text-gray-400 text-sm font-semibold text-center px-4 py-3 border-b border-gray-200 dark:border-gray-600 min-w-[80px] hidden md:table-cell"
              >
                趋势
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(category, index) in sortedCategories"
              :key="category.category"
              class="hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors"
            >
              <td
                class="text-center px-2 md:px-4 py-3 border-b border-gray-100 dark:border-gray-700"
              >
                <div
                  class="inline-flex items-center justify-center w-6 h-6 rounded-full text-xs font-semibold text-white"
                  :class="[
                    index === 0 ? 'bg-[#ffd700]'
                    : index === 1 ? 'bg-[#c0c0c0]'
                      : index === 2 ? 'bg-[#cd7f32]'
                        : 'bg-gray-300 dark:bg-gray-600 text-gray-600 dark:text-gray-300',
                  ]"
                >
                  {{ index + 1 }}
                </div>
              </td>
              <td class="px-2 md:px-4 py-3 border-b border-gray-100 dark:border-gray-700">
                <div class="flex items-center gap-2">
                  <span class="text-base"> {{ getCategoryIcon(category.category) }}</span>
                  <span class="text-xs md:text-sm text-gray-900 dark:text-white font-medium">
                    {{ t(`common.categories.${lowercaseFirstLetter(category.category)}`) }}
                  </span>
                </div>
              </td>
              <td
                class="text-right px-2 md:px-4 py-3 border-b border-gray-100 dark:border-gray-700"
              >
                <span class="text-xs md:text-sm font-semibold text-gray-900 dark:text-white">
                  ¥{{ formatAmount(category.amount) }}
                </span>
              </td>
              <td
                class="px-4 py-3 border-b border-gray-100 dark:border-gray-700 hidden md:table-cell"
              >
                <div class="flex items-center gap-2">
                  <div
                    class="flex-1 h-1.5 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden"
                  >
                    <div
                      class="h-full bg-blue-500 dark:bg-blue-400 rounded-full transition-all duration-300"
                      :style="{ width: `${formatPercentage(category.amount)}%` }"
                    />
                  </div>
                  <span class="text-xs text-gray-500 dark:text-gray-400 min-w-[40px] text-right">
                    {{ formatPercentage(category.amount) }}%
                  </span>
                </div>
              </td>
              <td
                class="text-center px-2 md:px-4 py-3 border-b border-gray-100 dark:border-gray-700"
              >
                <div class="flex items-center justify-center gap-1">
                  <span class="text-xs md:text-sm font-semibold text-gray-900 dark:text-white">
                    {{ category.count }}
                  </span>
                  <span class="text-xs text-gray-500 dark:text-gray-400"> 笔 </span>
                </div>
              </td>
              <td
                class="text-right px-4 py-3 border-b border-gray-100 dark:border-gray-700 hidden md:table-cell"
              >
                <span class="text-sm text-gray-500 dark:text-gray-400">
                  ¥{{ formatAmount(category.amount / category.count) }}
                </span>
              </td>
              <td
                class="px-4 py-3 border-b border-gray-100 dark:border-gray-700 hidden md:table-cell"
              >
                <div class="flex items-center justify-center">
                  <div class="w-full">
                    <div class="h-1 bg-gray-200 dark:bg-gray-600 rounded-full overflow-hidden">
                      <div
                        class="h-full bg-gradient-to-r from-blue-500 to-purple-500 dark:from-blue-400 dark:to-purple-400 rounded-full transition-all duration-300"
                        :style="{ width: `${(category.amount / totalAmount) * 100}%` }"
                      />
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 导出功能 -->
    <div
      class="flex flex-col md:flex-row justify-center gap-4 px-4 md:px-6 py-4 bg-gray-50 dark:bg-gray-700 border-t border-gray-200 dark:border-gray-600"
    >
      <Button variant="primary" size="sm" class="w-full md:w-auto">📊 导出数据</Button>
      <Button variant="primary" size="sm" class="w-full md:w-auto">📈 生成报告</Button>
    </div>
  </div>
</template>
