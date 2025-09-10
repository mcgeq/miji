<script setup lang="ts">
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import FamilyLedgerList from '../components/FamilyLedgerList.vue';
import FamilyLedgerModal from '../components/FamilyLedgerModal.vue';
import type { FamilyLedger } from '@/schema/money';

const loading = ref(false);
const showLedgerModal = ref(false);
const selectedLedger = ref<FamilyLedger | null>(null);
const ledgers = ref<FamilyLedger[]>([]);

async function loadLedgers() {
  loading.value = true;
  try {
    // 这里调用实际的 API
    // ledgers.value = await familyLedgerStore.getLedgers();

    // 临时示例数据
    ledgers.value = [];
  } catch (_error) {
    toast.error('加载家庭账本失败');
  } finally {
    loading.value = false;
  }
}

function enterLedger(ledger: FamilyLedger) {
  // 进入特定账本，跳转到 MoneyView 并设置当前账本上下文
  Lg.i('进入账本:', ledger);
  // 这里可以设置全局状态或路由跳转
  // router.push({ name: 'MoneyView', params: { ledgerId: ledger.serialNum } });
}

function editLedger(ledger: FamilyLedger) {
  selectedLedger.value = ledger;
  showLedgerModal.value = true;
}

async function deleteLedger(serialNum: string) {
// confirm('确定删除此家庭账本吗？此操作不可恢复！')
  if (true) {
    try {
      // await familyLedgerStore.deleteLedger(serialNum);
      Lg.i('删除账本:', serialNum);
      toast.success('删除成功');
      loadLedgers();
    } catch (_error) {
      toast.error('删除失败');
    }
  }
}

function closeLedgerModal() {
  showLedgerModal.value = false;
  selectedLedger.value = null;
}

async function saveLedger(ledger: FamilyLedger) {
  try {
    if (selectedLedger.value) {
      // await familyLedgerStore.updateLedger(ledger);
      Lg.i('更新账本:', ledger);
      toast.success('更新成功');
    } else {
      // await familyLedgerStore.createLedger(ledger);
      Lg.i('创建账本:', ledger);
      toast.success('创建成功');
    }
    closeLedgerModal();
    loadLedgers();
  } catch (_error) {
    toast.error('保存失败');
  }
}

onMounted(() => {
  loadLedgers();
});
</script>

<template>
  <div class="mx-auto p-5 max-w-1200px">
    <!-- 头部 -->
    <div class="mb-6 flex items-center justify-between">
      <h2 class="text-2xl text-gray-800 font-bold">
        家庭账本管理
      </h2>
      <button class="btn-primary" @click="showLedgerModal = true">
        <LucidePlus class="mr-2 h-4 w-4" />
        创建账本
      </button>
    </div>

    <!-- 账本列表 -->
    <FamilyLedgerList
      :ledgers="ledgers" :loading="loading" @enter="enterLedger" @edit="editLedger"
      @delete="deleteLedger"
    />

    <!-- 模态框 -->
    <FamilyLedgerModal v-if="showLedgerModal" :ledger="selectedLedger" @close="closeLedgerModal" @save="saveLedger" />
  </div>
</template>
