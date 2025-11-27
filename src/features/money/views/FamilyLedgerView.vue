<script setup lang="ts">
import { LucidePlus } from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import { computed, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
import { useFamilyLedgerStore } from '@/stores/money';
import { deepDiff } from '@/utils/diffObject';
import { toast } from '@/utils/toast';
import FamilyLedgerList from '../components/FamilyLedgerList.vue';
import FamilyLedgerModal from '../components/FamilyLedgerModal.vue';
import type { FamilyLedger, FamilyLedgerUpdate, FamilyMember } from '@/schema/money';

const router = useRouter();
const route = useRoute();
const familyLedgerStore = useFamilyLedgerStore();

const showLedgerModal = ref(false);
const selectedLedger = ref<FamilyLedger | null>(null);

// 删除确认状态
const showDeleteConfirm = ref(false);
const ledgerToDelete = ref<string | null>(null);
const deletingLedger = ref(false);

// 使用store中的状态
const { ledgers, loading } = storeToRefs(familyLedgerStore);
const showingDetail = computed(() => route.name === 'family-ledger-detail');

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
    toast.success(`已切换到账本: ${ledger.name}`);
    await router.push({
      path: `/family-ledger/${ledger.serialNum}`,
    });
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

async function updateLedger(serialNum: string, ledgerData: FamilyLedgerUpdate) {
  try {
    if (!selectedLedger.value) return;
    await familyLedgerStore.updateLedger(serialNum, ledgerData);
    toast.success('更新成功');
  } catch (error) {
    console.error('更新账本失败:', error);
    toast.error('更新失败');
    throw error;
  }
}

async function saveLedger(ledgerData: FamilyLedger & { selectedAccounts?: any[] }) {
  try {
    let ledgerSerialNum: string;
    const isEditMode = !!selectedLedger.value;

    if (isEditMode && selectedLedger.value) {
      // 编辑模式
      const original = selectedLedger.value;
      const diff = deepDiff(original, ledgerData) as FamilyLedgerUpdate;
      await updateLedger(selectedLedger.value.serialNum, diff);
      ledgerSerialNum = selectedLedger.value.serialNum;
    } else {
      // 创建模式 - 需要转换 baseCurrency 为字符串
      const createData = {
        ...ledgerData,
        baseCurrency: typeof ledgerData.baseCurrency === 'string'
          ? ledgerData.baseCurrency
          : ledgerData.baseCurrency.code,
      };
      const createdLedger = await familyLedgerStore.createLedger(createData);
      ledgerSerialNum = createdLedger.serialNum;
      toast.success('创建成功');
    }

    // 保存成员信息（创建模式下才需要处理成员创建）
    await saveLedgerMembers(ledgerSerialNum, ledgerData.memberList || []);

    // 保存账户关联
    if (ledgerData.selectedAccounts) {
      await saveLedgerAccounts(ledgerSerialNum, ledgerData.selectedAccounts);
    }

    // 刷新账本列表（后端已同步更新计数）
    await loadLedgers();
    closeLedgerModal();
  } catch (error) {
    console.error('保存失败:', error);
    toast.error('保存失败');
  }
}

// 保存账本的成员
async function saveLedgerMembers(ledgerSerialNum: string, members: FamilyMember[]) {
  try {
    const { MoneyDb } = await import('@/services/money/money');

    // 获取现有的成员关联
    const existingLedgerMembers = await MoneyDb.listFamilyLedgerMembers();
    const existingMemberIds = existingLedgerMembers
      .filter(lm => lm.familyLedgerSerialNum === ledgerSerialNum)
      .map(lm => lm.familyMemberSerialNum);

    // Existing member IDs loaded

    // 处理每个成员
    for (const member of members) {
      let memberSerialNum: string;

      // 判断是否需要创建新成员
      // 1. 如果有有效的 serialNum，直接使用
      // 2. 如果没有 serialNum，先按 name 搜索
      // 3. 搜索到了就使用，搜索不到才创建新成员

      const hasValidId = member.serialNum && !member.serialNum.startsWith('temp_');

      if (hasValidId) {
        // 有有效 ID，直接使用
        memberSerialNum = member.serialNum;
        // Using existing member ID
      } else {
        // 没有有效 ID，先按 name 搜索是否存在
        // Searching for member by name

        const allMembers = await MoneyDb.listFamilyMembers();
        const existingMember = allMembers.find(m => m.name === member.name);

        if (existingMember) {
          // 找到了同名成员，使用现有成员
          memberSerialNum = existingMember.serialNum;
          // Found existing member, reusing
        } else {
          // 没找到，创建新成员
          // Creating new member
          const createdMember = await MoneyDb.createFamilyMember({
            name: member.name,
            role: member.role,
            isPrimary: member.isPrimary,
            permissions: member.permissions || '{}',
            userSerialNum: member.userSerialNum,
            avatar: member.avatar,
            colorTag: member.colorTag,
          });
          memberSerialNum = createdMember.serialNum;
          // Created new member
        }
      }

      // 创建账本-成员关联（如果还未关联）
      if (!existingMemberIds.includes(memberSerialNum)) {
        // Creating member association
        await MoneyDb.createFamilyLedgerMember({
          familyLedgerSerialNum: ledgerSerialNum,
          familyMemberSerialNum: memberSerialNum,
        });
        // Member association created
      } else {
        // Skipping existing member
      }
    }

    // All members saved successfully

    // 注意：后端已经在创建/删除关联时自动更新了成员数量
    // 不需要手动调用 updateLedgerMemberCount
  } catch (error) {
    console.error('❌ 保存成员失败:', error);
    throw error;
  }
}

// 保存账本的账户关联
async function saveLedgerAccounts(ledgerSerialNum: string, accounts: any[]) {
  try {
    const { MoneyDb } = await import('@/services/money/money');

    // 获取现有的账户关联
    const existingLedgerAccounts = await MoneyDb.listFamilyLedgerAccountsByLedger(ledgerSerialNum);
    const existingAccountIds = existingLedgerAccounts.map(la => la.accountSerialNum);

    // 获取当前选中的账户ID
    const selectedAccountIds = accounts.map(a => a.serialNum);

    // 创建新的关联
    for (const account of accounts) {
      if (!existingAccountIds.includes(account.serialNum)) {
        await MoneyDb.createFamilyLedgerAccount({
          familyLedgerSerialNum: ledgerSerialNum,
          accountSerialNum: account.serialNum,
        });
      }
    }

    // 删除不再选中的关联
    for (const existingAccount of existingLedgerAccounts) {
      if (!selectedAccountIds.includes(existingAccount.accountSerialNum)) {
        await MoneyDb.deleteFamilyLedgerAccount(
          ledgerSerialNum,
          existingAccount.accountSerialNum,
        );
      }
    }
  } catch (error) {
    console.error('保存账户关联失败:', error);
    throw error;
  }
}

onMounted(() => {
  loadLedgers();
});
</script>

<template>
  <div v-if="!showingDetail" class="family-ledger-container">
    <!-- 头部 -->
    <div class="header">
      <div class="header-info">
        <h2 class="page-title">
          家庭记账
        </h2>
      </div>
      <div class="header-actions">
        <button class="btn btn-primary" @click="showLedgerModal = true">
          <LucidePlus class="icon" />
          创建账本
        </button>
      </div>
    </div>

    <!-- 账本管理列表 -->
    <div class="tab-content">
      <div class="tab-panel">
        <FamilyLedgerList
          :ledgers="ledgers"
          :loading="loading"
          @enter="enterLedger"
          @edit="editLedger"
          @delete="deleteLedger"
        />
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
    <ConfirmDialog
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
  <RouterView v-else />
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
  border-bottom: 1px solid var(--color-gray-200);
}

.header-info {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.page-title {
  font-size: 24px;
  font-weight: 700;
  color: var(--color-base-content);
  margin: 0;
}

.current-ledger-info {
  display: flex;
  align-items: center;
  gap: 12px;
}

.ledger-name {
  font-size: 14px;
  color: var(--color-gray-500);
  background: var(--color-gray-100);
  padding: 4px 8px;
  border-radius: 4px;
}

.ledger-currency {
  font-size: 14px;
  color: var(--color-success);
  font-weight: 600;
}

.header-actions {
  display: flex;
  gap: 12px;
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
  color: var(--color-gray-500);
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
  background: var(--color-primary);
  color: var(--color-primary-content);
}

.btn-primary:hover {
  background: var(--color-primary-hover);
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
