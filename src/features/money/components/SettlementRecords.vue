<script setup lang="ts">
import { useFamilyMemberStore } from '@/stores/money';
import type { SettlementRecord } from '@/schema/money';

interface Props {
  familyLedgerSerialNum: string;
}

const props = defineProps<Props>();

const memberStore = useFamilyMemberStore();

// 本地状态
const settlementRecords = ref<SettlementRecord[]>([]);
const loading = ref(false);
const selectedRecord = ref<SettlementRecord | null>(null);

// 获取成员信息
function getMemberName(serialNum: string): string {
  const member = memberStore.members.find(m => m.serialNum === serialNum);
  return member?.name || 'Unknown';
}

// 格式化日期
function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('zh-CN');
}

// 格式化金额
function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

// 获取结算记录
async function fetchSettlementRecords() {
  loading.value = true;
  try {
    // TODO: 替换为实际API调用
    // console.log('Fetching settlement records for:', props.familyLedgerSerialNum);
    settlementRecords.value = [];
  } catch (error) {
    console.error('获取结算记录失败:', error);
  } finally {
    loading.value = false;
  }
}

// 查看结算详情
function viewDetails(record: SettlementRecord) {
  selectedRecord.value = record;
}

// 关闭详情
function closeDetails() {
  selectedRecord.value = null;
}

// 初始化
onMounted(() => {
  memberStore.fetchMembers(props.familyLedgerSerialNum);
  fetchSettlementRecords();
});
</script>

<template>
  <div class="settlement-records">
    <!-- 头部 -->
    <div class="records-header">
      <h3 class="records-title">
        结算记录
      </h3>
      <button class="refresh-btn" @click="fetchSettlementRecords">
        <LucideRefreshCw class="w-4 h-4" />
        刷新
      </button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-state">
      <div class="loading-spinner" />
      <span>加载中...</span>
    </div>

    <!-- 空状态 -->
    <div v-else-if="settlementRecords.length === 0" class="empty-state">
      <LucideFileText class="empty-icon" />
      <h3 class="empty-title">
        暂无结算记录
      </h3>
      <p class="empty-description">
        还没有进行过结算操作
      </p>
    </div>

    <!-- 记录列表 -->
    <div v-else class="records-list">
      <div
        v-for="record in settlementRecords"
        :key="record.serialNum"
        class="record-item"
        @click="viewDetails(record)"
      >
        <div class="record-header">
          <div class="record-date">
            {{ formatDate(record.settlementDate) }}
          </div>
          <div class="record-amount">
            ¥{{ formatAmount(record.totalSettlementAmount) }}
          </div>
        </div>

        <div class="record-period">
          结算周期: {{ formatDate(record.periodStart) }} - {{ formatDate(record.periodEnd) }}
        </div>

        <div class="record-summary">
          {{ record.settlements.length }} 笔转账
        </div>
      </div>
    </div>

    <!-- 详情模态框 -->
    <div v-if="selectedRecord" class="modal-mask" @click="closeDetails">
      <div class="modal-content" @click.stop>
        <div class="modal-header">
          <h3 class="modal-title">
            结算详情
          </h3>
          <button class="modal-close" @click="closeDetails">
            <LucideX class="w-5 h-5" />
          </button>
        </div>

        <div class="modal-body">
          <div class="detail-section">
            <h4 class="section-title">
              基本信息
            </h4>
            <div class="detail-grid">
              <div class="detail-item">
                <span class="detail-label">结算日期:</span>
                <span class="detail-value">{{ formatDate(selectedRecord.settlementDate) }}</span>
              </div>
              <div class="detail-item">
                <span class="detail-label">结算周期:</span>
                <span class="detail-value">
                  {{ formatDate(selectedRecord.periodStart) }} - {{ formatDate(selectedRecord.periodEnd) }}
                </span>
              </div>
              <div class="detail-item">
                <span class="detail-label">总金额:</span>
                <span class="detail-value">¥{{ formatAmount(selectedRecord.totalSettlementAmount) }}</span>
              </div>
            </div>
          </div>

          <div class="detail-section">
            <h4 class="section-title">
              转账明细
            </h4>
            <div class="settlement-list">
              <div
                v-for="(settlement, index) in selectedRecord.settlements"
                :key="index"
                class="settlement-item"
              >
                <div class="settlement-flow">
                  <span class="from-member">{{ getMemberName(settlement.fromMemberSerialNum) }}</span>
                  <LucideArrowRight class="w-4 h-4 text-gray-400" />
                  <span class="to-member">{{ getMemberName(settlement.toMemberSerialNum) }}</span>
                </div>
                <div class="settlement-amount">
                  ¥{{ formatAmount(settlement.amount) }}
                </div>
              </div>
            </div>
          </div>

          <div v-if="selectedRecord.notes" class="detail-section">
            <h4 class="section-title">
              备注
            </h4>
            <p class="notes-text">
              {{ selectedRecord.notes }}
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.settlement-records {
  padding: 1rem;
}

.records-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1.5rem;
}

.records-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: #1f2937;
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

.loading-state {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 2rem;
  color: #6b7280;
}

.loading-spinner {
  width: 1rem;
  height: 1rem;
  border: 2px solid #e5e7eb;
  border-top-color: #3b82f6;
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
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
  width: 3rem;
  height: 3rem;
  color: #9ca3af;
  margin-bottom: 1rem;
}

.empty-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 0.5rem;
}

.empty-description {
  color: #6b7280;
}

.records-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.record-item {
  padding: 1rem;
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  cursor: pointer;
  transition: all 0.2s;
}

.record-item:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
  transform: translateY(-1px);
}

.record-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.record-date {
  font-weight: 600;
  color: #1f2937;
}

.record-amount {
  font-weight: 600;
  color: #059669;
}

.record-period {
  font-size: 0.875rem;
  color: #6b7280;
  margin-bottom: 0.25rem;
}

.record-summary {
  font-size: 0.875rem;
  color: #374151;
}

.modal-mask {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: white;
  border-radius: 0.5rem;
  width: 90%;
  max-width: 600px;
  max-height: 90vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #1f2937;
}

.modal-close {
  color: #6b7280;
  transition: color 0.2s;
}

.modal-close:hover {
  color: #374151;
}

.modal-body {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

.detail-section {
  margin-bottom: 1.5rem;
}

.section-title {
  font-size: 1rem;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 0.75rem;
}

.detail-grid {
  display: grid;
  gap: 0.75rem;
}

.detail-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.detail-label {
  font-size: 0.875rem;
  color: #6b7280;
}

.detail-value {
  font-size: 0.875rem;
  font-weight: 500;
  color: #1f2937;
}

.settlement-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.settlement-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem;
  background-color: #f9fafb;
  border-radius: 0.375rem;
}

.settlement-flow {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.from-member {
  color: #dc2626;
  font-weight: 500;
}

.to-member {
  color: #16a34a;
  font-weight: 500;
}

.settlement-amount {
  font-weight: 600;
  color: #1f2937;
}

.notes-text {
  font-size: 0.875rem;
  color: #374151;
  line-height: 1.5;
}
</style>
