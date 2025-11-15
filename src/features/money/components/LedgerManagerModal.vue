<script setup lang="ts">
import { computed, ref } from 'vue';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import LedgerFormModal from './LedgerFormModal.vue';
import type { FamilyLedger } from '@/schema/money';

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
const showConfirmModal = ref(false);
const deleteLedger = ref();

const currentLedger = computed(() =>
  props.ledgers.find(ledger => ledger.serialNum === props.currentLedgerId),
);

function selectLedger(ledgerId: string) {
  selectedLedgerId.value = ledgerId;
  // 立即选择账本
  emit('ledgerSelected', ledgerId);
}

function confirmSelection() {
  if (selectedLedgerId.value) {
    emit('ledgerSelected', selectedLedgerId.value);
  }
}

function editLedger(ledger: FamilyLedger) {
  editingLedger.value = { ...ledger }; // 深拷贝避免直接修改
}

function handleDeleteLedger(ledger: FamilyLedger) {
  // 不能删除当前正在使用的账本
  if (props.currentLedgerId === ledger.serialNum) {
    toast.warning('不能删除当前正在使用的账本');
    return;
  }
  deleteLedger.value = ledger;
  showConfirmModal.value = true;
  // const confirmMessage = `确定删除账本"${ledger.name}"吗？\n\n! 此操作将永久删除该账本下的所有数据，包括：\n• 所有账户信息\n• 所有交易记录\n• 所有预算设置\n• 所有提醒设置\n\n此操作不可恢复！`;
}

function closeForm() {
  showCreateForm.value = false;
  editingLedger.value = null;
}

function handleSave(savedLedger: FamilyLedger) {
  closeForm();
  emit('ledgersUpdated');

  if (editingLedger.value) {
    toast.success('账本更新成功');
  } else {
    toast.success('账本创建成功');
    // 如果是新创建的账本，自动选择它
    emit('ledgerSelected', savedLedger.serialNum);
  }
}

async function handleConfirmClose() {
  try {
    // TODO: 调用删除 API
    // await familyLedgerStore.deleteLedger(deleteLedger.serialNum);
    toast.success('账本删除成功');
    showConfirmModal.value = false;
    emit('ledgersUpdated');
  } catch (error) {
    Lg.e('LedgerManagerModal', error);
    toast.error('删除账本失败');
  }
  emit('close');
}

function handleCancelClose() {
  showConfirmModal.value = false;
}

function formatDate(dateString?: string) {
  if (!dateString)
    return '未知';
  try {
    return new Date(dateString).toLocaleDateString('zh-CN');
  } catch {
    return '未知';
  }
}
</script>

<template>
  <div class="bg-black bg-opacity-50 flex items-center inset-0 justify-center fixed z-50" @click.self="$emit('close')">
    <div class="rounded-lg bg-white max-h-[90vh] max-w-4xl w-full shadow-2xl overflow-hidden">
      <!-- 头部 -->
      <div class="p-6 border-b border-gray-200 bg-gray-50 flex items-center justify-between">
        <h2 class="text-xl text-gray-800 font-bold">
          家庭账本管理
        </h2>
        <button class="text-gray-400 transition-colors hover:text-gray-600" @click="$emit('close')">
          <LucideX class="h-6 w-6" />
        </button>
      </div>

      <!-- 内容 -->
      <div class="p-6 max-h-[calc(90vh-120px)] overflow-y-auto">
        <!-- 操作栏 -->
        <div class="mb-6 flex items-center justify-between">
          <div class="text-sm text-gray-600">
            共 {{ ledgers.length }} 个账本
          </div>
          <button
            class="text-white px-4 py-2 rounded-md bg-blue-600 flex gap-2 transition-colors items-center hover:bg-blue-700"
            @click="showCreateForm = true"
          >
            <LucidePlus class="h-4 w-4" />
            创建新账本
          </button>
        </div>

        <!-- 账本列表 -->
        <div v-if="ledgers.length > 0" class="gap-4 grid">
          <div
            v-for="ledger in ledgers" :key="ledger.serialNum" class="p-4 border rounded-lg cursor-pointer transition-all hover:shadow-md" :class="[
              currentLedgerId === ledger.serialNum
                ? 'border-blue-500 bg-blue-50 shadow-md'
                : 'border-gray-200 hover:border-gray-300',
            ]" @click="selectLedger(ledger.serialNum)"
          >
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <div class="mb-2 flex gap-3 items-center">
                  <h3 class="text-lg text-gray-900 font-semibold">
                    {{ ledger.name }}
                  </h3>
                  <span
                    v-if="currentLedgerId === ledger.serialNum"
                    class="text-xs text-blue-800 font-medium px-2 py-1 rounded-full bg-blue-100"
                  >
                    当前使用
                  </span>
                </div>

                <p class="text-sm text-gray-600 mb-3">
                  {{ ledger.description || '暂无描述' }}
                </p>

                <div class="text-xs text-gray-500 flex gap-6 items-center">
                  <div class="flex gap-1 items-center">
                    <LucideCreditCard class="h-3 w-3" />
                    <span>货币: {{ ledger.baseCurrency?.symbol || '¥' }} {{ ledger.baseCurrency?.code || 'CNY' }}</span>
                  </div>
                  <div class="flex gap-1 items-center">
                    <LucideUsers class="h-3 w-3" />
                    <span>成员: {{ ledger.members || 0 }}人</span>
                  </div>
                  <div class="flex gap-1 items-center">
                    <LucideCalendar class="h-3 w-3" />
                    <span>创建: {{ formatDate(ledger.createdAt) }}</span>
                  </div>
                </div>
              </div>

              <div class="ml-4 flex gap-2">
                <button
                  class="text-gray-400 p-2 rounded-md transition-colors hover:text-blue-600 hover:bg-blue-50"
                  title="编辑账本"
                  @click.stop="editLedger(ledger)"
                >
                  <LucideEdit class="h-4 w-4" />
                </button>
                <button
                  class="text-gray-400 p-2 rounded-md transition-colors hover:text-red-600 hover:bg-red-50"
                  title="删除账本" :disabled="currentLedgerId === ledger.serialNum"
                  @click.stop="handleDeleteLedger(ledger)"
                >
                  <LucideTrash2 class="h-4 w-4" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 空状态 -->
        <div v-else class="py-16 text-center">
          <LucideHandCoins class="text-gray-300 mx-auto mb-6 h-20 w-20" />
          <h3 class="text-xl text-gray-900 font-medium mb-3">
            还没有账本
          </h3>
          <p class="text-gray-500 mx-auto mb-8 max-w-md">
            创建您的第一个家庭账本，开始管理家庭财务。每个账本可以有不同的成员和货币设置。
          </p>
          <button
            class="text-white px-6 py-3 rounded-md bg-blue-600 transition-colors hover:bg-blue-700"
            @click="showCreateForm = true"
          >
            创建第一个账本
          </button>
        </div>
      </div>

      <!-- 底部操作栏 -->
      <div class="p-6 border-t border-gray-200 bg-gray-50 flex items-center justify-between">
        <div class="text-sm text-gray-600">
          <span v-if="currentLedgerId">
            当前使用: <strong>{{ currentLedger?.name }}</strong>
          </span>
          <span v-else class="text-amber-600">
            ! 请选择一个账本
          </span>
        </div>
        <div class="flex gap-3">
          <button
            class="text-gray-700 px-4 py-2 border border-gray-300 rounded-md transition-colors hover:bg-gray-50"
            @click="$emit('close')"
          >
            关闭
          </button>
          <button
            v-if="currentLedgerId && currentLedgerId !== props.currentLedgerId" class="text-white px-4 py-2 rounded-md bg-blue-600 transition-colors hover:bg-blue-700"
            @click="confirmSelection"
          >
            确认选择
          </button>
        </div>
      </div>
    </div>

    <!-- 创建/编辑表单模态框 -->
    <LedgerFormModal
      v-if="showCreateForm || editingLedger" :ledger="editingLedger" @close="closeForm"
      @save="handleSave"
    />

    <ConfirmModal
      :visible="showConfirmModal"
      title="确认关闭"
      message="已经删除不可恢复"
      type="warning"
      confirm-text="确定关闭"
      cancel-text="继续编辑"
      confirm-button-type="warning"
      @confirm="handleConfirmClose"
      @cancel="handleCancelClose"
      @close="handleCancelClose"
    />
  </div>
</template>

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
