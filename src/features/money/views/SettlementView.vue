<script setup lang="ts">
import { useFamilyLedgerStore } from '@/stores/money';
import DebtRelationChart from '../components/DebtRelationChart.vue';
import SettlementRecords from '../components/SettlementRecords.vue';

const familyLedgerStore = useFamilyLedgerStore();
const { currentLedger } = storeToRefs(familyLedgerStore);

// 当前选中的标签页
const activeTab = ref<'overview' | 'records'>('overview');

// 切换标签页
function switchTab(tab: 'overview' | 'records') {
  activeTab.value = tab;
}
</script>

<template>
  <div class="settlement-view">
    <div class="view-header">
      <h2 class="view-title">
        结算中心
      </h2>
      <div v-if="currentLedger" class="ledger-info">
        <span class="ledger-name">{{ currentLedger.name }}</span>
      </div>
    </div>

    <!-- 标签页导航 -->
    <div class="tab-navigation">
      <button
        class="tab-button"
        :class="{ active: activeTab === 'overview' }"
        @click="switchTab('overview')"
      >
        <LucideBarChart3 class="w-4 h-4" />
        债务总览
      </button>
      <button
        class="tab-button"
        :class="{ active: activeTab === 'records' }"
        @click="switchTab('records')"
      >
        <LucideFileText class="w-4 h-4" />
        结算记录
      </button>
    </div>

    <!-- 内容区域 -->
    <div class="tab-content">
      <div v-if="activeTab === 'overview'" class="tab-panel">
        <DebtRelationChart
          v-if="currentLedger"
          :family-ledger-serial-num="currentLedger.serialNum"
        />
        <div v-else class="no-ledger-state">
          <LucideAlertCircle class="warning-icon" />
          <h3 class="warning-title">
            请先选择账本
          </h3>
          <p class="warning-description">
            需要选择一个家庭账本才能查看结算信息
          </p>
        </div>
      </div>

      <div v-if="activeTab === 'records'" class="tab-panel">
        <SettlementRecords
          v-if="currentLedger"
          :family-ledger-serial-num="currentLedger.serialNum"
        />
        <div v-else class="no-ledger-state">
          <LucideAlertCircle class="warning-icon" />
          <h3 class="warning-title">
            请先选择账本
          </h3>
          <p class="warning-description">
            需要选择一个家庭账本才能查看结算记录
          </p>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.settlement-view {
  padding: 0;
}

.view-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 2rem;
}

.view-title {
  font-size: 1.5rem;
  font-weight: 600;
  color: #1f2937;
}

.ledger-info {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background-color: #f3f4f6;
  border-radius: 0.375rem;
}

.ledger-name {
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
}

.tab-navigation {
  display: flex;
  gap: 0.25rem;
  margin-bottom: 1.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.tab-button {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: #6b7280;
  border-bottom: 2px solid transparent;
  transition: all 0.2s;
}

.tab-button:hover {
  color: #374151;
  background-color: #f9fafb;
}

.tab-button.active {
  color: #3b82f6;
  border-bottom-color: #3b82f6;
  background-color: #eff6ff;
}

.tab-content {
  min-height: 400px;
}

.tab-panel {
  animation: fadeIn 0.2s ease-in-out;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.no-ledger-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem;
  text-align: center;
}

.warning-icon {
  width: 3rem;
  height: 3rem;
  color: #f59e0b;
  margin-bottom: 1rem;
}

.warning-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 0.5rem;
}

.warning-description {
  color: #6b7280;
}
</style>
