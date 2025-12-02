<script setup lang="ts">
import { Button, Modal } from '@/components/ui';
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
  <Modal
    :open="true"
    title="家庭账本管理"
    size="lg"
    :show-footer="false"
    @close="$emit('close')"
  >
    <div>
      <!-- 操作栏 -->
      <div class="mb-6 flex items-center justify-between">
        <div class="text-sm text-gray-600 dark:text-gray-400">
          共 {{ ledgers.length }} 个账本
        </div>
        <Button variant="primary" size="sm" @click="showCreateForm = true">
          <LucidePlus :size="16" />
          <span class="ml-2">创建新账本</span>
        </Button>
      </div>

      <!-- 账本列表 -->
      <div v-if="ledgers.length > 0" class="grid gap-4">
        <div
          v-for="ledger in ledgers" :key="ledger.serialNum"
          class="p-4 border rounded-lg cursor-pointer transition-all hover:shadow-md"
          :class="[
            currentLedgerId === ledger.serialNum
              ? 'border-blue-500 dark:border-blue-600 bg-blue-50 dark:bg-blue-900/20 shadow-md'
              : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600 bg-white dark:bg-gray-900/50',
          ]"
          @click="selectLedger(ledger.serialNum)"
        >
          <div class="flex flex-col sm:flex-row items-start justify-between gap-3">
            <div class="flex-1 min-w-0">
              <div class="mb-2 flex flex-wrap gap-2 items-center">
                <h3 class="text-lg text-gray-900 dark:text-white font-semibold">
                  {{ ledger.name }}
                </h3>
                <span
                  v-if="currentLedgerId === ledger.serialNum"
                  class="text-xs text-blue-800 dark:text-blue-200 font-medium px-2 py-1 rounded-full bg-blue-100 dark:bg-blue-900/50 whitespace-nowrap"
                >
                  当前使用
                </span>
              </div>

              <p class="text-sm text-gray-600 dark:text-gray-400 mb-3">
                {{ ledger.description || '暂无描述' }}
              </p>

              <div class="text-xs text-gray-500 dark:text-gray-500 flex flex-wrap gap-3 sm:gap-6 items-center">
                <div class="flex gap-1 items-center whitespace-nowrap">
                  <LucideCreditCard :size="12" />
                  <span>货币: {{ ledger.baseCurrency?.symbol || '¥' }} {{ ledger.baseCurrency?.code || 'CNY' }}</span>
                </div>
                <div class="flex gap-1 items-center whitespace-nowrap">
                  <LucideUsers :size="12" />
                  <span>成员: {{ ledger.members || 0 }}人</span>
                </div>
                <div class="flex gap-1 items-center whitespace-nowrap">
                  <LucideCalendar :size="12" />
                  <span>创建: {{ formatDate(ledger.createdAt) }}</span>
                </div>
              </div>
            </div>

            <div class="flex gap-2 shrink-0">
              <button
                class="text-gray-400 dark:text-gray-500 p-2 rounded-md transition-colors hover:text-blue-600 dark:hover:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20"
                title="编辑账本"
                @click.stop="editLedger(ledger)"
              >
                <LucideEdit :size="16" />
              </button>
              <button
                class="text-gray-400 dark:text-gray-500 p-2 rounded-md transition-colors hover:text-red-600 dark:hover:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 disabled:opacity-50 disabled:cursor-not-allowed"
                title="删除账本"
                :disabled="currentLedgerId === ledger.serialNum"
                @click.stop="handleDeleteLedger(ledger)"
              >
                <LucideTrash2 :size="16" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 空状态 -->
      <div v-else class="py-16 text-center">
        <LucideHandCoins :size="80" class="text-gray-300 dark:text-gray-600 mx-auto mb-6" />
        <h3 class="text-xl text-gray-900 dark:text-white font-medium mb-3">
          还没有账本
        </h3>
        <p class="text-gray-500 dark:text-gray-400 mx-auto mb-8 max-w-md">
          创建您的第一个家庭账本，开始管理家庭财务。每个账本可以有不同的成员和货币设置。
        </p>
        <Button variant="primary" @click="showCreateForm = true">
          创建第一个账本
        </Button>
      </div>
    </div>

    <!-- 底部操作栏 -->
    <div class="p-6 border-t border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/50 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
      <div class="text-sm text-gray-600 dark:text-gray-400">
        <span v-if="currentLedgerId">
          当前使用: <strong class="text-gray-900 dark:text-white">{{ currentLedger?.name }}</strong>
        </span>
        <span v-else class="text-amber-600 dark:text-amber-500">
          ! 请选择一个账本
        </span>
      </div>
      <div class="flex gap-3 w-full sm:w-auto">
        <Button variant="secondary" class="flex-1 sm:flex-initial" @click="$emit('close')">
          关闭
        </Button>
        <Button
          v-if="currentLedgerId && currentLedgerId !== props.currentLedgerId"
          variant="primary"
          class="flex-1 sm:flex-initial"
          @click="confirmSelection"
        >
          确认选择
        </Button>
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
  </Modal>
</template>
