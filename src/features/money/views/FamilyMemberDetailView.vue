<script setup lang="ts">
import {
  LucideActivity,
  LucideArrowLeft,
  LucideCoins,
  LucideTrendingUp,
  LucideWallet,
} from 'lucide-vue-next';
import { useFamilyMemberStore } from '@/stores/money';
import MemberDebtRelations from '../components/MemberDebtRelations.vue';
import MemberSplitRecordList from '../components/MemberSplitRecordList.vue';
import MemberTransactionList from '../components/MemberTransactionList.vue';

const route = useRoute();
const router = useRouter();
const memberStore = useFamilyMemberStore();

const memberSerialNum = computed(() => {
  const params = route.params as { memberSerialNum?: string };
  return params.memberSerialNum || '';
});
const activeTab = ref<'transactions' | 'splits' | 'debts'>('transactions');

// 获取成员信息
const member = computed(() => memberStore.getMemberById(memberSerialNum.value));

// 获取成员统计
const memberStats = computed(() => memberStore.getMemberStats(memberSerialNum.value));

// 页面加载
const loading = ref(true);

onMounted(async () => {
  try {
    if (!member.value) {
      await memberStore.fetchMembers();
    }
    await memberStore.fetchMemberStats(memberSerialNum.value);
  } catch (error) {
    console.error('Failed to load member details:', error);
  } finally {
    loading.value = false;
  }
});

function goBack() {
  router.back();
}

function formatCurrency(amount: number | undefined): string {
  if (amount === undefined || amount === null) return '¥0.00';
  return `¥${amount.toFixed(2)}`;
}

function getBalanceClass(balance: number | undefined): string {
  if (!balance) return 'neutral';
  return balance > 0 ? 'positive' : balance < 0 ? 'negative' : 'neutral';
}

function getRoleName(role: string): string {
  const roleMap: Record<string, string> = {
    Owner: '所有者',
    Admin: '管理员',
    Member: '成员',
    Viewer: '查看者',
  };
  return roleMap[role] || role;
}
</script>

<template>
  <div class="member-detail-view">
    <div v-if="loading" class="page-loader">
      <div class="spinner" />
      <span>加载中...</span>
    </div>

    <template v-else-if="member">
      <!-- 头部 -->
      <header class="detail-header">
        <button class="btn-back" @click="goBack">
          <LucideArrowLeft class="icon" />
        </button>
        <div class="member-header-info">
          <div
            class="member-avatar-large"
            :style="{ backgroundColor: member.colorTag || '#3b82f6' }"
          >
            {{ member.name.charAt(0).toUpperCase() }}
          </div>
          <div class="member-info-section">
            <h1>{{ member.name }}</h1>
            <span class="role-badge" :class="member.role">
              {{ getRoleName(member.role) }}
            </span>
            <p v-if="member.userSerialNum" class="member-user-id">
              ID: {{ member.userSerialNum }}
            </p>
          </div>
        </div>
      </header>

      <!-- 财务统计卡片 -->
      <section class="stats-grid">
        <div class="stat-card">
          <LucideWallet class="stat-icon" />
          <div>
            <label>总支付</label>
            <h3>{{ formatCurrency(memberStats?.totalPaid) }}</h3>
          </div>
        </div>
        <div class="stat-card">
          <LucideCoins class="stat-icon" />
          <div>
            <label>应分摊</label>
            <h3>{{ formatCurrency(memberStats?.totalOwed) }}</h3>
          </div>
        </div>
        <div class="stat-card" :class="getBalanceClass(memberStats?.netBalance)">
          <LucideTrendingUp class="stat-icon" />
          <div>
            <label>净余额</label>
            <h3>{{ formatCurrency(memberStats?.netBalance) }}</h3>
          </div>
        </div>
        <div class="stat-card">
          <LucideActivity class="stat-icon" />
          <div>
            <label>交易笔数</label>
            <h3>{{ memberStats?.transactionCount || 0 }}</h3>
          </div>
        </div>
      </section>

      <!-- 标签页 -->
      <section class="detail-tabs">
        <div class="tabs-nav">
          <button
            :class="{ active: activeTab === 'transactions' }"
            @click="activeTab = 'transactions'"
          >
            交易记录
          </button>
          <button
            :class="{ active: activeTab === 'splits' }"
            @click="activeTab = 'splits'"
          >
            分摊记录
          </button>
          <button
            :class="{ active: activeTab === 'debts' }"
            @click="activeTab = 'debts'"
          >
            债务关系
          </button>
        </div>

        <div class="tab-content">
          <div v-if="activeTab === 'transactions'" class="tab-panel">
            <MemberTransactionList :member-serial-num="memberSerialNum" />
          </div>
          <div v-if="activeTab === 'splits'" class="tab-panel">
            <MemberSplitRecordList :member-serial-num="memberSerialNum" />
          </div>
          <div v-if="activeTab === 'debts'" class="tab-panel">
            <MemberDebtRelations :member-serial-num="memberSerialNum" />
          </div>
        </div>
      </section>
    </template>

    <div v-else class="error-state">
      <p>未找到成员信息</p>
      <button @click="goBack">
        返回
      </button>
    </div>
  </div>
</template>

<style scoped>
.member-detail-view {
  min-height: 100vh;
  background: var(--color-base-100);
  padding: 1.5rem;
}

.page-loader,
.error-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 60vh;
  gap: 1rem;
}

.spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--color-base-300);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Header */
.detail-header {
  display: flex;
  gap: 1rem;
  margin-bottom: 2rem;
}

.btn-back {
  padding: 0.5rem;
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-back:hover {
  background: var(--color-base-200);
}

.icon {
  width: 20px;
  height: 20px;
}

.member-header-info {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  flex: 1;
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: var(--shadow-sm);
}

.member-avatar-large {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 2rem;
  font-weight: 600;
  flex-shrink: 0;
}

.member-info-section h1 {
  font-size: 1.5rem;
  font-weight: 600;
  margin: 0 0 0.5rem 0;
}

.role-badge {
  display: inline-block;
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-size: 0.875rem;
  font-weight: 500;
}

.role-badge.Owner {
  background: #fef3c7;
  color: #92400e;
}

.role-badge.Admin {
  background: #dbeafe;
  color: #1e40af;
}

.role-badge.Member {
  background: #d1fae5;
  color: #065f46;
}

.member-user-id {
  margin: 0.5rem 0 0 0;
  color: var(--color-gray-500);
  font-size: 0.875rem;
}

/* Stats Grid */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  background: white;
  padding: 1.5rem;
  border-radius: 12px;
  box-shadow: var(--shadow-sm);
  display: flex;
  align-items: center;
  gap: 1rem;
}

.stat-icon {
  width: 40px;
  height: 40px;
  padding: 0.5rem;
  border-radius: 8px;
  background: var(--color-base-200);
  color: var(--color-primary);
}

.stat-card.positive .stat-icon {
  background: #d1fae5;
  color: #059669;
}

.stat-card.negative .stat-icon {
  background: #fee2e2;
  color: #dc2626;
}

.stat-card label {
  display: block;
  font-size: 0.875rem;
  color: var(--color-gray-500);
  margin-bottom: 0.25rem;
}

.stat-card h3 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 600;
}

.stat-card.positive h3 {
  color: #059669;
}

.stat-card.negative h3 {
  color: #dc2626;
}

/* Tabs */
.detail-tabs {
  background: white;
  border-radius: 12px;
  box-shadow: var(--shadow-sm);
  overflow: hidden;
}

.tabs-nav {
  display: flex;
  border-bottom: 1px solid var(--color-base-300);
}

.tabs-nav button {
  flex: 1;
  padding: 1rem;
  background: none;
  border: none;
  cursor: pointer;
  font-size: 1rem;
  font-weight: 500;
  color: var(--color-gray-500);
  transition: all 0.2s;
  border-bottom: 2px solid transparent;
}

.tabs-nav button:hover {
  background: var(--color-base-100);
}

.tabs-nav button.active {
  color: var(--color-primary);
  border-bottom-color: var(--color-primary);
}

.tab-content {
  padding: 2rem;
}

.tab-panel {
  min-height: 400px;
}

/* 响应式 */
@media (max-width: 768px) {
  .member-detail-view {
    padding: 1rem;
  }

  .member-header-info {
    flex-direction: column;
    text-align: center;
  }

  .stats-grid {
    grid-template-columns: 1fr;
  }

  .tabs-nav button {
    font-size: 0.875rem;
    padding: 0.75rem 0.5rem;
  }
}
</style>
