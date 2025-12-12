<script setup lang="ts">
  import { ArrowRight, ArrowRightLeft, DollarSign, Users } from 'lucide-vue-next';
  import { Modal } from '@/components/ui';
  import Badge from '@/components/ui/Badge.vue';

  // ==================== Props & Emits ====================

  interface TransferSuggestion {
    from: string;
    fromName: string;
    to: string;
    toName: string;
    amount: number;
    currency: string;
  }

  interface SettlementDetails {
    transferCount?: number;
    savingsCount?: number;
    notes?: string;
    [key: string]: unknown;
  }

  interface SettlementRecord {
    serialNum: string;
    familyLedgerSerialNum: string;
    settlementType: 'manual' | 'auto' | 'optimized';
    periodStart: string;
    periodEnd: string;
    totalAmount: number;
    currency: string;
    participantMembers: string[];
    settlementDetails?: SettlementDetails;
    optimizedTransfers?: TransferSuggestion[];
    status: 'pending' | 'completed' | 'cancelled';
    initiatedBy: string;
    completedBy?: string;
    completedAt?: string;
    createdAt: string;
  }

  interface Props {
    record: SettlementRecord;
  }

  const props = defineProps<Props>();

  const emit = defineEmits<{
    close: [];
  }>();

  // ==================== 计算属性 ====================

  const optimizedTransfers = computed<TransferSuggestion[]>(() => {
    if (Array.isArray(props.record.optimizedTransfers)) {
      return props.record.optimizedTransfers;
    }
    return [];
  });

  // ==================== 方法 ====================

  function handleClose() {
    emit('close');
  }

  function getTypeText(type: string): string {
    const typeMap: Record<string, string> = {
      manual: '手动结算',
      auto: '自动结算',
      optimized: '优化结算',
    };
    return typeMap[type] || type;
  }

  function getMemberColor(memberName: string): string {
    const colors = [
      '#3b82f6',
      '#ef4444',
      '#10b981',
      '#f59e0b',
      '#8b5cf6',
      '#ec4899',
      '#14b8a6',
      '#f97316',
    ];
    const index = memberName.charCodeAt(0) % colors.length;
    return colors[index];
  }

  function getInitials(name: string): string {
    return name.charAt(0).toUpperCase();
  }

  function formatAmount(amount: number): string {
    return amount.toFixed(2);
  }

  function formatDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('zh-CN');
  }

  function formatDateTime(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleString('zh-CN');
  }
</script>

<template>
  <Modal :open="true" title="结算详情" size="lg" :show-footer="false" @close="handleClose">
    <div class="flex flex-col gap-6">
      <!-- 基本信息 -->
      <div>
        <h3
          class="text-base font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2"
        >
          基本信息
        </h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">结算序号</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white"
              >{{ record.serialNum }}</span
            >
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">结算类型</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white"
              >{{ getTypeText(record.settlementType) }}</span
            >
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">结算周期</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white">
              {{ formatDate(record.periodStart) }}~ {{ formatDate(record.periodEnd) }}
            </span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">结算金额</span>
            <span class="text-xl font-bold text-blue-600 dark:text-blue-400"
              >¥{{ formatAmount(record.totalAmount) }}</span
            >
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">发起人</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white"
              >{{ record.initiatedBy }}</span
            >
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">发起时间</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white"
              >{{ formatDateTime(record.createdAt) }}</span
            >
          </div>
          <div v-if="record.completedAt" class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">完成时间</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white"
              >{{ formatDateTime(record.completedAt) }}</span
            >
          </div>
          <div v-if="record.completedBy" class="flex flex-col gap-1">
            <span class="text-xs text-gray-500 dark:text-gray-400">完成人</span>
            <span class="text-sm font-medium text-gray-900 dark:text-white"
              >{{ record.completedBy }}</span
            >
          </div>
        </div>
      </div>

      <!-- 参与成员 -->
      <div>
        <h3
          class="text-base font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2"
        >
          参与成员
          <Badge variant="primary" size="sm">{{ record.participantMembers.length }}人</Badge>
        </h3>
        <div class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
          <div
            v-for="(member, index) in record.participantMembers"
            :key="index"
            class="flex flex-col items-center gap-2 p-3 bg-gray-50 dark:bg-gray-900 rounded-lg"
          >
            <div
              class="w-12 h-12 rounded-full flex items-center justify-center text-white font-bold text-lg"
              :style="{ backgroundColor: getMemberColor(member) }"
            >
              {{ getInitials(member) }}
            </div>
            <span
              class="text-sm font-medium text-gray-900 dark:text-white truncate w-full text-center"
              >{{ member }}</span
            >
          </div>
        </div>
      </div>

      <!-- 转账明细 -->
      <div v-if="optimizedTransfers.length > 0">
        <h3
          class="text-base font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2"
        >
          转账明细
          <Badge variant="primary" size="sm">{{ optimizedTransfers.length }}笔</Badge>
        </h3>
        <div class="flex flex-col gap-3">
          <div
            v-for="(transfer, index) in optimizedTransfers"
            :key="index"
            class="flex items-center gap-3 p-4 bg-gray-50 dark:bg-gray-900 rounded-lg border border-gray-200 dark:border-gray-700"
          >
            <div
              class="w-8 h-8 rounded-full bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 flex items-center justify-center font-bold text-sm shrink-0"
            >
              {{ index + 1 }}
            </div>
            <div class="flex-1 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div class="flex items-center gap-3 flex-wrap">
                <div class="flex items-center gap-2 text-sm text-gray-900 dark:text-white">
                  <div
                    class="w-7 h-7 rounded-full flex items-center justify-center text-white font-bold text-xs shrink-0"
                    :style="{ backgroundColor: getMemberColor(transfer.fromName) }"
                  >
                    {{ getInitials(transfer.fromName) }}
                  </div>
                  <span class="font-medium">{{ transfer.fromName }}</span>
                </div>
                <ArrowRight class="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0" />
                <div class="flex items-center gap-2 text-sm text-gray-900 dark:text-white">
                  <div
                    class="w-7 h-7 rounded-full flex items-center justify-center text-white font-bold text-xs shrink-0"
                    :style="{ backgroundColor: getMemberColor(transfer.toName) }"
                  >
                    {{ getInitials(transfer.toName) }}
                  </div>
                  <span class="font-medium">{{ transfer.toName }}</span>
                </div>
              </div>
              <div class="text-base font-bold text-gray-900 dark:text-white shrink-0">
                ¥{{ formatAmount(transfer.amount) }}
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 统计信息 -->
      <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div class="p-4 bg-gray-50 dark:bg-gray-900 rounded-lg flex items-center gap-3">
          <div
            class="w-10 h-10 p-2 bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 rounded-lg shrink-0"
          >
            <Users class="w-full h-full" />
          </div>
          <div class="flex flex-col gap-0.5">
            <span class="text-xs text-gray-500 dark:text-gray-400">参与成员</span>
            <span class="text-lg font-bold text-gray-900 dark:text-white"
              >{{ record.participantMembers.length }}人</span
            >
          </div>
        </div>
        <div class="p-4 bg-gray-50 dark:bg-gray-900 rounded-lg flex items-center gap-3">
          <div
            class="w-10 h-10 p-2 bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 rounded-lg shrink-0"
          >
            <ArrowRightLeft class="w-full h-full" />
          </div>
          <div class="flex flex-col gap-0.5">
            <span class="text-xs text-gray-500 dark:text-gray-400">转账次数</span>
            <span class="text-lg font-bold text-gray-900 dark:text-white"
              >{{ optimizedTransfers.length }}笔</span
            >
          </div>
        </div>
        <div class="p-4 bg-gray-50 dark:bg-gray-900 rounded-lg flex items-center gap-3">
          <div
            class="w-10 h-10 p-2 bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 rounded-lg shrink-0"
          >
            <DollarSign class="w-full h-full" />
          </div>
          <div class="flex flex-col gap-0.5">
            <span class="text-xs text-gray-500 dark:text-gray-400">结算金额</span>
            <span class="text-lg font-bold text-gray-900 dark:text-white"
              >¥{{ formatAmount(record.totalAmount) }}</span
            >
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>
