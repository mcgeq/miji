<script setup lang="ts">
import {
  LucideActivity,
  LucideArrowLeft,
  LucideLoader2,
  LucideReceiptText,
  LucideTrendingDown,
  LucideTrendingUp,
  LucideUserCheck,
  LucideUsers,
  LucideWallet,
} from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { computed, onMounted, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { MoneyDb } from '@/services/money/money';
import { useFamilyLedgerStore } from '@/stores/money';
import { toast } from '@/utils/toast';
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

const members = computed(() => currentLedger.value?.members ?? []);

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
    selectedMemberSerial.value = ledger.members?.[0]?.serialNum || null;
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

function formatCurrency(value?: number | null) {
  if (value === undefined || value === null) return '￥0.00';
  return `￥${value.toFixed(2)}`;
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
const memberCount = computed(() => currentLedger.value?.memberCount || members.value.length || 0);
const activeTransactions = computed(() => currentStats.value?.activeTransactionCount || allTransactions.value.length);
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
            返回列表
          </button>
          <div class="title-block">
            <h1>{{ currentLedger.name || currentLedger.description || '未命名账本' }}</h1>
            <p>{{ currentLedger.description || '暂未填写描述' }}</p>
            <div class="meta">
              <span>基础币种：{{ currentLedger.baseCurrency?.code || 'CNY' }}</span>
              <span>结算周期：{{ currentLedger.settlementCycle }}</span>
              <span>成员数：{{ memberCount }}</span>
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
  background: #f8fafc;
}

.page-loader,
.panel-loading {
  display: flex;
  align-items: center;
  gap: 12px;
  color: #64748b;
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
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #fff;
  cursor: pointer;
  color: #1f2937;
}

.icon {
  width: 16px;
  height: 16px;
}

.title-block h1 {
  margin: 0 0 8px;
  font-size: 28px;
  color: #0f172a;
}

.title-block p {
  margin: 0;
  color: #475569;
}

.meta {
  display: flex;
  gap: 16px;
  margin-top: 12px;
  color: #64748b;
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
  background: #fff;
  box-shadow: 0 1px 3px rgb(15 23 42 / 0.08);
}

.summary-card p {
  margin: 0;
  color: #475569;
}

.summary-card h3 {
  margin: 4px 0 0;
  font-size: 24px;
  color: #0f172a;
}

.summary-card.income { border-left: 4px solid #10b981; }
.summary-card.expense { border-left: 4px solid #ef4444; }
.summary-card.warning { border-left: 4px solid #f59e0b; }
.summary-card.info { border-left: 4px solid #3b82f6; }

.card-icon {
  width: 32px;
  height: 32px;
  color: #475569;
}

.detail-body {
  display: grid;
  grid-template-columns: minmax(280px, 360px) 1fr;
  gap: 24px;
  margin-top: 32px;
}

.members-panel,
.transactions-panel {
  background: #fff;
  border-radius: 16px;
  padding: 24px;
  box-shadow: 0 10px 30px rgb(15 23 42 / 0.08);
}

.panel-header h2 {
  margin: 0;
  font-size: 20px;
  color: #0f172a;
}

.panel-header p {
  margin: 4px 0 0;
  color: #64748b;
}

.members-grid {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 16px;
}

.member-card {
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 16px;
  cursor: pointer;
  transition: all 0.2s;
}

.member-card.active {
  border-color: #3b82f6;
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
  background: #e2e8f0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  color: #0f172a;
}

.member-name {
  margin: 0;
  font-weight: 600;
  color: #0f172a;
}

.member-role {
  margin: 4px 0 0;
  color: #64748b;
}

.member-metrics {
  display: flex;
  justify-content: space-between;
  margin-top: 12px;
  color: #475569;
}

.member-metrics span {
  font-size: 12px;
  color: #94a3b8;
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
  border-bottom: 1px solid #e2e8f0;
  text-align: left;
  font-size: 14px;
}

.transactions-table th {
  color: #94a3b8;
  font-weight: 500;
}

.transactions-table td {
  color: #0f172a;
}

.transactions-table .positive {
  color: #10b981;
}

.transactions-table .negative {
  color: #ef4444;
}

.empty-state {
  padding: 32px;
  text-align: center;
  color: #94a3b8;
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

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
