<script setup lang="ts">
import Button from '@/components/ui/Button.vue';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';

interface Filters {
  dateRange: {
    start: string;
    end: string;
  };
  timeDimension: 'year' | 'month' | 'week';
  category: string;
  subCategory: string;
  accountSerialNum: string;
  transactionType: string;
  currency: string;
}

interface Props {
  filters: Filters;
}

interface Emits {
  (e: 'change', filters: Filters): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// 响应式数据
const localFilters = ref<Filters>({ ...props.filters });
const accounts = ref<Array<{ serialNum: string; name: string }>>([]);
const categories = ref<Array<{ name: string }>>([]);
const subCategories = ref<Array<{ name: string; categoryName: string }>>([]);
const currencies = ref<Array<{ code: string; name: string }>>([]);

// 预设时间范围选项
const presetRanges = [
  {
    label: '昨天',
    value: 'yesterday',
    getRange: () => {
      const yesterday = new Date();
      yesterday.setDate(yesterday.getDate() - 1);
      return {
        start: DateUtils.formatDateFromDate(yesterday),
        end: DateUtils.formatDateFromDate(yesterday),
      };
    },
  },
  {
    label: '今天',
    value: 'today',
    getRange: () => ({
      start: DateUtils.formatDateFromDate(new Date()),
      end: DateUtils.formatDateFromDate(new Date()),
    }),
  },
  {
    label: '本周',
    value: 'thisWeek',
    getRange: () => ({
      start: DateUtils.formatDateFromDate(DateUtils.getStartOfWeek(new Date())),
      end: DateUtils.formatDateFromDate(DateUtils.getEndOfWeek(new Date())),
    }),
  },
  {
    label: '上周',
    value: 'lastWeek',
    getRange: () => {
      const lastWeek = new Date();
      lastWeek.setDate(lastWeek.getDate() - 7);
      return {
        start: DateUtils.formatDateFromDate(DateUtils.getStartOfWeek(lastWeek)),
        end: DateUtils.formatDateFromDate(DateUtils.getEndOfWeek(lastWeek)),
      };
    },
  },
  {
    label: '本月',
    value: 'thisMonth',
    getRange: () => ({
      start: DateUtils.formatDateFromDate(DateUtils.getStartOfMonth(new Date())),
      end: DateUtils.formatDateFromDate(DateUtils.getEndOfMonth(new Date())),
    }),
  },
  {
    label: '上月',
    value: 'lastMonth',
    getRange: () => {
      const lastMonth = new Date();
      lastMonth.setMonth(lastMonth.getMonth() - 1);
      return {
        start: DateUtils.formatDateFromDate(DateUtils.getStartOfMonth(lastMonth)),
        end: DateUtils.formatDateFromDate(DateUtils.getEndOfMonth(lastMonth)),
      };
    },
  },
  {
    label: '今年',
    value: 'thisYear',
    getRange: () => ({
      start: DateUtils.formatDateFromDate(DateUtils.getStartOfYear(new Date())),
      end: DateUtils.formatDateFromDate(DateUtils.getEndOfYear(new Date())),
    }),
  },
  {
    label: '去年',
    value: 'lastYear',
    getRange: () => {
      const lastYear = new Date();
      lastYear.setFullYear(lastYear.getFullYear() - 1);
      return {
        start: DateUtils.formatDateFromDate(DateUtils.getStartOfYear(lastYear)),
        end: DateUtils.formatDateFromDate(DateUtils.getEndOfYear(lastYear)),
      };
    },
  },
];

// 交易类型选项
const transactionTypes = [
  { label: '交易类型', value: '' },
  { label: '收入', value: 'Income' },
  { label: '支出', value: 'Expense' },
  { label: '转账', value: 'Transfer' },
];

// 时间维度选项
const timeDimensions = [
  { label: '年度', value: 'year' },
  { label: '月度', value: 'month' },
  { label: '周度', value: 'week' },
];

// 计算属性
const filteredSubCategories = computed(() => {
  if (!localFilters.value.category) {
    return subCategories.value;
  }
  return subCategories.value.filter(sub => sub.categoryName === localFilters.value.category);
});

// 方法
async function loadReferenceData() {
  try {
    // 加载账户列表
    const accountList = await MoneyDb.listAccounts();
    accounts.value = accountList.map(account => ({
      serialNum: account.serialNum,
      name: account.name,
    }));

    // 加载分类列表
    const categoryList = await MoneyDb.listCategory();
    categories.value = categoryList.map(category => ({
      name: category.name,
    }));

    // 加载子分类列表
    const subCategoryList = await MoneyDb.listSubCategory();
    subCategories.value = subCategoryList.map(subCategory => ({
      name: subCategory.name,
      categoryName: subCategory.categoryName,
    }));

    // 加载货币列表
    const currencyList = await MoneyDb.listCurrencies();
    currencies.value = currencyList.map(currency => ({
      code: currency.code,
      name: currency.locale, // 使用locale作为显示名称
    }));
  } catch (error) {
    console.error('加载参考数据失败:', error);
  }
}

function applyPresetRange(preset: typeof presetRanges[0]) {
  const range = preset.getRange();
  localFilters.value.dateRange = range;
  emitChange();
}

function emitChange() {
  emit('change', { ...localFilters.value });
}

function resetFilters() {
  localFilters.value = {
    dateRange: {
      start: DateUtils.formatDateFromDate(DateUtils.getStartOfMonth(new Date())),
      end: DateUtils.formatDateFromDate(DateUtils.getEndOfMonth(new Date())),
    },
    timeDimension: 'month',
    category: '',
    subCategory: '',
    accountSerialNum: '',
    transactionType: '',
    currency: '',
  };
  emitChange();
}

// 监听分类变化，清空子分类
watch(() => localFilters.value.category, newCategory => {
  if (newCategory !== localFilters.value.subCategory) {
    localFilters.value.subCategory = '';
  }
  emitChange();
});

// 监听所有筛选条件变化
watch(localFilters, () => {
  emitChange();
}, { deep: true });

// 初始化
loadReferenceData();
</script>

<template>
  <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4 mb-6">
    <!-- 桌面端布局 -->
    <div class="hidden md:block">
      <!-- 第一行：过去时间按钮 + 开始日期 + 时间维度 + 账户 + 分类 -->
      <div class="flex items-center gap-2 flex-wrap mb-3">
        <!-- 过去时间按钮组 -->
        <div class="flex gap-1 flex-wrap">
          <Button
            v-for="preset in [presetRanges[0], presetRanges[2], presetRanges[4], presetRanges[6]]"
            :key="preset.value"
            variant="primary"
            size="xs"
            @click="applyPresetRange(preset)"
          >
            {{ preset.label }}
          </Button>
        </div>
        <!-- 开始日期输入框 -->
        <input
          v-model="localFilters.dateRange.start"
          type="date"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs min-w-[140px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
        <!-- 时间维度 -->
        <select
          v-model="localFilters.timeDimension"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer min-w-[120px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option
            v-for="dimension in timeDimensions"
            :key="dimension.value"
            :value="dimension.value"
          >
            {{ dimension.label }}
          </option>
        </select>
        <!-- 账户 -->
        <select
          v-model="localFilters.accountSerialNum"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer min-w-[120px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            全部账户
          </option>
          <option
            v-for="account in accounts"
            :key="account.serialNum"
            :value="account.serialNum"
          >
            {{ account.name }}
          </option>
        </select>
        <!-- 分类 -->
        <select
          v-model="localFilters.category"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer min-w-[120px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            全部分类
          </option>
          <option
            v-for="category in categories"
            :key="category.name"
            :value="category.name"
          >
            {{ category.name }}
          </option>
        </select>
      </div>

      <!-- 第二行：当前时间按钮 + 结束日期 + 交易类型 + 货币 + 子分类 + 重置 -->
      <div class="flex items-center gap-2 flex-wrap">
        <!-- 当前时间按钮组 -->
        <div class="flex gap-1 flex-wrap">
          <Button
            v-for="preset in [presetRanges[1], presetRanges[3], presetRanges[5], presetRanges[7]]"
            :key="preset.value"
            variant="primary"
            size="xs"
            @click="applyPresetRange(preset)"
          >
            {{ preset.label }}
          </Button>
        </div>
        <!-- 结束日期输入框 -->
        <input
          v-model="localFilters.dateRange.end"
          type="date"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs min-w-[140px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
        <!-- 交易类型 -->
        <select
          v-model="localFilters.transactionType"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer min-w-[120px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option
            v-for="type in transactionTypes"
            :key="type.value"
            :value="type.value"
          >
            {{ type.label }}
          </option>
        </select>
        <!-- 货币 -->
        <select
          v-model="localFilters.currency"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer min-w-[120px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            全部货币
          </option>
          <option
            v-for="currency in currencies"
            :key="currency.code"
            :value="currency.code"
          >
            {{ currency.name }} ({{ currency.code }})
          </option>
        </select>
        <!-- 子分类 -->
        <select
          v-model="localFilters.subCategory"
          class="px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer min-w-[120px] max-w-[160px] focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-200 dark:disabled:bg-gray-600 disabled:text-gray-500 dark:disabled:text-gray-400 disabled:cursor-not-allowed"
          :disabled="!localFilters.category"
        >
          <option value="">
            全部子分类
          </option>
          <option
            v-for="subCategory in filteredSubCategories"
            :key="subCategory.name"
            :value="subCategory.name"
          >
            {{ subCategory.name }}
          </option>
        </select>
        <!-- 重置按钮 -->
        <Button
          variant="secondary"
          size="xs"
          @click="resetFilters"
        >
          重置
        </Button>
      </div>
    </div>

    <!-- 移动端布局 -->
    <div class="block md:hidden">
      <!-- 第一行：过去时间按钮 -->
      <div class="flex items-center gap-2 flex-wrap justify-center mb-3">
        <Button
          v-for="preset in [presetRanges[0], presetRanges[2], presetRanges[4], presetRanges[6]]"
          :key="preset.value"
          variant="primary"
          size="xs"
          class="flex-1 min-w-0"
          @click="applyPresetRange(preset)"
        >
          {{ preset.label }}
        </Button>
      </div>

      <!-- 第二行：当前时间按钮 -->
      <div class="flex items-center gap-2 flex-wrap justify-center mb-3">
        <Button
          v-for="preset in [presetRanges[1], presetRanges[3], presetRanges[5], presetRanges[7]]"
          :key="preset.value"
          variant="primary"
          size="xs"
          class="flex-1 min-w-0"
          @click="applyPresetRange(preset)"
        >
          {{ preset.label }}
        </Button>
      </div>

      <!-- 第三行：日期范围选择 -->
      <div class="flex items-center gap-2 flex-wrap justify-center mb-3">
        <input
          v-model="localFilters.dateRange.start"
          type="date"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
        <input
          v-model="localFilters.dateRange.end"
          type="date"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
      </div>

      <!-- 第四行：通用筛选器 -->
      <div class="flex items-center gap-2 flex-wrap justify-center mb-3">
        <select
          v-model="localFilters.transactionType"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option
            v-for="type in transactionTypes"
            :key="type.value"
            :value="type.value"
          >
            {{ type.label }}
          </option>
        </select>
        <select
          v-model="localFilters.accountSerialNum"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            全部账户
          </option>
          <option
            v-for="account in accounts"
            :key="account.serialNum"
            :value="account.serialNum"
          >
            {{ account.name }}
          </option>
        </select>
        <select
          v-model="localFilters.category"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            全部分类
          </option>
          <option
            v-for="category in categories"
            :key="category.name"
            :value="category.name"
          >
            {{ category.name }}
          </option>
        </select>
      </div>

      <!-- 第五行：附加筛选器 -->
      <div class="flex items-center gap-2 flex-wrap justify-center">
        <select
          v-model="localFilters.timeDimension"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option
            v-for="dimension in timeDimensions"
            :key="dimension.value"
            :value="dimension.value"
          >
            {{ dimension.label }}
          </option>
        </select>
        <select
          v-model="localFilters.currency"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500"
        >
          <option value="">
            货币
          </option>
          <option
            v-for="currency in currencies"
            :key="currency.code"
            :value="currency.code"
          >
            {{ currency.name }} ({{ currency.code }})
          </option>
        </select>
        <select
          v-model="localFilters.subCategory"
          class="flex-1 min-w-0 px-2 py-2 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-700 text-gray-900 dark:text-white text-xs cursor-pointer focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-200 dark:disabled:bg-gray-600 disabled:text-gray-500 dark:disabled:text-gray-400 disabled:cursor-not-allowed"
          :disabled="!localFilters.category"
        >
          <option value="">
            子分类
          </option>
          <option
            v-for="subCategory in filteredSubCategories"
            :key="subCategory.name"
            :value="subCategory.name"
          >
            {{ subCategory.name }}
          </option>
        </select>
        <Button
          variant="secondary"
          size="xs"
          class="flex-1 min-w-0"
          @click="resetFilters"
        >
          重置
        </Button>
      </div>
    </div>
  </div>
</template>
