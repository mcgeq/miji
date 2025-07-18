<template>
  <div class="p-5 max-w-1200px mx-auto">
    <!-- 头部 -->
    <div class="flex justify-between items-center mb-6">
      <h2 class="text-2xl font-bold text-gray-800">家庭账本管理</h2>
      <button @click="showLedgerModal = true" class="btn-primary">
        <Plus class="w-4 h-4 mr-2" />
        创建账本
      </button>
    </div>

    <!-- 账本列表 -->
    <FamilyLedgerList :ledgers="ledgers" :loading="loading" @enter="enterLedger" @edit="editLedger"
      @delete="deleteLedger" />

    <!-- 模态框 -->
    <FamilyLedgerModal v-if="showLedgerModal" :ledger="selectedLedger" @close="closeLedgerModal" @save="saveLedger" />
  </div>
</template>

<script setup lang="ts">
import { Plus } from 'lucide-vue-next';
import { FamilyLedger } from '@/schema/money';
import { toast } from '@/utils/toast';
import FamilyLedgerList from '../components/FamilyLedgerList.vue';
import FamilyLedgerModal from '../components/FamilyLedgerModal.vue';

const loading = ref(false);
const showLedgerModal = ref(false);
const selectedLedger = ref<FamilyLedger | null>(null);
const ledgers = ref<FamilyLedger[]>([]);

const loadLedgers = async () => {
  loading.value = true;
  try {
    // 这里调用实际的 API
    // ledgers.value = await familyLedgerStore.getLedgers();

    // 临时示例数据
    ledgers.value = [];
  } catch (error) {
    toast.error('加载家庭账本失败');
  } finally {
    loading.value = false;
  }
};

const enterLedger = (ledger: FamilyLedger) => {
  // 进入特定账本，跳转到 MoneyView 并设置当前账本上下文
  console.log('进入账本:', ledger);
  // 这里可以设置全局状态或路由跳转
  // router.push({ name: 'MoneyView', params: { ledgerId: ledger.serialNum } });
};

const editLedger = (ledger: FamilyLedger) => {
  selectedLedger.value = ledger;
  showLedgerModal.value = true;
};

const deleteLedger = async (serialNum: string) => {
  if (confirm('确定删除此家庭账本吗？此操作不可恢复！')) {
    try {
      // await familyLedgerStore.deleteLedger(serialNum);
      console.log('删除账本:', serialNum);
      toast.success('删除成功');
      loadLedgers();
    } catch (error) {
      toast.error('删除失败');
    }
  }
};

const closeLedgerModal = () => {
  showLedgerModal.value = false;
  selectedLedger.value = null;
};

const saveLedger = async (ledger: FamilyLedger) => {
  try {
    if (selectedLedger.value) {
      // await familyLedgerStore.updateLedger(ledger);
      console.log('更新账本:', ledger);
      toast.success('更新成功');
    } else {
      // await familyLedgerStore.createLedger(ledger);
      console.log('创建账本:', ledger);
      toast.success('创建成功');
    }
    closeLedgerModal();
    loadLedgers();
  } catch (error) {
    toast.error('保存失败');
  }
};

onMounted(() => {
  loadLedgers();
});
</script>
