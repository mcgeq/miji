<script setup lang="ts">
  import { LucidePlus } from 'lucide-vue-next';
  import { storeToRefs } from 'pinia';
  import { computed, onMounted, ref } from 'vue';
  import { useRoute, useRouter } from 'vue-router';
  import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
  import Button from '@/components/ui/Button.vue';
  import type { Account, FamilyLedger, FamilyLedgerUpdate, FamilyMember } from '@/schema/money';
  import { MoneyDb } from '@/services/money/money';
  import { useFamilyLedgerStore } from '@/stores/money';
  import { deepDiff } from '@/utils/diff';
  import { toast } from '@/utils/toast';
  import FamilyLedgerList from '../components/FamilyLedgerList.vue';
  import FamilyLedgerModal from '../components/FamilyLedgerModal.vue';

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

  async function saveLedger(ledgerData: FamilyLedger & { selectedAccounts?: Account[] }) {
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
          baseCurrency:
            typeof ledgerData.baseCurrency === 'string'
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
  async function saveLedgerAccounts(ledgerSerialNum: string, accounts: Account[]) {
    try {
      // 获取现有的账户关联
      const existingLedgerAccounts =
        await MoneyDb.listFamilyLedgerAccountsByLedger(ledgerSerialNum);
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
  <div v-if="!showingDetail" class="flex flex-col w-full min-h-screen p-5 box-border">
    <!-- 头部 -->
    <div
      class="flex flex-col md:flex-row justify-between items-start md:items-center mb-6 pb-4 border-b border-gray-200 dark:border-gray-700 gap-3 md:gap-0"
    >
      <div class="flex flex-col gap-2">
        <h2 class="text-2xl font-bold text-gray-900 dark:text-gray-100 m-0">家庭记账</h2>
      </div>
      <div class="flex gap-3">
        <Button variant="primary" @click="showLedgerModal = true">
          <LucidePlus class="w-4 h-4" />
          创建账本
        </Button>
      </div>
    </div>

    <!-- 账本管理列表 -->
    <div class="flex-1 min-h-[calc(100vh-200px)] w-full">
      <div class="animate-[fadeIn_0.2s_ease-in-out] h-full w-full">
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
      :icon-buttons="true"
      @confirm="confirmDelete"
      @cancel="cancelDelete"
      @close="cancelDelete"
    />
  </div>
  <RouterView v-else />
</template>
