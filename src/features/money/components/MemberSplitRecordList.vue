<script setup lang="ts">
import { LucideCheck, LucideClock, LucideFilter, LucideX } from 'lucide-vue-next';
import { Card, Spinner } from '@/components/ui';
import type { SplitRecord } from '@/schema/money';

interface Props {
  memberSerialNum: string;
}

const props = defineProps<Props>();

const splitRecords = ref<SplitRecord[]>([]);
const loading = ref(true);
const filterStatus = ref<'all' | 'Pending' | 'Confirmed' | 'Settled'>('all');

// 加载分摊记录
onMounted(async () => {
  await loadSplitRecords();
});

async function loadSplitRecords() {
  loading.value = true;
  try {
    // TODO: 替换为实际API调用
    // await splitStore.fetchSplitRecords({ memberSerialNum: props.memberSerialNum });
    // splitRecords.value = splitStore.currentLedgerSplitRecords;

    // 临时模拟数据
    splitRecords.value = [];
  } catch (error) {
    console.error('Failed to load split records:', error);
  } finally {
    loading.value = false;
  }
}

// 筛选后的记录
const filteredRecords = computed(() => {
  let result = splitRecords.value;

  if (filterStatus.value !== 'all') {
    result = result.filter(record =>
      record.splitDetails.some(detail =>
        detail.memberSerialNum === props.memberSerialNum &&
        (detail.isPaid ? 'Settled' : 'Pending') === filterStatus.value,
      ),
    );
  }

  return result;
});

// 格式化日期
function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    month: '2-digit',
    day: '2-digit',
  });
}

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 获取该成员的分摊详情
function getMemberSplitDetail(record: SplitRecord) {
  return record.splitDetails.find(detail => detail.memberSerialNum === props.memberSerialNum);
}
</script>

<template>
  <div class="flex flex-col gap-4">
    <!-- 工具栏 -->
    <div class="flex justify-end">
      <div class="flex items-center gap-2">
        <LucideFilter :size="18" class="text-gray-500 dark:text-gray-400" />
        <select
          v-model="filterStatus"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm cursor-pointer transition-all bg-white dark:bg-gray-800 text-gray-900 dark:text-white hover:border-blue-500 dark:hover:border-blue-600 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:focus:ring-blue-600"
        >
          <option value="all">
            全部状态
          </option>
          <option value="Pending">
            待支付
          </option>
          <option value="Confirmed">
            已确认
          </option>
          <option value="Settled">
            已结算
          </option>
        </select>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="flex flex-col items-center gap-2 py-12 text-gray-500 dark:text-gray-400">
      <Spinner size="lg" />
      <span>加载中...</span>
    </div>

    <!-- 分摊记录列表 -->
    <div v-else-if="filteredRecords.length > 0" class="flex flex-col gap-4">
      <Card
        v-for="record in filteredRecords"
        :key="record.serialNum"
        padding="lg"
        hoverable
        class="transition-all hover:-translate-y-0.5"
      >
        <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-3 mb-4 pb-3 border-b border-gray-200 dark:border-gray-700">
          <div class="flex items-center gap-3">
            <h4 class="text-base font-semibold text-gray-900 dark:text-white">
              交易分摊
            </h4>
            <span class="text-sm text-gray-500 dark:text-gray-400">{{ formatDate(record.createdAt || '') }}</span>
          </div>
          <div v-if="getMemberSplitDetail(record)" class="flex items-center gap-2">
            <component
              :is="getMemberSplitDetail(record)!.isPaid ? LucideCheck : LucideClock"
              :size="16"
            />
            <span
              class="text-sm font-medium px-3 py-1 rounded-xl" :class="[
                getMemberSplitDetail(record)!.isPaid
                  ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                  : 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300',
              ]"
            >
              {{ getMemberSplitDetail(record)!.isPaid ? '已支付' : '待支付' }}
            </span>
          </div>
        </div>

        <div class="flex flex-col gap-3">
          <div class="flex justify-between items-center text-sm">
            <span class="text-gray-600 dark:text-gray-400">分摊总额:</span>
            <span class="text-gray-900 dark:text-white">{{ formatAmount(record.totalAmount) }}</span>
          </div>

          <div v-if="getMemberSplitDetail(record)" class="flex justify-between items-center text-sm p-3 bg-gray-50 dark:bg-gray-900/50 rounded-lg font-medium">
            <span class="text-gray-600 dark:text-gray-400">我的分摊:</span>
            <span class="text-lg font-semibold text-blue-600 dark:text-blue-400">
              {{ formatAmount(getMemberSplitDetail(record)!.amount) }}
            </span>
          </div>

          <div class="flex justify-between items-center text-sm">
            <span class="text-gray-600 dark:text-gray-400">分摊方式:</span>
            <span class="text-gray-900 dark:text-white">均摊</span>
          </div>

          <div class="flex justify-between items-center text-sm">
            <span class="text-gray-600 dark:text-gray-400">参与人数:</span>
            <span class="text-gray-900 dark:text-white">{{ record.splitDetails.length }} 人</span>
          </div>
        </div>

        <div v-if="getMemberSplitDetail(record)?.isPaid" class="flex items-center gap-2 mt-4 p-3 bg-green-100 dark:bg-green-900/30 rounded-lg text-green-800 dark:text-green-300 text-sm font-medium">
          <LucideCheck :size="16" />
          <span>已支付</span>
        </div>
      </Card>
    </div>

    <!-- 空状态 -->
    <div v-else class="flex flex-col items-center gap-3 py-12 text-center">
      <LucideX :size="48" class="text-gray-300 dark:text-gray-600" />
      <p class="text-base text-gray-600 dark:text-gray-400">
        暂无分摊记录
      </p>
      <span class="text-sm text-gray-400 dark:text-gray-500">参与家庭账本的分摊后，记录将显示在这里</span>
    </div>

    <!-- 统计信息 -->
    <Card v-if="!loading && filteredRecords.length > 0" padding="md" class="bg-gray-50 dark:bg-gray-900/50">
      <div class="flex flex-col sm:flex-row gap-4 sm:gap-8">
        <div class="flex flex-col gap-1">
          <label class="text-sm text-gray-500 dark:text-gray-400">总记录数</label>
          <strong class="text-xl font-semibold text-gray-900 dark:text-white">{{ filteredRecords.length }}</strong>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-sm text-gray-500 dark:text-gray-400">总分摊金额</label>
          <strong class="text-xl font-semibold text-blue-600 dark:text-blue-400">
            {{ formatAmount(filteredRecords.reduce((sum, r) => {
              const detail = getMemberSplitDetail(r);
              return sum + (detail?.amount || 0);
            }, 0)) }}
          </strong>
        </div>
      </div>
    </Card>
  </div>
</template>
