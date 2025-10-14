<script setup lang="ts">
import { computed, ref, watch } from 'vue';
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
  { label: '全部', value: '' },
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
  <div class="transaction-stats-filters">
    <div class="filters-header">
      <h3 class="filters-title">
        筛选条件
      </h3>
      <button
        class="reset-btn"
        @click="resetFilters"
      >
        重置
      </button>
    </div>

    <div class="filters-content">
      <!-- 时间范围 -->
      <div class="filter-group">
        <label class="filter-label">
          时间范围
        </label>
        <div class="preset-ranges">
          <button
            v-for="preset in presetRanges"
            :key="preset.value"
            class="preset-btn"
            @click="applyPresetRange(preset)"
          >
            {{ preset.label }}
          </button>
        </div>
        <div class="date-range">
          <input
            v-model="localFilters.dateRange.start"
            type="date"
            class="date-input"
          >
          <input
            v-model="localFilters.dateRange.end"
            type="date"
            class="date-input"
          >
        </div>
      </div>

      <!-- 统计维度与交易类型配对行 -->
      <div class="filter-row">
        <!-- 时间维度 -->
        <div class="filter-group">
          <select
            v-model="localFilters.timeDimension"
            class="filter-select"
          >
            <option
              v-for="dimension in timeDimensions"
              :key="dimension.value"
              :value="dimension.value"
            >
              {{ dimension.label }}
            </option>
          </select>
        </div>

        <!-- 交易类型 -->
        <div class="filter-group">
          <select
            v-model="localFilters.transactionType"
            class="filter-select"
          >
            <option
              v-for="type in transactionTypes"
              :key="type.value"
              :value="type.value"
            >
              {{ type.label }}
            </option>
          </select>
        </div>
      </div>

      <!-- 账户与分类配对行 -->
      <div class="filter-row">
        <!-- 账户 -->
        <div class="filter-group">
          <select
            v-model="localFilters.accountSerialNum"
            class="filter-select"
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
        </div>

        <!-- 分类 -->
        <div class="filter-group">
          <select
            v-model="localFilters.category"
            class="filter-select"
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
      </div>

      <!-- 子分类与货币配对行 -->
      <div class="filter-row">
        <!-- 子分类 -->
        <div class="filter-group">
          <select
            v-model="localFilters.subCategory"
            class="filter-select"
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
        </div>

        <!-- 货币 -->
        <div class="filter-group">
          <select
            v-model="localFilters.currency"
            class="filter-select"
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
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.transaction-stats-filters {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  padding: 1rem;
  margin-bottom: 1.5rem;
}

.filters-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.filters-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-accent-content);
}

.reset-btn {
  padding: 0.25rem 0.75rem;
  background: var(--color-base-200);
  border: 1px solid var(--color-base-300);
  border-radius: 0.25rem;
  color: var(--color-neutral);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.reset-btn:hover {
  background: var(--color-base-300);
}

.filters-content {
  display: grid !important;
  grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)) !important;
  gap: 0.25rem !important;
  align-items: start;
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  min-width: 0; /* 防止内容溢出 */
}

/* 时间范围组特殊处理 */
.filter-group:first-child {
  min-width: 180px !important; /* 确保时间范围组有足够空间 */
}

.filter-label {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--color-neutral);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.preset-ranges {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.preset-btn {
  padding: 0.25rem 0.5rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 0.25rem;
  font-size: 0.75rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.preset-btn:hover {
  background: var(--color-primary-dark);
}

.date-range {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.date-input {
  padding: 0.375rem 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.25rem;
  background: var(--color-base-100);
  color: var(--color-accent-content);
  font-size: 0.75rem;
  min-width: 120px;
  max-width: 140px;
  flex: 1;
}

.filter-select {
  padding: 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.25rem;
  background: var(--color-base-100);
  color: var(--color-accent-content);
  font-size: 0.75rem;
  cursor: pointer;
  width: 100%;
  max-width: 200px;
  min-width: 140px;
}

.filter-select:disabled {
  background: var(--color-base-200);
  color: var(--color-neutral);
  cursor: not-allowed;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .filters-content {
    display: flex !important;
    flex-direction: column !important;
    gap: 1rem;
  }

  .preset-ranges {
    justify-content: center;
  }

  .date-range {
    display: flex;
    flex-direction: row;
    align-items: center;
    gap: 0.5rem;
  }

  .date-input {
    flex: 1;
    font-size: 0.75rem;
    padding: 0.375rem;
  }
  /* 创建配对行容器 */
  .filter-row {
    display: flex !important;
    gap: 1rem;
    width: 100%;
  }

  .filter-row .filter-group {
    flex: 1;
    display: flex !important;
    flex-direction: column;
    gap: 0.5rem;
  }

  .filter-label {
    font-size: 0.75rem;
    margin-bottom: 0.25rem;
  }

  .filter-select {
    font-size: 0.75rem;
    padding: 0.375rem;
  }
}

/* 中等屏幕优化 */
@media (max-width: 1024px) and (min-width: 769px) {
  .filters-content {
    grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)) !important;
    gap: 0.25rem !important;
  }
  .filter-group:first-child {
    min-width: 160px !important;
  }
  .date-input {
    min-width: 100px;
    max-width: 120px;
  }
  .filter-select {
    max-width: 160px;
  }
}

/* 大屏幕优化 */
@media (min-width: 1200px) {
  .filters-content {
    grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)) !important;
    gap: 0.25rem !important;
  }
  .filter-group:first-child {
    min-width: 180px !important;
  }
  .date-input {
    min-width: 120px;
    max-width: 140px;
  }
  .filter-select {
    max-width: 180px;
  }
}

/* 超小屏幕优化 */
@media (max-width: 480px) {
  .transaction-stats-filters {
    padding: 0.75rem;
  }

  .filters-header {
    margin-bottom: 0.75rem;
  }

  .filters-title {
    font-size: 1rem;
  }

  .reset-btn {
    font-size: 0.75rem;
    padding: 0.25rem 0.5rem;
  }

  .preset-ranges {
    gap: 0.25rem;
  }

  .preset-btn {
    font-size: 0.625rem;
    padding: 0.25rem 0.375rem;
  }

  .date-input {
    font-size: 0.625rem;
    padding: 0.25rem;
  }
  .filter-label {
    font-size: 0.625rem;
    margin-bottom: 0.125rem;
  }

  .filter-select {
    font-size: 0.625rem;
    padding: 0.25rem;
  }

  /* 在超小屏幕上，配对字段恢复垂直排列 */
  .filter-row {
    flex-direction: column !important;
    gap: 0.75rem;
  }

  .filter-row .filter-group {
    width: 100% !important;
  }
}
</style>
