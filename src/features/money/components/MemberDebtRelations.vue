<script setup lang="ts">
import { LucideArrowRight, LucideTrendingDown, LucideTrendingUp } from 'lucide-vue-next';
import type { DebtRelation } from '@/schema/money';

interface Props {
  memberSerialNum: string;
}

const props = defineProps<Props>();

const debtRelations = ref<DebtRelation[]>([]);
const loading = ref(true);

// 加载债务关系
onMounted(async () => {
  await loadDebtRelations();
});

async function loadDebtRelations() {
  loading.value = true;
  try {
    // TODO: 替换为实际API调用
    // const relations = await DebtApi.getDebtRelations({ memberSerialNum: props.memberSerialNum });
    // debtRelations.value = relations;

    // 临时模拟数据
    debtRelations.value = [];
  } catch (error) {
    console.error('Failed to load debt relations:', error);
  } finally {
    loading.value = false;
  }
}

// 我欠别人的债务
const debts = computed(() =>
  debtRelations.value.filter(r => r.debtorMemberSerialNum === props.memberSerialNum),
);

// 别人欠我的债权
const credits = computed(() =>
  debtRelations.value.filter(r => r.creditorMemberSerialNum === props.memberSerialNum),
);

// 净余额
const netBalance = computed(() => {
  const totalCredit = credits.value.reduce((sum, r) => sum + r.amount, 0);
  const totalDebt = debts.value.reduce((sum, r) => sum + r.amount, 0);
  return totalCredit - totalDebt;
});

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${Math.abs(amount).toFixed(2)}`;
}
</script>

<template>
  <div class="member-debt-relations">
    <!-- 加载状态 -->
    <div v-if="loading" class="loading-state">
      <div class="spinner" />
      <span>加载中...</span>
    </div>

    <template v-else>
      <!-- 净余额卡片 -->
      <div class="net-balance-card" :class="netBalance > 0 ? 'positive' : netBalance < 0 ? 'negative' : 'neutral'">
        <div class="balance-info">
          <label>净余额</label>
          <h2 class="balance-amount">
            {{ netBalance > 0 ? '+' : netBalance < 0 ? '-' : '' }}
            {{ formatAmount(netBalance) }}
          </h2>
          <p class="balance-desc">
            {{ netBalance > 0 ? '您有应收款项' : netBalance < 0 ? '您有应付款项' : '已结清' }}
          </p>
        </div>
        <component
          :is="netBalance > 0 ? LucideTrendingUp : netBalance < 0 ? LucideTrendingDown : LucideArrowRight"
          class="balance-icon"
        />
      </div>

      <!-- 债务列表 -->
      <div class="relations-container">
        <!-- 应收款（别人欠我的） -->
        <section v-if="credits.length > 0" class="relations-section">
          <h3 class="section-title credit">
            <LucideTrendingUp class="title-icon" />
            应收款
          </h3>
          <div class="relation-list">
            <div
              v-for="credit in credits"
              :key="credit.serialNum"
              class="relation-item credit"
            >
              <div class="relation-header">
                <span class="relation-member">成员 {{ credit.debtorMemberSerialNum.slice(0, 8) }}</span>
                <span class="relation-amount">{{ formatAmount(credit.amount) }}</span>
              </div>
              <div class="relation-footer">
                <span class="relation-status" :class="[credit.isSettled ? 'settled' : 'pending']">
                  {{ credit.isSettled ? '已结算' : '待结算' }}
                </span>
                <span class="relation-date">
                  {{ new Date(credit.createdAt).toLocaleDateString('zh-CN') }}
                </span>
              </div>
            </div>
          </div>
          <div class="section-summary">
            <span>小计</span>
            <strong>{{ formatAmount(credits.reduce((sum, r) => sum + r.amount, 0)) }}</strong>
          </div>
        </section>

        <!-- 应付款（我欠别人的） -->
        <section v-if="debts.length > 0" class="relations-section">
          <h3 class="section-title debt">
            <LucideTrendingDown class="title-icon" />
            应付款
          </h3>
          <div class="relation-list">
            <div
              v-for="debt in debts"
              :key="debt.serialNum"
              class="relation-item debt"
            >
              <div class="relation-header">
                <span class="relation-member">成员 {{ debt.creditorMemberSerialNum.slice(0, 8) }}</span>
                <span class="relation-amount">{{ formatAmount(debt.amount) }}</span>
              </div>
              <div class="relation-footer">
                <span class="relation-status" :class="[debt.isSettled ? 'settled' : 'pending']">
                  {{ debt.isSettled ? '已结算' : '待结算' }}
                </span>
                <span class="relation-date">
                  {{ new Date(debt.createdAt).toLocaleDateString('zh-CN') }}
                </span>
              </div>
            </div>
          </div>
          <div class="section-summary">
            <span>小计</span>
            <strong>{{ formatAmount(debts.reduce((sum, r) => sum + r.amount, 0)) }}</strong>
          </div>
        </section>

        <!-- 空状态 -->
        <div v-if="credits.length === 0 && debts.length === 0" class="empty-state">
          <LucideArrowRight class="empty-icon" />
          <p>暂无债务关系</p>
          <span class="empty-hint">参与分摊后，债务关系将显示在这里</span>
        </div>
      </div>
    </template>
  </div>
</template>

<style scoped>
.member-debt-relations {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

/* 加载状态 */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 0;
  color: var(--color-gray-500);
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-base-300);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 净余额卡片 */
.net-balance-card {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 2rem;
  background: white;
  border: 2px solid var(--color-base-300);
  border-radius: 16px;
  box-shadow: var(--shadow-lg);
}

.net-balance-card.positive {
  background: linear-gradient(135deg, #d1fae5 0%, white 100%);
  border-color: #059669;
}

.net-balance-card.negative {
  background: linear-gradient(135deg, #fee2e2 0%, white 100%);
  border-color: #dc2626;
}

.balance-info label {
  display: block;
  font-size: 0.875rem;
  color: var(--color-gray-600);
  margin-bottom: 0.5rem;
}

.balance-amount {
  margin: 0 0 0.5rem 0;
  font-size: 2.5rem;
  font-weight: 700;
}

.net-balance-card.positive .balance-amount {
  color: #059669;
}

.net-balance-card.negative .balance-amount {
  color: #dc2626;
}

.balance-desc {
  margin: 0;
  font-size: 0.875rem;
  color: var(--color-gray-600);
}

.balance-icon {
  width: 64px;
  height: 64px;
  opacity: 0.2;
}

.net-balance-card.positive .balance-icon {
  color: #059669;
}

.net-balance-card.negative .balance-icon {
  color: #dc2626;
}

/* 关系列表容器 */
.relations-container {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.relations-section {
  background: white;
  border: 1px solid var(--color-base-300);
  border-radius: 12px;
  overflow: hidden;
}

.section-title {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 1rem 1.25rem;
  font-size: 1rem;
  font-weight: 600;
  margin: 0;
  border-bottom: 1px solid var(--color-base-200);
}

.section-title.credit {
  background: #d1fae5;
  color: #065f46;
}

.section-title.debt {
  background: #fee2e2;
  color: #991b1b;
}

.title-icon {
  width: 20px;
  height: 20px;
}

.relation-list {
  display: flex;
  flex-direction: column;
}

.relation-item {
  padding: 1rem 1.25rem;
  border-bottom: 1px solid var(--color-base-200);
  transition: background 0.2s;
}

.relation-item:last-child {
  border-bottom: none;
}

.relation-item:hover {
  background: var(--color-base-100);
}

.relation-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.relation-member {
  font-size: 1rem;
  font-weight: 500;
}

.relation-amount {
  font-size: 1.125rem;
  font-weight: 600;
}

.relation-item.credit .relation-amount {
  color: #059669;
}

.relation-item.debt .relation-amount {
  color: #dc2626;
}

.relation-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.875rem;
}

.relation-status {
  padding: 0.25rem 0.75rem;
  border-radius: 12px;
  font-weight: 500;
}

.relation-status.pending {
  background: #fef3c7;
  color: #92400e;
}

.relation-status.confirmed {
  background: #dbeafe;
  color: #1e40af;
}

.relation-status.settled {
  background: #d1fae5;
  color: #065f46;
}

.relation-date {
  color: var(--color-gray-500);
}

.section-summary {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  background: var(--color-base-100);
  font-size: 0.875rem;
}

.section-summary strong {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-gray-900);
}

/* 空状态 */
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.75rem;
  padding: 3rem 0;
  text-align: center;
}

.empty-icon {
  width: 48px;
  height: 48px;
  color: var(--color-gray-300);
}

.empty-state p {
  margin: 0;
  font-size: 1rem;
  color: var(--color-gray-600);
}

.empty-hint {
  font-size: 0.875rem;
  color: var(--color-gray-400);
}

/* 响应式 */
@media (max-width: 768px) {
  .net-balance-card {
    padding: 1.5rem;
  }

  .balance-amount {
    font-size: 2rem;
  }

  .balance-icon {
    width: 48px;
    height: 48px;
  }
}
</style>
