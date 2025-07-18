<template>
  <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50" @click.self="$emit('close')">
    <div class="bg-white rounded-lg w-full max-w-4xl max-h-[90vh] overflow-hidden shadow-2xl">
      <!-- 头部 -->
      <div class="flex justify-between items-center p-6 border-b border-gray-200 bg-gray-50">
        <h2 class="text-xl font-bold text-gray-800">家庭账本管理</h2>
        <button @click="$emit('close')" class="text-gray-400 hover:text-gray-600 transition-colors">
          <X class="w-6 h-6" />
        </button>
      </div>

      <!-- 内容 -->
      <div class="p-6 overflow-y-auto max-h-[calc(90vh-120px)]">
        <!-- 操作栏 -->
        <div class="flex justify-between items-center mb-6">
          <div class="text-sm text-gray-600">
            共 {{ ledgers.length }} 个账本
          </div>
          <button @click="showCreateForm = true"
            class="flex items-center gap-2 bg-blue-600 text-white px-4 py-2 rounded-md hover:bg-blue-700 transition-colors">
            <Plus class="w-4 h-4" />
            创建新账本
          </button>
        </div>

        <!-- 账本列表 -->
        <div v-if="ledgers.length > 0" class="grid gap-4">
          <div v-for="ledger in ledgers" :key="ledger.serialNum" :class="[
            'border rounded-lg p-4 cursor-pointer transition-all hover:shadow-md',
            currentLedgerId === ledger.serialNum
              ? 'border-blue-500 bg-blue-50 shadow-md'
              : 'border-gray-200 hover:border-gray-300'
          ]" @click="selectLedger(ledger.serialNum)">
            <div class="flex justify-between items-start">
              <div class="flex-1">
                <div class="flex items-center gap-3 mb-2">
                  <h3 class="font-semibold text-gray-900 text-lg">{{ ledger.name }}</h3>
                  <span v-if="currentLedgerId === ledger.serialNum"
                    class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full font-medium">
                    当前使用
                  </span>
                </div>

                <p class="text-gray-600 text-sm mb-3">{{ ledger.description || '暂无描述' }}</p>

                <div class="flex items-center gap-6 text-xs text-gray-500">
                  <div class="flex items-center gap-1">
                    <CreditCard class="w-3 h-3" />
                    <span>货币: {{ ledger.baseCurrency?.symbol || '¥' }} {{ ledger.baseCurrency?.code || 'CNY' }}</span>
                  </div>
                  <div class="flex items-center gap-1">
                    <Users class="w-3 h-3" />
                    <span>成员: {{ ledger.members?.length || 0 }}人</span>
                  </div>
                  <div class="flex items-center gap-1">
                    <Calendar class="w-3 h-3" />
                    <span>创建: {{ formatDate(ledger.createdAt) }}</span>
                  </div>
                </div>
              </div>

              <div class="flex gap-2 ml-4">
                <button @click.stop="editLedger(ledger)"
                  class="text-gray-400 hover:text-blue-600 p-2 rounded-md hover:bg-blue-50 transition-colors"
                  title="编辑账本">
                  <Edit class="w-4 h-4" />
                </button>
                <button @click.stop="deleteLedger(ledger)"
                  class="text-gray-400 hover:text-red-600 p-2 rounded-md hover:bg-red-50 transition-colors" title="删除账本"
                  :disabled="currentLedgerId === ledger.serialNum">
                  <Trash2 class="w-4 h-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 空状态 -->
        <div v-else class="text-center py-16">
          <HandCoins class="w-20 h-20 mx-auto text-gray-300 mb-6" />
          <h3 class="text-xl font-medium text-gray-900 mb-3">还没有账本</h3>
          <p class="text-gray-500 mb-8 max-w-md mx-auto">
            创建您的第一个家庭账本，开始管理家庭财务。每个账本可以有不同的成员和货币设置。
          </p>
          <button @click="showCreateForm = true"
            class="bg-blue-600 text-white px-6 py-3 rounded-md hover:bg-blue-700 transition-colors">
            创建第一个账本
          </button>
        </div>
      </div>

      <!-- 底部操作栏 -->
      <div class="flex justify-between items-center p-6 border-t border-gray-200 bg-gray-50">
        <div class="text-sm text-gray-600">
          <span v-if="currentLedgerId">
            当前使用: <strong>{{ currentLedger?.name }}</strong>
          </span>
          <span v-else class="text-amber-600">
            ! 请选择一个账本
          </span>
        </div>
        <div class="flex gap-3">
          <button @click="$emit('close')"
            class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50 transition-colors">
            关闭
          </button>
          <button v-if="currentLedgerId && currentLedgerId !== props.currentLedgerId" @click="confirmSelection"
            class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors">
            确认选择
          </button>
        </div>
      </div>
    </div>

    <!-- 创建/编辑表单模态框 -->
    <LedgerFormModal v-if="showCreateForm || editingLedger" :ledger="editingLedger" @close="closeForm"
      @save="handleSave" />
  </div>
</template>

<script setup lang="ts">
import {
  Calendar,
  CreditCard,
  Edit,
  HandCoins,
  Plus,
  Trash2,
  Users,
  X,
} from 'lucide-vue-next';
import { computed, ref } from 'vue';
import { FamilyLedger } from '@/schema/money';
import { toast } from '@/utils/toast';
import LedgerFormModal from './LedgerFormModal.vue'; // 需要创建这个组件

interface Props {
  ledgers: FamilyLedger[];
  currentLedgerId?: string;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  close: [];
  ledgerSelected: [ledgerId: string];
  ledgersUpdated: [];
}>();

const showCreateForm = ref(false);
const editingLedger = ref<FamilyLedger | null>(null);
const selectedLedgerId = ref(props.currentLedgerId || '');

const currentLedger = computed(() =>
  props.ledgers.find((ledger) => ledger.serialNum === props.currentLedgerId),
);

const selectLedger = (ledgerId: string) => {
  selectedLedgerId.value = ledgerId;
  // 立即选择账本
  emit('ledgerSelected', ledgerId);
};

const confirmSelection = () => {
  if (selectedLedgerId.value) {
    emit('ledgerSelected', selectedLedgerId.value);
  }
};

const editLedger = (ledger: FamilyLedger) => {
  editingLedger.value = { ...ledger }; // 深拷贝避免直接修改
};

const deleteLedger = async (ledger: FamilyLedger) => {
  // 不能删除当前正在使用的账本
  if (props.currentLedgerId === ledger.serialNum) {
    toast.warning('不能删除当前正在使用的账本');
    return;
  }

  const confirmMessage = `确定删除账本"${ledger.name}"吗？\n\n! 此操作将永久删除该账本下的所有数据，包括：\n• 所有账户信息\n• 所有交易记录\n• 所有预算设置\n• 所有提醒设置\n\n此操作不可恢复！`;

  if (confirm(confirmMessage)) {
    try {
      // TODO: 调用删除 API
      // await familyLedgerStore.deleteLedger(ledger.serialNum);
      console.log('删除账本:', ledger.serialNum);
      toast.success('账本删除成功');
      emit('ledgersUpdated');
    } catch (error) {
      toast.error('删除账本失败');
    }
  }
};

const closeForm = () => {
  showCreateForm.value = false;
  editingLedger.value = null;
};

const handleSave = (savedLedger: FamilyLedger) => {
  closeForm();
  emit('ledgersUpdated');

  if (editingLedger.value) {
    toast.success('账本更新成功');
  } else {
    toast.success('账本创建成功');
    // 如果是新创建的账本，自动选择它
    emit('ledgerSelected', savedLedger.serialNum);
  }
};

const formatDate = (dateString?: string) => {
  if (!dateString) return '未知';
  try {
    return new Date(dateString).toLocaleDateString('zh-CN');
  } catch {
    return '未知';
  }
};
</script>

<style scoped>
/* 自定义滚动条样式 */
.overflow-y-auto::-webkit-scrollbar {
  width: 6px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 3px;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 3px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: #a1a1a1;
}
</style>
