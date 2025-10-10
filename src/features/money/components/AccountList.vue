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
      class="loading-container"
    >
      {{ t('common.loading') }}
    </div>

    <div
      v-else-if="pagination.totalItems.value === 0"
      class="empty-state-container"
    >
      <div class="empty-state-icon">
        <LucideCreditCard class="empty-icon" />
      </div>
      <div class="empty-state-text">
        {{ pagination.totalItems.value === 0 ? t('financial.messages.noPatternAccount') : t('financial.noAccount') }}
      </div>
    </div>

    <div
      v-else
      class="accounts-grid"
      :class="[
        { 'grid-template-columns-320': !mediaQueries.isMobile },
      ]"
    >
      <div
        v-for="account in pagination.paginatedItems.value"
        :key="account.serialNum"
        class="account-card"
        :class="{
          'account-card-inactive': !account.isActive,
        }" :style="{
          borderColor: account.color || '#E5E7EB',
        }"
      >
        <div class="account-header">
          <!-- 类型图标 + 类型名称 + 账户名称 + 币种 -->
          <div class="account-info">
            <component :is="getAccountTypeIcon(account.type)" class="account-type-icon" />
            <span class="account-name">{{ account.name }}</span>
            <span class="account-type-name">{{ getAccountTypeName(account.type) }}</span>
            <span class="account-currency">{{ account.currency?.code }}</span>
          </div>

          <!-- 操作按钮 -->
          <div class="account-actions">
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

        <div class="account-balance">
          <span class="balance-amount">{{ formatCurrency(account.balance) }}</span>
        </div>

        <div class="account-details">
          <div class="detail-row">
            <span class="detail-label"> {{ t('date.createDate') }} </span>
            <span class="detail-value">{{ DateUtils.formatDate(account.createdAt) }}</span>
          </div>
          <div v-if="account.description" class="detail-row">
            <span class="detail-label"> {{ t('common.misc.remark') }} </span>
            <span class="detail-value"> {{ account.description }} </span>
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
/* Loading and Empty States */
.loading-container {
  color: #6b7280;
  height: 12.5rem;
  display: flex;
  justify-content: center;
  align-items: center;
}

.empty-state-container {
  color: #9ca3af;
  display: flex;
  flex-direction: column;
  height: 12.5rem;
  justify-content: center;
  align-items: center;
}

.empty-state-icon {
  font-size: 3.75rem;
  margin-bottom: 1rem;
  opacity: 0.5;
}

.empty-icon {
  width: 1.25rem;
  height: 1.25rem;
}

.empty-state-text {
  font-size: 1rem;
}

/* Accounts Grid */
.accounts-grid {
  margin-bottom: 0.5rem;
  gap: 0.5rem;
  display: grid;
}

/* Account Card */
.account-card {
  background-color: var(--color-base-100);
  padding: 0.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
}

.account-card:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.account-card-inactive {
  opacity: 0.6;
  background-color: #f3f4f6;
}

/* Account Header */
.account-header {
  margin-bottom: 1rem;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  justify-content: space-between;
}

.account-info {
  color: #1f2937;
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

.account-type-icon {
  color: #3b82f6;
  height: 1rem;
  width: 1rem;
}

.account-name {
  font-size: 1.125rem;
  color: #1f2937;
  font-weight: 600;
}

.account-type-name {
  font-size: 0.875rem;
  color: #374151;
}

.account-currency {
  font-size: 0.75rem;
  color: #4b5563;
}

.account-actions {
  padding: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

@media (min-width: 768px) {
  .account-actions {
    justify-content: flex-end;
  }
}

/* Account Balance */
.account-balance {
  margin-bottom: 1rem;
  display: flex;
  gap: 0.5rem;
  align-items: baseline;
}

.balance-amount {
  font-size: 1.5rem;
  color: #1f2937;
  font-weight: 600;
}

/* Account Details */
.account-details {
  padding-top: 1rem;
  border-top: 1px solid #e5e7eb;
}

.detail-row {
  font-size: 0.875rem;
  margin-bottom: 0.5rem;
  display: flex;
  justify-content: space-between;
}

.detail-label {
  color: #4b5563;
}

.detail-value {
  color: #1f2937;
}

/* Account Select Buttons */
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
