<script setup lang="ts">
import { LucideBarChart3, LucideCalculator } from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import { useFamilyLedgerStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import FamilyStatsView from './FamilyStatsView.vue';
import SettlementView from './SettlementView.vue';
import type { FamilyMember, Transaction } from '@/schema/money';

interface LedgerDetailRouteParams {
  serialNum?: string;
}

const route = useRoute();
const router = useRouter();
const familyLedgerStore = useFamilyLedgerStore();
const { currentLedger, currentLedgerStats } = storeToRefs(familyLedgerStore);

const pageLoading = ref(true);
const transactionsLoading = ref(false);
const allTransactions = ref<Transaction[]>([]);
const selectedMemberSerial = ref<string | null>(null);

// 详情页标签：结算中心 / 统计报表
const activeTab = ref<'settlement' | 'statistics'>('settlement');
const tabs = [
  { key: 'settlement', label: '结算中心', icon: 'Calculator' },
  { key: 'statistics', label: '统计报表', icon: 'BarChart3' },
];

const members = computed(() => currentLedger.value?.memberList ?? []);

const selectedMember = computed<FamilyMember | null>(() => {
  if (!members.value.length) return null;
  return (
    members.value.find(member => member.serialNum === selectedMemberSerial.value) ||
    members.value[0] ||
    null
  );
});

const memberTransactions = computed<Transaction[]>(() => {
  if (!selectedMember.value) return [];
  return allTransactions.value.filter(transaction =>
    transaction.splitMembers?.some(member => member.serialNum === selectedMember.value!.serialNum),
  );
});

const routeSerialNum = computed(() => (route.params as LedgerDetailRouteParams).serialNum);

onMounted(() => {
  hydrateFromRoute();
});

watch(
  () => routeSerialNum.value,
  serialNum => {
    if (typeof serialNum === 'string' && serialNum.length) {
      hydrateFromRoute();
    }
  },
);

watch(
  () => currentLedger.value?.serialNum,
  serialNum => {
    if (!serialNum) return;
    const firstMember = members.value[0];
    selectedMemberSerial.value = firstMember?.serialNum || null;
    loadLedgerTransactions(serialNum);
  },
);

async function hydrateFromRoute() {
  const serialNum = routeSerialNum.value;
  if (!serialNum) {
    router.push('/family-ledger');
    return;
  }

  pageLoading.value = true;
  try {
    if (!familyLedgerStore.ledgers.length) {
      await familyLedgerStore.fetchLedgers();
    }

    const ledger = familyLedgerStore.getLedgerById(serialNum);
    if (!ledger) {
      toast.error('未找到指定的账本');
      router.push('/family-ledger');
      return;
    }

    await familyLedgerStore.switchLedger(serialNum);
    selectedMemberSerial.value = ledger.memberList?.[0]?.serialNum || null;
    await loadLedgerTransactions(serialNum);
  } catch (error) {
    console.error(error);
    toast.error('加载账本详情失败');
    router.push('/family-ledger');
  } finally {
    pageLoading.value = false;
  }
}

async function loadLedgerTransactions(serialNum: string) {
  transactionsLoading.value = true;
  try {
    const relations = await MoneyDb.listFamilyLedgerTransactions();
    const related = relations.filter(relation => relation.familyLedgerSerialNum === serialNum);

    const results = await Promise.all(
      related.map(async relation => {
        const transaction = await MoneyDb.getTransaction(relation.transactionSerialNum);
        return transaction || null;
      }),
    );

    allTransactions.value = results.filter((transaction): transaction is Transaction => Boolean(transaction));
  } catch (error) {
    console.error(error);
    toast.error('加载交易记录失败');
    allTransactions.value = [];
  } finally {
    transactionsLoading.value = false;
  }
}

function selectMember(serialNum: string) {
  selectedMemberSerial.value = serialNum;
}

function goBack() {
  router.push('/family-ledger');
}

function formatCurrency(value?: number | string | null) {
  if (value === undefined || value === null) return '￥0.00';
  const numValue = typeof value === 'string' ? Number.parseFloat(value) : value;
  if (Number.isNaN(numValue)) return '￥0.00';
  return `￥${numValue.toFixed(2)}`;
}

function getRoleName(role: FamilyMember['role']) {
  const mapper: Record<string, string> = {
    Owner: '所有者',
    Admin: '管理员',
    Member: '成员',
    Viewer: '观察者',
  };
  return mapper[role] || role;
}

const currentStats = computed(() => currentLedgerStats.value);
const memberCount = computed(() => currentLedger.value?.members || members.value.length || 0);
const accountCount = computed(() => currentLedger.value?.accounts);
const activeTransactions = computed(() => currentStats.value?.activeTransactionCount || allTransactions.value.length);

function getTabIcon(iconName: string) {
  const iconMap = {
    Calculator: LucideCalculator,
    BarChart3: LucideBarChart3,
  };
  return iconMap[iconName as keyof typeof iconMap] || LucideCalculator;
}
</script>

<template>
  <div class="ledger-detail-view">
    <div v-if="pageLoading" class="page-loader">
      <LucideLoader2 class="spinner" />
      <span>正在加载账本详情...</span>
    </div>

    <template v-else>
      <div v-if="currentLedger" class="detail-content">
        <header class="detail-header">
          <button class="ghost-button" @click="goBack">
            <LucideArrowLeft class="icon" />
          </button>
          <div class="title-block">
            <div class="title-main">
              <h1 class="title-name">
                {{ currentLedger.name || currentLedger.description || '未命名账本' }}
              </h1>
              <p class="title-description text-sm text-muted">
                {{ currentLedger.description || '暂未填写描述' }}
              </p>
            </div>
            <div class="title-footer">
              <div class="tabs-nav">
                <button
                  v-for="tab in tabs"
                  :key="tab.key"
                  class="tab-btn"
                  :class="{ active: activeTab === tab.key }"
                  :title="tab.label"
                  @click="activeTab = tab.key as 'settlement' | 'statistics'"
                >
                  <component :is="getTabIcon(tab.icon)" class="tab-icon" />
                </button>
              </div>
              <div class="meta">
                <span>币种：{{ currentLedger.baseCurrency?.code || 'CNY' }}</span>
                <span>结算周期：{{ currentLedger.settlementCycle }}</span>
                <span>成员数：{{ memberCount }}</span>
                <span>账户数：{{ accountCount }}</span>
              </div>
            </div>
          </div>
        </header>

        <section class="summary-grid">
          <article class="summary-card income">
            <LucideTrendingUp class="card-icon" />
            <div>
              <p>总收入</p>
              <h3>{{ formatCurrency(currentStats?.totalIncome) }}</h3>
            </div>
          </article>
          <article class="summary-card expense">
            <LucideTrendingDown class="card-icon" />
            <div>
              <p>总支出</p>
              <h3>{{ formatCurrency(currentStats?.totalExpense) }}</h3>
            </div>
          </article>
          <article class="summary-card neutral">
            <LucideWallet class="card-icon" />
            <div>
              <p>净余额</p>
              <h3>{{ formatCurrency((currentStats?.totalIncome || 0) - (currentStats?.totalExpense || 0)) }}</h3>
            </div>
          </article>
          <article class="summary-card warning">
            <LucideReceiptText class="card-icon" />
            <div>
              <p>待结算</p>
              <h3>{{ formatCurrency(currentStats?.pendingSettlement) }}</h3>
            </div>
          </article>
          <article class="summary-card info">
            <LucideUsers class="card-icon" />
            <div>
              <p>成员数</p>
              <h3>{{ memberCount }}</h3>
            </div>
          </article>
          <article class="summary-card info">
            <LucideActivity class="card-icon" />
            <div>
              <p>活跃交易</p>
              <h3>{{ activeTransactions }}</h3>
            </div>
          </article>
        </section>

        <!-- 成员概览 / 交易记录 -->
        <section class="detail-body">
          <div class="members-panel">
            <div class="panel-header">
              <h2>成员概览</h2>
            </div>
            <div v-if="members.length" class="members-grid">
              <article
                v-for="member in members"
                :key="member.serialNum"
                class="member-card"
                :class="{ active: member.serialNum === selectedMember?.serialNum }"
                @click="selectMember(member.serialNum)"
              >
                <div class="member-header">
                  <div class="avatar">
                    {{ member.name.charAt(0).toUpperCase() }}
                  </div>
                  <div>
                    <p class="member-name">
                      {{ member.name }}
                    </p>
                    <p class="member-role">
                      {{ getRoleName(member.role) }}
                    </p>
                  </div>
                </div>
                <div class="member-metrics">
                  <div>
                    <span>交易笔数</span>
                    <strong>{{ member.transactionCount ?? 0 }}</strong>
                  </div>
                  <div>
                    <span>总支付</span>
                    <strong>{{ formatCurrency(member.totalPaid) }}</strong>
                  </div>
                  <div>
                    <span>应分摊</span>
                    <strong>{{ formatCurrency(member.totalOwed) }}</strong>
                  </div>
                </div>
              </article>
            </div>
            <div v-else class="empty-state">
              <LucideUserCheck class="empty-icon" />
              <p>尚未添加成员</p>
            </div>
          </div>

          <div class="transactions-panel">
            <div class="panel-header">
              <div>
                <h2>
                  {{ selectedMember ? `${selectedMember.name} 的交易` : '交易记录' }}
                </h2>
                <p>
                  点击左侧成员即可切换查看其交易详情
                </p>
              </div>
            </div>

            <div v-if="transactionsLoading" class="panel-loading">
              <LucideLoader2 class="spinner" />
              <span>正在加载交易...</span>
            </div>

            <div v-else-if="memberTransactions.length === 0" class="empty-state">
              <LucideReceiptText class="empty-icon" />
              <p>暂无相关交易记录</p>
            </div>

            <div v-else class="transactions-table-wrapper">
              <table class="transactions-table">
                <thead>
                  <tr>
                    <th>日期</th>
                    <th>类型</th>
                    <th>金额</th>
                    <th>账户</th>
                    <th>说明</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="transaction in memberTransactions" :key="transaction.serialNum">
                    <td>{{ new Date(transaction.date).toLocaleDateString() }}</td>
                    <td>{{ transaction.transactionType }}</td>
                    <td :class="transaction.transactionType === 'Expense' ? 'negative' : 'positive'">
                      {{ transaction.transactionType === 'Expense' ? '-' : '' }}
                      {{ formatCurrency(transaction.amount) }}
                    </td>
                    <td>{{ transaction.account.name }}</td>
                    <td>{{ transaction.description || '—' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </section>

        <!-- 结算中心 / 统计报表 -->
        <section class="detail-tabs">
          <div class="tab-content">
            <div v-if="activeTab === 'settlement'" class="tab-panel">
              <SettlementView />
            </div>
            <div v-else-if="activeTab === 'statistics'" class="tab-panel">
              <FamilyStatsView />
            </div>
          </div>
        </section>
      </div>

      <div v-else class="empty-state">
        <LucideUsers class="empty-icon" />
        <p>暂无账本数据</p>
      </div>
    </template>
  </div>
</template>

<style scoped>
.ledger-detail-view {
  min-height: 100vh;
  padding: 24px;
  background: var(--color-base-100);
}

.page-loader,
.panel-loading {
  display: flex;
  align-items: center;
  gap: 12px;
  color: var(--color-gray-500);
}

.spinner {
  width: 24px;
  height: 24px;
  animation: spin 1s linear infinite;
}

.detail-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 24px;
  margin-bottom: 24px;
}

.ghost-button {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  border: 1px solid var(--color-primary-soft);
  border-radius: 8px;
  background: var(--color-base-100);
  cursor: pointer;
  color: var(--color-base-content);
}

.icon {
  width: 16px;
  height: 16px;
}

.title-block {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.title-main {
  display: flex;
  align-items: baseline;
  gap: 8px;
}

.title-name {
  margin: 0;
  font-size: 28px;
  color: var(--color-base-content);
}

.title-description {
  margin: 0;
}

.title-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.tabs-nav {
  display: flex;
  align-items: center;
  gap: 8px;
}

.tab-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  border-radius: 999px;
  border: 1px solid transparent;
  background: transparent;
  color: var(--color-gray-600);
  cursor: pointer;
  font-size: 13px;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}

.tab-btn:hover {
  background: var(--color-base-200);
  border-color: var(--color-gray-200);
}

.tab-btn.active {
  background: var(--color-base-300);
  border-color: var(--color-neutral);
  color: var(--color-accent);
}

.tab-icon {
  width: 1rem;
  height: 1rem;
}

.meta {
  display: flex;
  gap: 16px;
  margin-top: 12px;
  color: var(--color-gray-500);
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
  gap: 16px;
}

.summary-card {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 16px;
  border-radius: 16px;
  background: var(--color-base-200);
  box-shadow: 0 1px 3px rgb(15 23 42 / 0.08);
}

.summary-card p {
  margin: 0;
  color: var(--color-gray-600);
}

.summary-card h3 {
  margin: 4px 0 0;
  font-size: 24px;
  color: var(--color-base-content);
}

.summary-card.neutral { border-left: 4px solid var(--color-neutral); }
.summary-card.income { border-left: 4px solid var(--color-success); }
.summary-card.expense { border-left: 4px solid var(--color-error); }
.summary-card.warning { border-left: 4px solid var(--color-warning); }
.summary-card.info { border-left: 4px solid var(--color-info); }

.card-icon {
  width: 32px;
  height: 32px;
  color: var(--color-gray-600);
}

.detail-body {
  display: grid;
  grid-template-columns: minmax(280px, 360px) 1fr;
  gap: 24px;
  margin-top: 32px;
}

.detail-tabs {
  margin-top: 1em;
  margin-left: auto;
  margin-right: auto;
}

.tab-content {
  background: var(--color-base-100);
  border-radius: 1rem;
  padding: 1rem;
  box-shadow: 0 10px 30px rgb(15 23 42 / 0.08);
}

.tab-panel {
  width: 100%;
}

.members-panel,
.transactions-panel {
  background: var(--color-base-100);
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 10px 30px rgb(15 23 42 / 0.08);
}

.panel-header h2 {
  margin: 0;
  font-size: 20px;
  color: var(--color-base-content);
}

.panel-header p {
  margin: 4px 0 0;
  color: var(--color-gray-500);
}

.members-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 16px;
}

.member-card {
  border: 1px solid var(--color-gray-200);
  border-radius: 12px;
  padding: 16px;
  cursor: pointer;
  transition: all 0.2s;
}

.member-card.active {
  border-color: var(--color-primary);
  box-shadow: 0 10px 20px rgb(59 130 246 / 0.15);
}

.member-header {
  display: flex;
  align-items: center;
  gap: 12px;
}

.avatar {
  width: 44px;
  height: 44px;
  border-radius: 12px;
  background: var(--color-gray-200);
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  color: var(--color-base-content);
}

.member-name {
  margin: 0;
  font-weight: 600;
  color: var(--color-base-content);
}

.member-role {
  margin: 4px 0 0;
  color: var(--color-gray-500);
}

.member-metrics {
  display: flex;
  justify-content: space-between;
  margin-top: 12px;
  color: var(--color-gray-600);
}

.member-metrics span {
  font-size: 12px;
  color: var(--color-gray-400);
}

.member-metrics strong {
  display: block;
  font-size: 16px;
  margin-top: 4px;
}

.transactions-table-wrapper {
  margin-top: 16px;
  overflow: auto;
}

.transactions-table {
  width: 100%;
  border-collapse: collapse;
}

.transactions-table th,
.transactions-table td {
  padding: 12px 8px;
  border-bottom: 1px solid var(--color-gray-200);
  text-align: left;
  font-size: 14px;
}

.transactions-table th {
  color: var(--color-gray-400);
  font-weight: 500;
}

.transactions-table td {
  color: var(--color-base-content);
}

.transactions-table .positive {
  color: var(--color-success);
}

.transactions-table .negative {
  color: var(--color-error);
}

.empty-state {
  padding: 32px;
  text-align: center;
  color: var(--color-gray-400);
}

.empty-icon {
  width: 36px;
  height: 36px;
  margin-bottom: 12px;
}

@media (max-width: 1024px) {
  .detail-body {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 768px) {
  .title-footer {
    flex-direction: column;
    align-items: flex-start;
    gap: 8px;
  }

  .meta {
    margin-top: 4px;
    flex-wrap: wrap;
  }
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
