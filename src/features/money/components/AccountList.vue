<script setup lang="ts">
import {
  Cloud,
  CreditCard,
  DollarSign,
  PiggyBank,
  TrendingUp,
  Wallet,
  Wallet2,
} from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { DateUtils } from '@/utils/date';
import { formatCurrency } from '../utils/money';
import type { Account, AccountType } from '@/schema/money';
import type {
  LucideIcon,
} from 'lucide-vue-next';

interface Props {
  accounts: Account[];
  loading: boolean;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [account: Account];
  delete: [serialNum: string];
  toggleActive: [serialNum: string, isActive: boolean];
}>();

const { t } = useI18n();

const mediaQueries = useMediaQueriesStore();

// 过滤和分页状态
const activeFilter = ref<'all' | 'active' | 'inactive'>('all');
const selectedType = ref<string>('');
const selectedCurrency = ref<string>('');
const sortBy = ref<'createdAt' | 'name' | 'balance' | 'type'>('createdAt');
const sortOrder = ref<'asc' | 'desc'>('desc');
const currentPage = ref(1);
const pageSize = ref(4);

// 计算统计数据
const totalAccounts = computed(() => props.accounts.length);
const activeAccounts = computed(
  () => props.accounts.filter(account => account.isActive).length,
);
const inactiveAccounts = computed(
  () => props.accounts.filter(account => !account.isActive).length,
);

// 获取所有账户类型
const accountTypes = computed(() => {
  const types = new Set(props.accounts.map(account => account.type));
  return Array.from(types);
});

// 获取所有币种
const currencies = computed(() => {
  const currencies = new Set(
    props.accounts.map(account => account.currency?.code).filter(Boolean),
  );
  return Array.from(currencies);
});

// 过滤后的账户
const filteredAccounts = computed(() => {
  let filtered = props.accounts;

  // 状态过滤
  if (activeFilter.value === 'active') {
    filtered = filtered.filter(account => account.isActive);
  } else if (activeFilter.value === 'inactive') {
    filtered = filtered.filter(account => !account.isActive);
  }

  // 类型过滤
  if (selectedType.value) {
    filtered = filtered.filter(
      account => account.type === selectedType.value,
    );
  }

  // 币种过滤
  if (selectedCurrency.value) {
    filtered = filtered.filter(
      account => account.currency?.code === selectedCurrency.value,
    );
  }

  // 排序
  filtered.sort((a, b) => {
    let aValue, bValue;

    switch (sortBy.value) {
      case 'name':
        aValue = a.name.toLowerCase();
        bValue = b.name.toLowerCase();
        break;
      case 'balance':
        aValue = a.balance;
        bValue = b.balance;
        break;
      case 'type':
        aValue = a.type;
        bValue = b.type;
        break;
      case 'createdAt':
      default:
        if (a.updatedAt && b.updatedAt) {
          aValue = new Date(a.updatedAt).getTime();
          bValue = new Date(b.updatedAt).getTime();
        } else {
          aValue = new Date(a.createdAt).getTime();
          bValue = new Date(b.createdAt).getTime();
        }
        break;
    }

    if (aValue < bValue)
      return sortOrder.value === 'asc' ? -1 : 1;
    if (aValue > bValue)
      return sortOrder.value === 'asc' ? 1 : -1;
    return 0;
  });

  return filtered;
});

// 分页后的账户
const paginatedAccounts = computed(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  const end = start + pageSize.value;
  return filteredAccounts.value.slice(start, end);
});

// 总页数
const totalPages = computed(() => {
  return Math.ceil(filteredAccounts.value.length / pageSize.value);
});

// 过滤器方法
function setActiveFilter(filter: 'all' | 'active' | 'inactive') {
  activeFilter.value = filter;
  currentPage.value = 1;
}

function handleTypeFilter() {
  currentPage.value = 1;
}

function handleCurrencyFilter() {
  currentPage.value = 1;
}

function handleSortChange() {
  currentPage.value = 1;
}

function toggleSortOrder() {
  sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc';
  currentPage.value = 1;
}

function resetFilters() {
  activeFilter.value = 'all';
  selectedType.value = '';
  selectedCurrency.value = '';
  sortBy.value = 'createdAt';
  sortOrder.value = 'desc';
  currentPage.value = 1;
}

// 分页方法
function handlePageChange(page: number) {
  currentPage.value = page;
}

function handlePageSizeChange(size: number) {
  pageSize.value = size;
  currentPage.value = 1;
}

// 监听过滤条件变化，重置页码
watch([activeFilter, selectedType, selectedCurrency], () => {
  currentPage.value = 1;
});

// 图标和名称映射函数
function getAccountTypeIcon(type: AccountType): LucideIcon {
  const icons: Record<AccountType, LucideIcon> = {
    Savings: PiggyBank,
    Cash: DollarSign,
    Bank: PiggyBank,
    CreditCard,
    Investment: TrendingUp,
    Alipay: Wallet,
    WeChat: Wallet2,
    CloudQuickPass: Cloud,
    Other: Wallet,
  };
  return icons[type] || Wallet;
}

function getAccountTypeName(type: AccountType): string {
  const names: Record<AccountType, string> = {
    Savings: '储蓄账户',
    Cash: '现金',
    Bank: '银行账户',
    CreditCard: '信用卡',
    Investment: '投资账户',
    Alipay: '支付宝',
    WeChat: '微信',
    CloudQuickPass: '云闪付',
    Other: '其他',
  };
  return names[type] || '未知类型';
}
</script>

<template>
  <div class="min-h-25">
    <!-- 过滤选项区域 -->
    <div class="mb-5 p-2 rounded-lg bg-gray-50 flex flex-wrap gap-3 items-center justify-center">
      <div class="flex flex-wrap gap-3 items-center">
        <!-- 账户状态过滤 -->
        <div class="filter-flex-wrap">
          <div class="flex gap-1">
            <button
              class="text-xs font-medium px-3 py-1.5 border rounded-full transition-all" :class="[
                activeFilter === 'all'
                  ? 'bg-blue-500 text-white border-blue-500'
                  : 'bg-white text-gray-600 border-gray-300 hover:border-blue-400',
              ]" @click="setActiveFilter('all')"
            >
              {{ t('common.actions.all') }}<span class="text-xs ml-1 opacity-75">[{{ totalAccounts }}]</span>
            </button>
            <button
              class="text-xs font-medium px-3 py-1.5 border rounded-full transition-all" :class="[
                activeFilter === 'active'
                  ? 'bg-green-500 text-white border-green-500'
                  : 'bg-white text-gray-600 border-gray-300 hover:border-green-400',
              ]" @click="setActiveFilter('active')"
            >
              <LucideCheckCircle class="mr-1 h-3 w-3" />
              {{ t('common.status.active') }}<span class="text-xs ml-1 opacity-75">({{ activeAccounts }})</span>
            </button>
            <button
              class="text-xs font-medium px-3 py-1.5 border rounded-full transition-all" :class="[
                activeFilter === 'inactive'
                  ? 'bg-gray-500 text-white border-gray-500'
                  : 'bg-white text-gray-600 border-gray-300 hover:border-gray-400',
              ]" @click="setActiveFilter('inactive')"
            >
              <LucideXCircle class="mr-1 h-3 w-3" />
              {{ t('common.status.inactive') }}<span class="text-xs ml-1 opacity-75">({{ inactiveAccounts }})</span>
            </button>
          </div>
        </div>

        <!-- 账户类型过滤 -->
        <div class="filter-flex-wrap">
          <select
            v-model="selectedType" class="text-xs px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:border-transparent focus:ring-2 focus:ring-blue-500"
            @change="handleTypeFilter"
          >
            <option value="">
              {{ t('common.actions.all') }}{{ t('common.misc.types') }}
            </option>
            <option v-for="type in accountTypes" :key="type" :value="type">
              {{ getAccountTypeName(type) }}
            </option>
          </select>
        </div>

        <!-- 币种过滤 -->
        <div class="filter-flex-wrap">
          <select
            v-model="selectedCurrency" class="text-xs px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:border-transparent focus:ring-2 focus:ring-blue-500"
            @change="handleCurrencyFilter"
          >
            <option value="">
              {{ t('common.actions.all') }}{{ t('financial.currency') }}
            </option>
            <option v-for="currency in currencies" :key="currency" :value="currency">
              {{ currency }}
            </option>
          </select>
        </div>

        <!-- 排序选项 -->
        <div class="filter-flex-wrap">
          <select
            v-model="sortBy" class="text-xs px-3 py-1.5 border border-gray-300 rounded-md focus:outline-none focus:border-transparent focus:ring-2 focus:ring-blue-500"
            @change="handleSortChange"
          >
            <option value="createdAt">
              {{ t('date.createDate') }}
            </option>
            <option value="name">
              {{ t('financial.account.name') }}
            </option>
            <option value="balance">
              {{ t('financial.balance') }}
            </option>
            <option value="type">
              {{ t('financial.account.type') }}
            </option>
          </select>
          <button
            class="text-gray-600 p-1.5 transition-colors hover:text-blue-500" :title="sortOrder === 'asc' ? t('common.sorting.asc') : t('common.sorting.desc')"
            @click="toggleSortOrder"
          >
            <LucideArrowUpDown class="btn-lucide" :class="sortOrder === 'desc' && 'rotate-180'" />
          </button>
        </div>

        <!-- 清空过滤器 -->
        <button
          class="text-sm text-gray-700 px-3 py-1.5 rounded-md bg-gray-200 transition-colors hover:bg-gray-300"
          @click="resetFilters"
        >
          <LucideRotateCcw class="btn-lucide" />
        </button>
      </div>
    </div>

    <!-- 账户列表区域 -->
    <div v-if="loading" class="text-gray-500 h-50 flex-justify-center">
      {{ t('common.loading') }}
    </div>

    <div v-else-if="paginatedAccounts.length === 0" class="text-gray-400 flex-col h-50 flex-justify-center">
      <div class="text-6xl mb-4 opacity-50">
        <LucideCreditCard class="wh-5" />
      </div>
      <div class="text-base">
        {{ filteredAccounts.length === 0 ? t('financial.messages.noPatternAccount') : t('financial.noAccount') }}
      </div>
    </div>

    <div
      v-else
      class="mb-6 gap-5 grid"
      :class="[
        { 'grid-template-columns-320': !mediaQueries.isMobile },
      ]"
    >
      <div
        v-for="account in paginatedAccounts"
        :key="account.serialNum"
        class="p-2 border rounded-lg bg-white transition-all hover:shadow-md"
        :class="{
          'opacity-60 bg-gray-100': !account.isActive,
        }" :style="{
          borderColor: account.color || '#E5E7EB',
        }"
      >
        <div class="mb-4 flex flex-wrap gap-2 items-center justify-between">
          <!-- 类型图标 + 类型名称 + 账户名称 + 币种 -->
          <div class="text-gray-800 flex gap-3 items-center">
            <component :is="getAccountTypeIcon(account.type)" class="text-blue-500 h-4 w-4" />
            <span class="text-lg text-gray-800 font-semibold">{{ account.name }}</span>
            <span class="text-sm text-gray-700">{{ getAccountTypeName(account.type) }}</span>
            <span class="text-xs text-gray-600">{{ account.currency?.code }}</span>
          </div>

          <!-- 操作按钮 -->
          <div class="p-4 flex items-center justify-between md:justify-end">
            <button
              class="money-option-btn hover:(text-green-500 border-green-500)"
              :title="account.isActive ? t('common.status.stop') : t('common.status.enabled')"
              @click="emit('toggleActive', account.serialNum, !account.isActive)"
            >
              <LucideBan class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(text-blue-500 border-blue-500)" :title="t('common.actions.edit')"
              @click="emit('edit', account)"
            >
              <LucideEdit class="h-4 w-4" />
            </button>
            <button
              class="money-option-btn hover:(text-red-500 border-red-500)"
              :title="t('common.actions.delete')" @click="emit('delete', account.serialNum)"
            >
              <LucideTrash class="h-4 w-4" />
            </button>
          </div>
        </div>

        <div class="mb-4 flex gap-2 items-baseline">
          <span class="text-2xl text-gray-800 font-semibold">{{ formatCurrency(account.balance) }}</span>
        </div>

        <div class="pt-4 border-t border-gray-200">
          <div class="text-sm mb-2 flex justify-between">
            <span class="text-gray-600"> {{ t('date.createDate') }} </span>
            <span class="text-gray-800">{{ DateUtils.formatDate(account.createdAt) }}</span>
          </div>
          <div v-if="account.description" class="text-sm mb-2 flex justify-between">
            <span class="text-gray-600"> {{ t('common.misc.remark') }} </span>
            <span class="text-gray-800"> {{ account.description }} </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 -->
    <div v-if="totalPages > 1" class="mt-4 flex justify-center">
      <SimplePagination
        :current-page="currentPage"
        :total-pages="totalPages"
        :total-items="filteredAccounts.length"
        :page-size="pageSize"
        :show-total="false"
        :show-page-size="true"
        :page-size-options="[4, 8, 12, 20]"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
    </div>
  </div>
</template>

<style lang="postcss">
.money-option-btn {
  @apply inline-flex items-center justify-center w-8 h-8 rounded-lg border border-gray-300 text-gray-600 hover:shadow-md transition-all duration-200 bg-white;
}
</style>
