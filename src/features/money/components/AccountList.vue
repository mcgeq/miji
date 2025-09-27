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
import { useAccountFilters } from '../composables/useAccountFilters';
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
const {
  filters,
  accountTypes,
  currencies,
  pagination,
  activeAccounts,
  inactiveAccounts,
  resetFilters,
  setActiveFilter,
  toggleSortOrder,
} = useAccountFilters(() => props.accounts, 4);

function handleTypeFilter() {
  pagination.currentPage.value = 1;
}

function handleCurrencyFilter() {
  pagination.currentPage.value = 1;
}

function handleSortChange() {
  pagination.currentPage.value = 1;
}

// 分页方法
function handlePageChange(page: number) {
  pagination.currentPage.value = page;
}

function handlePageSizeChange(size: number) {
  pagination.pageSize.value = size;
  pagination.currentPage.value = 1;
}

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
  <div class="money-tab-25">
    <!-- 过滤选项区域 -->
    <div class="screening-filtering">
      <div class="flex flex-wrap gap-3 items-center">
        <!-- 账户状态过滤 -->
        <div class="filter-flex-wrap">
          <div class="flex gap-1">
            <button
              class="account-select" :class="[
                filters.status === 'all'
                  ? 'account-select-all'
                  : 'account-select-gray',
              ]" @click="setActiveFilter('all')"
            >
              {{ t('common.actions.all') }}<span class="text-xs ml-1 opacity-75">[{{ pagination.totalItems.value }}]</span>
            </button>
            <button
              class="account-select" :class="[
                filters.status === 'active'
                  ? 'account-select-green'
                  : 'account-select-gray',
              ]" @click="setActiveFilter('active')"
            >
              {{ t('common.status.active') }}<span class="text-xs ml-1 opacity-75">({{ activeAccounts }})</span>
            </button>
            <button
              class="account-select" :class="[
                filters.status === 'inactive'
                  ? 'account-select-back'
                  : 'account-select-gray',
              ]" @click="setActiveFilter('inactive')"
            >
              {{ t('common.status.inactive') }}<span class="text-xs ml-1 opacity-75">({{ inactiveAccounts }})</span>
            </button>
          </div>
        </div>

        <!-- 账户类型过滤 -->
        <div class="filter-flex-wrap">
          <select
            v-model="filters.type"
            class="screening-filtering-select"
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
            v-model="filters.currency"
            class="screening-filtering-select"
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
            v-model="filters.sortBy"
            class="screening-filtering-select"
            @change="handleSortChange"
          >
            <option value="updatedAt">
              {{ t('date.updatedDate') }}
            </option>
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
            class="screening-filtering-select"
            :title="filters.sortOrder === 'asc' ? t('common.sorting.asc') : t('common.sorting.desc')"
            @click="toggleSortOrder"
          >
            <LucideArrowUpDown class="btn-lucide" :class="filters.sortOrder === 'desc' && 'rotate-180'" />
          </button>
        </div>

        <!-- 清空过滤器 -->
        <button
          class="screening-filtering-select"
          @click="resetFilters"
        >
          <LucideRotateCcw class="btn-lucide" />
        </button>
      </div>
    </div>

    <!-- 账户列表区域 -->
    <div
      v-if="loading"
      class="text-gray-500 h-50 flex-justify-center"
    >
      {{ t('common.loading') }}
    </div>

    <div
      v-else-if="pagination.totalItems.value === 0"
      class="text-gray-400 flex-col h-50 flex-justify-center"
    >
      <div class="text-6xl mb-4 opacity-50">
        <LucideCreditCard class="wh-5" />
      </div>
      <div class="text-base">
        {{ pagination.totalItems.value === 0 ? t('financial.messages.noPatternAccount') : t('financial.noAccount') }}
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
        v-for="account in pagination.paginatedItems.value"
        :key="account.serialNum"
        class="bg-base-100 p-2 border rounded-lg bg-white transition-all hover:shadow-md"
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
              class="money-option-btn money-option-ben-hover"
              :title="account.isActive ? t('common.status.stop') : t('common.status.enabled')"
              @click="emit('toggleActive', account.serialNum, !account.isActive)"
            >
              <LucideBan class="wh-4" />
            </button>
            <button
              class="money-option-btn money-option-edit-hover" :title="t('common.actions.edit')"
              @click="emit('edit', account)"
            >
              <LucideEdit class="wh-4" />
            </button>
            <button
              class="money-option-btn money-option-trash-hover"
              :title="t('common.actions.delete')" @click="emit('delete', account.serialNum)"
            >
              <LucideTrash class="wh-4" />
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
    <div v-if="pagination.totalPages.value > 1" class="mt-4 flex justify-center">
      <SimplePagination
        :current-page="pagination.currentPage.value"
        :total-pages="pagination.totalPages.value"
        :total-items="pagination.totalItems.value"
        :page-size="pagination.pageSize.value"
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
.account-select {
  font-size: 0.75rem;
  font-weight: 500;
  padding: 0.375rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 9999px;
  transition: all 0.2s;
}

.account-select-all {
  background-color: #3b82f6;
  color: #ffffff;
  border: 1px solid #3b82f6;
}

.account-select-green {
  background-color: #16a34a;
  border-color: #16a34a;
}

.account-select-gray {
  background-color: var(--color-neutral-content);
  border-color: var(--color-neutral);
}
.account-select-back {
  background-color: #4b5563;
  border-color: #4b5563;
}

.account-select-blue {
  background-color: #3b82f6;
  border-color: #3b82f6;
}

.account-select-green:hover {
  border-color: #16a34a;
}

.account-select-blue:hover {
  border-color: #3b82f6;
}

.account-select-gray:hover {
  border-color: #9ca3af;
}
</style>
