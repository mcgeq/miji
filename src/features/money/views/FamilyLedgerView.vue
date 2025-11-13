<script setup lang="ts">
import { LucideBarChart3, LucideCalculator, LucidePlus, LucideUsers } from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { onMounted, ref } from 'vue';
import ConfirmModal from '@/components/common/ConfirmModal.vue';
import { useFamilyLedgerStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import FamilyLedgerList from '../components/FamilyLedgerList.vue';
import FamilyLedgerModal from '../components/FamilyLedgerModal.vue';
import FamilyStatsView from './FamilyStatsView.vue';
import SettlementView from './SettlementView.vue';
import type { FamilyLedger } from '@/schema/money';

const familyLedgerStore = useFamilyLedgerStore();
const showLedgerModal = ref(false);
const selectedLedger = ref<FamilyLedger | null>(null);

// 删除确认状态
const showDeleteConfirm = ref(false);
const ledgerToDelete = ref<string | null>(null);
const deletingLedger = ref(false);

// 标签页状态
const activeTab = ref('ledgers');
const tabs = [
  { key: 'ledgers', label: '账本管理', icon: 'Users' },
  { key: 'settlement', label: '结算中心', icon: 'Calculator' },
  { key: 'statistics', label: '统计报表', icon: 'BarChart3' },
];

// 使用store中的状态
const { ledgers, loading, currentLedger } = storeToRefs(familyLedgerStore);

// 获取标签页图标
function getTabIcon(iconName: string) {
  const iconMap = {
    Users: LucideUsers,
    Calculator: LucideCalculator,
    BarChart3: LucideBarChart3,
  };
  return iconMap[iconName as keyof typeof iconMap] || LucideUsers;
}

async function loadLedgers() {
  try {
    await familyLedgerStore.fetchLedgers();
  } catch (_error) {
    toast.error('加载家庭账本失败');
  }
}

async function enterLedger(ledger: FamilyLedger) {
  try {
    await familyLedgerStore.switchLedger(ledger.serialNum);
    Lg.i('进入账本:', ledger);
    toast.success(`已切换到账本: ${ledger.name}`);
    // TODO: 跳转到 MoneyView 或其他页面
    // router.push({ name: 'money', query: { ledgerId: ledger.serialNum } });
  } catch (_error) {
    toast.error('切换账本失败');
  }
}

function editLedger(ledger: FamilyLedger) {
  selectedLedger.value = ledger;
  showLedgerModal.value = true;
}

function deleteLedger(serialNum: string) {
  ledgerToDelete.value = serialNum;
  showDeleteConfirm.value = true;
}

async function confirmDelete() {
  if (!ledgerToDelete.value) return;

  deletingLedger.value = true;
  try {
    await familyLedgerStore.deleteLedger(ledgerToDelete.value);
    toast.success('删除成功');
    await loadLedgers(); // 刷新列表
  } catch (error) {
    console.error('删除失败:', error);
    toast.error('删除失败');
  } finally {
    deletingLedger.value = false;
    showDeleteConfirm.value = false;
    ledgerToDelete.value = null;
  }
}

function cancelDelete() {
  showDeleteConfirm.value = false;
  ledgerToDelete.value = null;
}

function closeLedgerModal() {
  showLedgerModal.value = false;
  selectedLedger.value = null;
}

async function saveLedger(ledgerData: any) {
  try {
    if (selectedLedger.value) {
      await familyLedgerStore.updateLedger(selectedLedger.value.serialNum, ledgerData);
      toast.success('更新成功');
    } else {
      await familyLedgerStore.createLedger(ledgerData);
      toast.success('创建成功');
    }

    // 刷新账本列表
    await loadLedgers();

    // 关闭模态框
    closeLedgerModal();
  } catch (error) {
    console.error('保存失败:', error);
    toast.error('保存失败');
  }
}

onMounted(() => {
  loadLedgers();
});
</script>

<template>
  <div class="family-ledger-container">
    <!-- 头部 -->
    <div class="header">
      <div class="header-info">
        <h2 class="page-title">
          家庭记账
        </h2>
        <div v-if="currentLedger" class="current-ledger-info">
          <span class="ledger-name">{{ currentLedger.name }}</span>
          <span class="ledger-currency">{{ currentLedger.baseCurrency.symbol }}</span>
        </div>
      </div>
      <div class="header-actions">
        <button v-if="activeTab === 'ledgers'" class="btn btn-primary" @click="showLedgerModal = true">
          <LucidePlus class="icon" />
          创建账本
        </button>
      </div>
    </div>

    <!-- 标签页导航 -->
    <div class="tabs-nav">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        class="tab-btn"
        :class="{ active: activeTab === tab.key }"
        :title="tab.label"
        @click="activeTab = tab.key"
      >
        <component :is="getTabIcon(tab.icon)" class="tab-icon" />
      </button>
    </div>

    <!-- 标签页内容 -->
    <div class="tab-content">
      <!-- 账本管理 -->
      <div v-if="activeTab === 'ledgers'" class="tab-panel">
        <FamilyLedgerList
          :ledgers="ledgers"
          :loading="loading"
          @enter="enterLedger"
          @edit="editLedger"
          @delete="deleteLedger"
        />
      </div>

      <!-- 结算中心 -->
      <div v-if="activeTab === 'settlement'" class="tab-panel">
        <div v-if="!currentLedger" class="no-ledger-message">
          <p>请先选择一个账本</p>
          <button class="btn btn-primary" @click="activeTab = 'ledgers'">
            选择账本
          </button>
        </div>
        <SettlementView v-else />
      </div>

      <!-- 统计报表 -->
      <div v-if="activeTab === 'statistics'" class="tab-panel">
        <div v-if="!currentLedger" class="no-ledger-message">
          <p>请先选择一个账本</p>
          <button class="btn btn-primary" @click="activeTab = 'ledgers'">
            选择账本
          </button>
        </div>
        <FamilyStatsView v-else />
      </div>
    </div>

    <!-- 模态框 -->
    <FamilyLedgerModal
      v-if="showLedgerModal"
      :ledger="selectedLedger"
      @close="closeLedgerModal"
      @save="saveLedger"
    />

    <!-- 删除确认弹窗 -->
    <ConfirmModal
      :visible="showDeleteConfirm"
      title="确认删除"
      message="确定要删除这个家庭账本吗？删除后将无法恢复，所有相关的交易记录、成员信息等数据都将被永久删除。"
      type="danger"
      confirm-text="删除"
      cancel-text="取消"
      confirm-button-type="danger"
      :loading="deletingLedger"
      @confirm="confirmDelete"
      @cancel="cancelDelete"
      @close="cancelDelete"
    />
  </div>
</template>

<style scoped>
.family-ledger-container {
  display: flex;
  flex-direction: column;
  width: 100%;
  min-height: 100vh;
  padding: 20px;
  box-sizing: border-box;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding-bottom: 16px;
  border-bottom: 1px solid #e5e7eb;
}

.header-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.page-title {
  font-size: 24px;
  font-weight: 700;
  color: #1f2937;
  margin: 0;
}

.current-ledger-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.ledger-name {
  font-size: 14px;
  color: #6b7280;
  background: #f3f4f6;
  padding: 4px 8px;
  border-radius: 4px;
}

.ledger-currency {
  font-size: 14px;
  color: #059669;
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 12px;
}

.tabs-nav {
  display: flex;
  justify-content: center;
  gap: 4px;
  margin-bottom: 16px;
  border-bottom: 1px solid #e5e7eb;
  padding-bottom: 0;
}

.tab-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 8px;
  border: none;
  background: none;
  color: #6b7280;
  cursor: pointer;
  border-radius: 4px 4px 0 0;
  transition: all 0.2s ease;
  position: relative;
  width: 36px;
  height: 36px;
}

.tab-btn:hover {
  color: #374151;
  background: #f9fafb;
  transform: translateY(-1px);
}

.tab-btn.active {
  color: #3b82f6;
  background: #eff6ff;
}

.tab-btn.active::after {
  content: '';
  position: absolute;
  bottom: -1px;
  left: 50%;
  transform: translateX(-50%);
  width: 20px;
  height: 2px;
  background: #3b82f6;
}

.tab-icon {
  width: 18px;
  height: 18px;
}

.tab-content {
  flex: 1;
  min-height: calc(100vh - 200px);
  width: 100%;
}

.tab-panel {
  animation: fadeIn 0.2s ease-in-out;
  height: 100%;
  width: 100%;
}

.no-ledger-message {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 60px 20px;
  text-align: center;
  color: #6b7280;
  height: 100%;
  min-height: 300px;
}

.no-ledger-message p {
  font-size: 16px;
  margin-bottom: 16px;
}

.btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary {
  background: #3b82f6;
  color: white;
}

.btn-primary:hover {
  background: #2563eb;
}

.icon {
  width: 16px;
  height: 16px;
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

/* 响应式设计 */
@media (max-width: 768px) {
  .family-ledger-container {
    padding: 12px;
    min-height: 100vh;
  }

  .header {
    flex-direction: column;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 16px;
    padding-bottom: 12px;
  }

  .page-title {
    font-size: 20px;
  }

  .tabs-nav {
    justify-content: center;
    margin-bottom: 12px;
    gap: 3px;
  }

  .tab-btn {
    width: 34px;
    height: 34px;
    padding: 7px;
  }

  .tab-icon {
    width: 16px;
    height: 16px;
  }

  .tab-content {
    min-height: calc(100vh - 160px);
  }

  .no-ledger-message {
    padding: 40px 16px;
  }

  .no-ledger-message p {
    font-size: 14px;
  }
}

/* 超小屏幕优化 */
@media (max-width: 480px) {
  .family-ledger-container {
    padding: 8px;
  }

  .header {
    margin-bottom: 12px;
    padding-bottom: 8px;
  }

  .page-title {
    font-size: 18px;
  }

  .current-ledger-info {
    flex-direction: column;
    align-items: flex-start;
    gap: 4px;
  }

  .tab-btn {
    width: 32px;
    height: 32px;
    padding: 6px;
  }

  .tab-icon {
    width: 14px;
    height: 14px;
  }

  .tab-content {
    min-height: calc(100vh - 140px);
  }
}
</style>
