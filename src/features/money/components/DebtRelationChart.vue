<script setup lang="ts">
import { useFamilyMemberStore, useFamilySplitStore } from '@/stores/money';
// 移除未使用的类型导入

interface Props {
  familyLedgerSerialNum: string;
}

const props = defineProps<Props>();

const splitStore = useFamilySplitStore();
const memberStore = useFamilyMemberStore();

// 使用store状态
const { debtRelations, settlementSuggestions } = storeToRefs(splitStore);
const { members } = storeToRefs(memberStore);

// 本地状态
const showSettlementSuggestions = ref(true);
const selectedMember = ref<string | null>(null);

// 获取成员信息
function getMemberInfo(serialNum: string) {
  const member = members.value.find(m => m.serialNum === serialNum);
  return {
    name: member?.name || 'Unknown',
    avatar: member?.avatar,
    colorTag: member?.colorTag || '#e5e7eb',
  };
}

// 计算成员净余额
const memberBalances = computed(() => {
  const balances = new Map<string, number>();

  // 初始化所有成员余额为0
  members.value.forEach(member => {
    balances.set(member.serialNum, 0);
  });

  // 计算债务关系
  debtRelations.value.forEach(debt => {
    if (!debt.isSettled) {
      // 债权人增加余额
      const creditorBalance = balances.get(debt.creditorMemberSerialNum) || 0;
      balances.set(debt.creditorMemberSerialNum, creditorBalance + debt.amount);

      // 债务人减少余额
      const debtorBalance = balances.get(debt.debtorMemberSerialNum) || 0;
      balances.set(debt.debtorMemberSerialNum, debtorBalance - debt.amount);
    }
  });

  return Array.from(balances.entries()).map(([serialNum, balance]) => ({
    serialNum,
    balance,
    ...getMemberInfo(serialNum),
  }));
});

// 债权人列表
const creditors = computed(() =>
  memberBalances.value.filter(m => m.balance > 0).sort((a, b) => b.balance - a.balance),
);

// 债务人列表
const debtors = computed(() =>
  memberBalances.value.filter(m => m.balance < 0).sort((a, b) => a.balance - b.balance),
);

// 平衡成员列表
const balanced = computed(() =>
  memberBalances.value.filter(m => Math.abs(m.balance) < 0.01),
);

// 获取成员相关的债务关系
function getMemberDebts(memberSerialNum: string) {
  return debtRelations.value.filter(debt =>
    !debt.isSettled && (
      debt.creditorMemberSerialNum === memberSerialNum ||
      debt.debtorMemberSerialNum === memberSerialNum
    ),
  );
}

// 格式化金额
function formatAmount(amount: number): string {
  return Math.abs(amount).toFixed(2);
}

// 移除未使用的函数

// 获取余额状态文本
function getBalanceText(balance: number): string {
  if (balance > 0) {
    return '债权';
  } else if (balance < 0) {
    return '债务';
  } else {
    return '平衡';
  }
}

// 选择成员查看详情
function selectMember(serialNum: string) {
  selectedMember.value = selectedMember.value === serialNum ? null : serialNum;
}

// 获取结算建议
async function fetchSettlementSuggestions() {
  try {
    await splitStore.fetchSettlementSuggestions(props.familyLedgerSerialNum);
  } catch (error) {
    console.error('获取结算建议失败:', error);
  }
}

// 初始化数据
onMounted(() => {
  splitStore.setCurrentLedger(props.familyLedgerSerialNum);
  memberStore.setCurrentLedger(props.familyLedgerSerialNum);

  // 加载数据
  memberStore.fetchMembers(props.familyLedgerSerialNum);
  fetchSettlementSuggestions();
});
</script>

<template>
  <div class="debt-chart-container">
    <!-- 头部控制 -->
    <div class="chart-header">
      <h3 class="chart-title">
        债务关系图
      </h3>
      <div class="chart-controls">
        <label class="toggle-label">
          <input
            v-model="showSettlementSuggestions"
            type="checkbox"
            class="toggle-checkbox"
          >
          <span>显示结算建议</span>
        </label>
        <button class="refresh-btn" @click="fetchSettlementSuggestions">
          <LucideRefreshCw class="w-4 h-4" />
          刷新
        </button>
      </div>
    </div>

    <!-- 总览统计 -->
    <div class="overview-stats">
      <div class="stat-card stat-creditors">
        <div class="stat-icon">
          <LucideTrendingUp class="w-5 h-5" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ creditors.length }}
          </div>
          <div class="stat-label">
            债权人
          </div>
        </div>
      </div>

      <div class="stat-card stat-debtors">
        <div class="stat-icon">
          <LucideTrendingDown class="w-5 h-5" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ debtors.length }}
          </div>
          <div class="stat-label">
            债务人
          </div>
        </div>
      </div>

      <div class="stat-card stat-balanced">
        <div class="stat-icon">
          <LucideEqual class="w-5 h-5" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ balanced.length }}
          </div>
          <div class="stat-label">
            已平衡
          </div>
        </div>
      </div>

      <div class="stat-card stat-total">
        <div class="stat-icon">
          <LucideUsers class="w-5 h-5" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ members.length }}
          </div>
          <div class="stat-label">
            总成员
          </div>
        </div>
      </div>
    </div>

    <!-- 成员余额列表 -->
    <div class="balance-section">
      <h4 class="section-title">
        成员余额
      </h4>

      <div class="balance-grid">
        <!-- 债权人 -->
        <div v-if="creditors.length > 0" class="balance-group">
          <h5 class="group-title text-green-600">
            债权人
          </h5>
          <div class="member-list">
            <div
              v-for="member in creditors"
              :key="member.serialNum"
              class="member-item creditor"
              :class="{ active: selectedMember === member.serialNum }"
              @click="selectMember(member.serialNum)"
            >
              <div class="member-avatar">
                <img
                  v-if="member.avatar"
                  :src="member.avatar"
                  :alt="member.name"
                  class="avatar-image"
                >
                <div
                  v-else
                  class="avatar-placeholder"
                  :style="{ backgroundColor: member.colorTag }"
                >
                  {{ member.name.charAt(0).toUpperCase() }}
                </div>
              </div>

              <div class="member-info">
                <div class="member-name">
                  {{ member.name }}
                </div>
                <div class="member-balance positive">
                  +¥{{ formatAmount(member.balance) }}
                </div>
              </div>

              <div class="balance-badge positive">
                {{ getBalanceText(member.balance) }}
              </div>
            </div>
          </div>
        </div>

        <!-- 债务人 -->
        <div v-if="debtors.length > 0" class="balance-group">
          <h5 class="group-title text-red-600">
            债务人
          </h5>
          <div class="member-list">
            <div
              v-for="member in debtors"
              :key="member.serialNum"
              class="member-item debtor"
              :class="{ active: selectedMember === member.serialNum }"
              @click="selectMember(member.serialNum)"
            >
              <div class="member-avatar">
                <img
                  v-if="member.avatar"
                  :src="member.avatar"
                  :alt="member.name"
                  class="avatar-image"
                >
                <div
                  v-else
                  class="avatar-placeholder"
                  :style="{ backgroundColor: member.colorTag }"
                >
                  {{ member.name.charAt(0).toUpperCase() }}
                </div>
              </div>

              <div class="member-info">
                <div class="member-name">
                  {{ member.name }}
                </div>
                <div class="member-balance negative">
                  -¥{{ formatAmount(member.balance) }}
                </div>
              </div>

              <div class="balance-badge negative">
                {{ getBalanceText(member.balance) }}
              </div>
            </div>
          </div>
        </div>

        <!-- 平衡成员 -->
        <div v-if="balanced.length > 0" class="balance-group">
          <h5 class="group-title text-gray-600">
            已平衡
          </h5>
          <div class="member-list">
            <div
              v-for="member in balanced"
              :key="member.serialNum"
              class="member-item balanced"
            >
              <div class="member-avatar">
                <img
                  v-if="member.avatar"
                  :src="member.avatar"
                  :alt="member.name"
                  class="avatar-image"
                >
                <div
                  v-else
                  class="avatar-placeholder"
                  :style="{ backgroundColor: member.colorTag }"
                >
                  {{ member.name.charAt(0).toUpperCase() }}
                </div>
              </div>

              <div class="member-info">
                <div class="member-name">
                  {{ member.name }}
                </div>
                <div class="member-balance neutral">
                  ¥0.00
                </div>
              </div>

              <div class="balance-badge neutral">
                {{ getBalanceText(member.balance) }}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 成员详情 -->
    <div v-if="selectedMember" class="member-details">
      <h4 class="section-title">
        {{ getMemberInfo(selectedMember).name }} 的债务详情
      </h4>

      <div class="debt-list">
        <div
          v-for="debt in getMemberDebts(selectedMember)"
          :key="debt.serialNum"
          class="debt-item"
        >
          <div class="debt-info">
            <div class="debt-participants">
              <span class="creditor">{{ getMemberInfo(debt.creditorMemberSerialNum).name }}</span>
              <LucideArrowRight class="w-4 h-4 text-gray-400" />
              <span class="debtor">{{ getMemberInfo(debt.debtorMemberSerialNum).name }}</span>
            </div>
            <div class="debt-amount">
              ¥{{ debt.amount.toFixed(2) }}
            </div>
          </div>

          <div v-if="debt.description" class="debt-description">
            {{ debt.description }}
          </div>

          <div class="debt-meta">
            <span class="debt-date">
              {{ new Date(debt.createdAt).toLocaleDateString() }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 结算建议 -->
    <div v-if="showSettlementSuggestions && settlementSuggestions.length > 0" class="settlement-suggestions">
      <h4 class="section-title">
        结算建议
      </h4>

      <div class="suggestion-list">
        <div
          v-for="(suggestion, index) in settlementSuggestions"
          :key="index"
          class="suggestion-item"
        >
          <div class="suggestion-flow">
            <div class="flow-from">
              <div class="flow-avatar">
                <div
                  class="avatar-placeholder"
                  :style="{ backgroundColor: getMemberInfo(suggestion.fromMemberSerialNum).colorTag }"
                >
                  {{ suggestion.fromMemberName.charAt(0).toUpperCase() }}
                </div>
              </div>
              <span class="flow-name">{{ suggestion.fromMemberName }}</span>
            </div>

            <div class="flow-arrow">
              <LucideArrowRight class="w-5 h-5 text-blue-500" />
              <div class="flow-amount">
                ¥{{ suggestion.amount.toFixed(2) }}
              </div>
            </div>

            <div class="flow-to">
              <div class="flow-avatar">
                <div
                  class="avatar-placeholder"
                  :style="{ backgroundColor: getMemberInfo(suggestion.toMemberSerialNum).colorTag }"
                >
                  {{ suggestion.toMemberName.charAt(0).toUpperCase() }}
                </div>
              </div>
              <span class="flow-name">{{ suggestion.toMemberName }}</span>
            </div>
          </div>

          <div v-if="suggestion.relatedDebts.length > 0" class="related-debts">
            <span class="related-label">涉及债务:</span>
            <span class="related-count">{{ suggestion.relatedDebts.length }} 笔</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-if="memberBalances.every(m => Math.abs(m.balance) < 0.01)" class="empty-state">
      <LucideCheckCircle class="empty-icon text-green-500" />
      <h3 class="empty-title">
        所有账务已平衡
      </h3>
      <p class="empty-description">
        当前没有未结算的债务关系
      </p>
    </div>
  </div>
</template>

<style scoped>
.debt-chart-container {
  padding: 1rem;
}

.chart-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
}

.chart-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: #1f2937;
}

.chart-controls {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.toggle-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  cursor: pointer;
}

.toggle-checkbox {
  width: 1rem;
  height: 1rem;
}

.refresh-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background-color: #f3f4f6;
  color: #374151;
  border-radius: 0.375rem;
  font-size: 0.875rem;
  transition: background-color 0.2s;
}

.refresh-btn:hover {
  background-color: #e5e7eb;
}

.overview-stats {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 1rem;
  margin-bottom: 2rem;
}

.stat-card {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem;
  background: white;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
}

.stat-icon {
  padding: 0.5rem;
  border-radius: 0.375rem;
}

.stat-creditors .stat-icon {
  background-color: #dcfce7;
  color: #16a34a;
}

.stat-debtors .stat-icon {
  background-color: #fee2e2;
  color: #dc2626;
}

.stat-balanced .stat-icon {
  background-color: #f3f4f6;
  color: #6b7280;
}

.stat-total .stat-icon {
  background-color: #dbeafe;
  color: #2563eb;
}

.stat-content {
  flex: 1;
}

.stat-value {
  font-size: 1.5rem;
  font-weight: 600;
  color: #1f2937;
}

.stat-label {
  font-size: 0.875rem;
  color: #6b7280;
}

.balance-section {
  margin-bottom: 2rem;
}

.section-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 1rem;
}

.balance-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 1.5rem;
}

.balance-group {
  background: white;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
  overflow: hidden;
}

.group-title {
  font-size: 1rem;
  font-weight: 600;
  padding: 0.75rem 1rem;
  background-color: #f9fafb;
  border-bottom: 1px solid #e5e7eb;
  margin: 0;
}

.member-list {
  padding: 0.5rem;
}

.member-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.2s;
}

.member-item:hover {
  background-color: #f9fafb;
}

.member-item.active {
  background-color: #eff6ff;
  border: 1px solid #3b82f6;
}

.member-avatar {
  flex-shrink: 0;
}

.avatar-image {
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  object-fit: cover;
}

.avatar-placeholder {
  width: 2rem;
  height: 2rem;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-weight: 600;
  font-size: 0.875rem;
}

.member-info {
  flex: 1;
}

.member-name {
  font-weight: 500;
  color: #1f2937;
  margin-bottom: 0.125rem;
}

.member-balance {
  font-size: 0.875rem;
  font-weight: 600;
}

.member-balance.positive {
  color: #16a34a;
}

.member-balance.negative {
  color: #dc2626;
}

.member-balance.neutral {
  color: #6b7280;
}

.balance-badge {
  padding: 0.25rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.balance-badge.positive {
  background-color: #dcfce7;
  color: #16a34a;
}

.balance-badge.negative {
  background-color: #fee2e2;
  color: #dc2626;
}

.balance-badge.neutral {
  background-color: #f3f4f6;
  color: #6b7280;
}

.member-details {
  margin-bottom: 2rem;
  padding: 1rem;
  background: white;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
}

.debt-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.debt-item {
  padding: 0.75rem;
  background-color: #f9fafb;
  border-radius: 0.375rem;
  border: 1px solid #e5e7eb;
}

.debt-info {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.debt-participants {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.creditor {
  color: #16a34a;
  font-weight: 500;
}

.debtor {
  color: #dc2626;
  font-weight: 500;
}

.debt-amount {
  font-weight: 600;
  color: #1f2937;
}

.debt-description {
  font-size: 0.875rem;
  color: #6b7280;
  margin-bottom: 0.5rem;
}

.debt-meta {
  font-size: 0.75rem;
  color: #9ca3af;
}

.settlement-suggestions {
  margin-bottom: 2rem;
  padding: 1rem;
  background: white;
  border-radius: 0.5rem;
  border: 1px solid #e5e7eb;
}

.suggestion-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.suggestion-item {
  padding: 1rem;
  background-color: #f0f9ff;
  border-radius: 0.5rem;
  border: 1px solid #bae6fd;
}

.suggestion-flow {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 0.5rem;
}

.flow-from, .flow-to {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
}

.flow-avatar {
  flex-shrink: 0;
}

.flow-avatar .avatar-placeholder {
  width: 1.5rem;
  height: 1.5rem;
  font-size: 0.75rem;
}

.flow-name {
  font-weight: 500;
  color: #1f2937;
}

.flow-arrow {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.flow-amount {
  font-size: 0.875rem;
  font-weight: 600;
  color: #2563eb;
}

.related-debts {
  font-size: 0.75rem;
  color: #6b7280;
}

.related-label {
  margin-right: 0.25rem;
}

.related-count {
  font-weight: 500;
}

.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  text-align: center;
}

.empty-icon {
  width: 4rem;
  height: 4rem;
  margin-bottom: 1rem;
}

.empty-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 0.5rem;
}

.empty-description {
  color: #6b7280;
}
</style>
