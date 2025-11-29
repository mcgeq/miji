<script setup lang="ts">
import { ArrowRight, FileText, RefreshCw } from 'lucide-vue-next';
import Button from '@/components/ui/Button.vue';
import Modal from '@/components/ui/Modal.vue';
import Spinner from '@/components/ui/Spinner.vue';
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
  <div class="p-4">
    <!-- 头部 -->
    <div class="flex items-center justify-between mb-6">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white">
        结算记录
      </h3>
      <Button
        variant="secondary"
        size="sm"
        :icon="RefreshCw"
        @click="fetchSettlementRecords"
      >
        刷新
      </Button>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex items-center justify-center gap-2 p-8 text-gray-500 dark:text-gray-400">
      <Spinner size="sm" />
      <span>加载中...</span>
    </div>

    <!-- 空状态 -->
    <div v-else-if="settlementRecords.length === 0" class="flex flex-col items-center justify-center p-12 text-center">
      <FileText class="w-12 h-12 text-gray-400 dark:text-gray-600 mb-4" />
      <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
        暂无结算记录
      </h3>
      <p class="text-gray-500 dark:text-gray-400">
        还没有进行过结算操作
      </p>
    </div>

    <!-- 记录列表 -->
    <div v-else class="flex flex-col gap-4">
      <div
        v-for="record in settlementRecords"
        :key="record.serialNum"
        class="p-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg cursor-pointer transition-all hover:shadow-md hover:-translate-y-0.5"
        @click="viewDetails(record)"
      >
        <div class="flex items-center justify-between mb-2">
          <div class="font-semibold text-gray-900 dark:text-white">
            {{ formatDate(record.settlementDate) }}
          </div>
          <div class="font-semibold text-green-600 dark:text-green-500">
            ¥{{ formatAmount(record.totalSettlementAmount) }}
          </div>
        </div>

        <div class="text-sm text-gray-500 dark:text-gray-400 mb-1">
          结算周期: {{ formatDate(record.periodStart) }} - {{ formatDate(record.periodEnd) }}
        </div>

        <div class="text-sm text-gray-700 dark:text-gray-300">
          {{ record.settlements.length }} 笔转账
        </div>
      </div>
    </div>

    <!-- 详情模态框 -->
    <Modal
      v-if="selectedRecord"
      :open="true"
      title="结算详情"
      size="md"
      :show-footer="false"
      @close="closeDetails"
    >
      <div class="flex flex-col gap-6">
        <div>
          <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3">
            基本信息
          </h4>
          <div class="grid gap-3">
            <div class="flex justify-between items-center">
              <span class="text-sm text-gray-500 dark:text-gray-400">结算日期:</span>
              <span class="text-sm font-medium text-gray-900 dark:text-white">{{ formatDate(selectedRecord.settlementDate) }}</span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-sm text-gray-500 dark:text-gray-400">结算周期:</span>
              <span class="text-sm font-medium text-gray-900 dark:text-white">
                {{ formatDate(selectedRecord.periodStart) }} - {{ formatDate(selectedRecord.periodEnd) }}
              </span>
            </div>
            <div class="flex justify-between items-center">
              <span class="text-sm text-gray-500 dark:text-gray-400">总金额:</span>
              <span class="text-sm font-medium text-gray-900 dark:text-white">¥{{ formatAmount(selectedRecord.totalSettlementAmount) }}</span>
            </div>
          </div>
        </div>

        <div>
          <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3">
            转账明细
          </h4>
          <div class="flex flex-col gap-3">
            <div
              v-for="(settlement, index) in selectedRecord.settlements"
              :key="index"
              class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-900 rounded-lg"
            >
              <div class="flex items-center gap-2">
                <span class="text-red-600 dark:text-red-400 font-medium">{{ getMemberName(settlement.fromMemberSerialNum) }}</span>
                <ArrowRight class="w-4 h-4 text-gray-400 dark:text-gray-600" />
                <span class="text-green-600 dark:text-green-400 font-medium">{{ getMemberName(settlement.toMemberSerialNum) }}</span>
              </div>
              <div class="font-semibold text-gray-900 dark:text-white">
                ¥{{ formatAmount(settlement.amount) }}
              </div>
            </div>
          </div>
        </div>

        <div v-if="selectedRecord.notes">
          <h4 class="text-base font-semibold text-gray-900 dark:text-white mb-3">
            备注
          </h4>
          <p class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">
            {{ selectedRecord.notes }}
          </p>
        </div>
      </div>
    </Modal>
  </div>
</template>
