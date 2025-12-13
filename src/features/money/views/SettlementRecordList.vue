<script setup lang="ts">
  import {
    CheckCircle2,
    Clock,
    DollarSign,
    Download,
    FileText,
    Inbox,
    Plus,
    Search,
  } from 'lucide-vue-next';
  import { useRouter } from 'vue-router';
  import Button from '@/components/ui/Button.vue';
  import type { SettlementRecord } from '@/services/money/settlement-record';
  import { settlementRecordService } from '@/services/money/settlement-record';
  import { toast } from '@/utils/toast';

  interface Statistics {
    totalCount: number;
    completedCount: number;
    pendingCount: number;
    totalAmount: number;
  }

  type SettlementStatus = 'pending' | 'completed' | 'cancelled' | 'all';
  type SettlementType = 'manual' | 'auto' | 'optimized' | 'all';

  interface Filters {
    status: SettlementStatus;
    type: SettlementType;
  }

  const router = useRouter();
  const records = ref<SettlementRecord[]>([]);
  const loading = ref(false);
  const searchQuery = ref('');

  // 当前账本
  const currentLedgerSerialNum = ref('FL001'); // TODO: 从store获取

  const filters = ref<Filters>({
    status: 'all',
    type: 'all',
  });

  const currentPage = ref(1);
  const pageSize = 10;

  const statistics = computed<Statistics>(() => ({
    totalCount: records.value.length,
    completedCount: records.value.filter(r => r.status === 'completed').length,
    pendingCount: records.value.filter(r => r.status === 'pending').length,
    totalAmount: records.value
      .filter(r => r.status === 'completed')
      .reduce((sum, r) => sum + r.totalAmount, 0),
  }));

  const filteredRecords = computed(() => {
    let result = [...records.value];
    if (filters.value.status !== 'all') {
      result = result.filter(r => r.status === filters.value.status);
    }
    if (filters.value.type !== 'all') {
      result = result.filter(r => r.settlementType === filters.value.type);
    }
    if (searchQuery.value) {
      const query = searchQuery.value.toLowerCase();
      result = result.filter(r => r.serialNum.toLowerCase().includes(query));
    }
    return result.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
  });

  const paginatedRecords = computed(() => {
    const start = (currentPage.value - 1) * pageSize;
    return filteredRecords.value.slice(start, start + pageSize);
  });

  const totalPages = computed(() => Math.ceil(filteredRecords.value.length / pageSize));

  async function loadData() {
    loading.value = true;
    try {
      const result = await settlementRecordService.listRecords({
        familyLedgerSerialNum: currentLedgerSerialNum.value,
        status: filters.value.status === 'all' ? undefined : filters.value.status,
        settlementType: filters.value.type === 'all' ? undefined : filters.value.type,
      });
      records.value = result.items || result.rows || [];
    } catch (error) {
      console.error('加载失败:', error);
      toast.error('加载失败');
    } finally {
      loading.value = false;
    }
  }

  function handleNewSettlement() {
    router.push('/money/settlement-suggestion');
  }

  function handleViewDetail(record: SettlementRecord) {
    // eslint-disable-next-line no-console
    console.log('查看详情:', record);
  }

  async function handleExport() {
    try {
      const result = await settlementRecordService.exportRecords(
        {
          familyLedgerSerialNum: currentLedgerSerialNum.value,
        },
        'excel',
      );
      // TODO: 处理下载文件
      // eslint-disable-next-line no-console
      console.log('Export result:', result);
      toast.success('导出成功');
    } catch (error) {
      console.error('导出失败:', error);
      toast.error('导出功能开发中...');
    }
  }

  function getTypeText(type: string): string {
    const map: Record<string, string> = {
      manual: '手动结算',
      auto: '自动结算',
      optimized: '优化结算',
    };
    return map[type] || type;
  }

  function getStatusText(status: string): string {
    const map: Record<string, string> = {
      pending: '待确认',
      completed: '已完成',
      cancelled: '已取消',
    };
    return map[status] || status;
  }

  function formatAmount(amount: number): string {
    return amount.toFixed(2);
  }

  function formatDate(dateString: string): string {
    const date = new Date(dateString);
    return `${date.getMonth() + 1}/${date.getDate()}`;
  }

  function formatTime(dateString: string): string {
    const date = new Date(dateString);
    const now = new Date();
    const days = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24));
    if (days === 0) return '今天';
    if (days === 1) return '昨天';
    if (days < 7) return `${days}天前`;
    return date.toLocaleDateString();
  }

  onMounted(() => {
    loadData();
  });
</script>

<template>
  <div class="p-6 flex flex-col gap-6">
    <!-- 页面标题 -->
    <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">结算记录</h1>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">查看和管理历史结算记录</p>
      </div>
      <div class="flex gap-3">
        <Button variant="secondary" @click="handleExport">
          <component :is="Download" class="w-4 h-4" />
          <span>导出</span>
        </Button>
        <Button variant="primary" @click="handleNewSettlement">
          <component :is="Plus" class="w-4 h-4" />
          <span>新建结算</span>
        </Button>
      </div>
    </div>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="bg-white dark:bg-gray-800 p-5 rounded-lg shadow-sm flex items-center gap-4">
        <div
          class="w-12 h-12 rounded-lg bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 flex items-center justify-center"
        >
          <component :is="FileText" class="w-6 h-6" />
        </div>
        <div>
          <div class="text-sm text-gray-600 dark:text-gray-400">总结算次数</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            {{ statistics.totalCount }}
          </div>
        </div>
      </div>

      <div class="bg-white dark:bg-gray-800 p-5 rounded-lg shadow-sm flex items-center gap-4">
        <div
          class="w-12 h-12 rounded-lg bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 flex items-center justify-center"
        >
          <component :is="CheckCircle2" class="w-6 h-6" />
        </div>
        <div>
          <div class="text-sm text-gray-600 dark:text-gray-400">已完成</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            {{ statistics.completedCount }}
          </div>
        </div>
      </div>

      <div class="bg-white dark:bg-gray-800 p-5 rounded-lg shadow-sm flex items-center gap-4">
        <div
          class="w-12 h-12 rounded-lg bg-yellow-100 dark:bg-yellow-900/30 text-yellow-600 dark:text-yellow-400 flex items-center justify-center"
        >
          <component :is="Clock" class="w-6 h-6" />
        </div>
        <div>
          <div class="text-sm text-gray-600 dark:text-gray-400">待确认</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            {{ statistics.pendingCount }}
          </div>
        </div>
      </div>

      <div class="bg-white dark:bg-gray-800 p-5 rounded-lg shadow-sm flex items-center gap-4">
        <div
          class="w-12 h-12 rounded-lg bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 flex items-center justify-center"
        >
          <component :is="DollarSign" class="w-6 h-6" />
        </div>
        <div>
          <div class="text-sm text-gray-600 dark:text-gray-400">累计结算金额</div>
          <div class="text-2xl font-bold text-gray-900 dark:text-gray-100 mt-1">
            ¥{{ formatAmount(statistics.totalAmount) }}
          </div>
        </div>
      </div>
    </div>

    <!-- 筛选栏 -->
    <div
      class="bg-white dark:bg-gray-800 p-4 rounded-lg shadow-sm flex flex-col sm:flex-row justify-between gap-4"
    >
      <div class="flex flex-col sm:flex-row gap-3">
        <select
          v-model="filters.status"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
        >
          <option value="all">全部状态</option>
          <option value="pending">待确认</option>
          <option value="completed">已完成</option>
          <option value="cancelled">已取消</option>
        </select>

        <select
          v-model="filters.type"
          class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
        >
          <option value="all">全部类型</option>
          <option value="manual">手动结算</option>
          <option value="auto">自动结算</option>
          <option value="optimized">优化结算</option>
        </select>
      </div>

      <div class="relative">
        <component
          :is="Search"
          class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400"
        />
        <input
          v-model="searchQuery"
          type="text"
          placeholder="搜索..."
          class="pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 w-full sm:w-64 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
        />
      </div>
    </div>

    <!-- 加载状态 -->
    <div
      v-if="loading"
      class="flex flex-col items-center justify-center py-20 bg-white dark:bg-gray-800 rounded-lg"
    >
      <div
        class="w-12 h-12 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"
      />
      <p class="mt-4 text-gray-600 dark:text-gray-400">加载中...</p>
    </div>

    <!-- 空状态 -->
    <div
      v-else-if="filteredRecords.length === 0"
      class="flex flex-col items-center justify-center py-20 bg-white dark:bg-gray-800 rounded-lg"
    >
      <component :is="Inbox" class="w-16 h-16 text-gray-400 dark:text-gray-600" />
      <p class="mt-4 text-lg font-medium text-gray-900 dark:text-gray-100">暂无结算记录</p>
      <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">创建第一笔结算记录吧</p>
    </div>

    <!-- 结算记录列表 -->
    <div v-else class="flex flex-col gap-4">
      <div
        v-for="record in paginatedRecords"
        :key="record.serialNum"
        class="bg-white dark:bg-gray-800 rounded-lg shadow-sm cursor-pointer transition-all hover:shadow-md hover:-translate-y-0.5"
        @click="handleViewDetail(record)"
      >
        <div
          class="px-6 py-4 flex justify-between items-center border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/50"
        >
          <div>
            <div class="font-semibold text-gray-900 dark:text-gray-100">
              {{ getTypeText(record.settlementType) }}
            </div>
            <div class="text-sm text-gray-600 dark:text-gray-400 mt-1">
              {{ formatDate(record.periodStart) }}~ {{ formatDate(record.periodEnd) }}
            </div>
          </div>
          <span
            class="px-3 py-1 rounded-full text-xs font-medium"
            :class="[
              record.status === 'pending' ? 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300'
              : record.status === 'completed' ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                : 'bg-red-100 dark:bg-red-900/30 text-red-800 dark:text-red-300',
            ]"
          >
            {{ getStatusText(record.status) }}
          </span>
        </div>

        <div class="px-6 py-4">
          <div class="flex gap-8">
            <div class="flex flex-col gap-1">
              <span class="text-xs text-gray-600 dark:text-gray-400">结算金额</span>
              <span class="text-lg font-semibold text-gray-900 dark:text-gray-100"
                >¥{{ formatAmount(record.totalAmount) }}</span
              >
            </div>
            <div class="flex flex-col gap-1">
              <span class="text-xs text-gray-600 dark:text-gray-400">参与成员</span>
              <span class="text-lg font-semibold text-gray-900 dark:text-gray-100"
                >{{ record.participantMembers.length }}人</span
              >
            </div>
          </div>
        </div>

        <div
          class="px-6 py-3 flex justify-between border-t border-gray-200 dark:border-gray-700 text-sm text-gray-600 dark:text-gray-400"
        >
          <span>发起人: {{ record.initiatedBy }}</span>
          <span>{{ formatTime(record.createdAt) }}</span>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="filteredRecords.length > pageSize" class="flex items-center justify-center gap-4">
      <button
        class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 cursor-pointer transition-colors hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="currentPage === 1"
        @click="currentPage--"
      >
        上一页
      </button>
      <span class="text-sm text-gray-600 dark:text-gray-400">
        第 {{ currentPage }}/ {{ totalPages }}页
      </span>
      <button
        class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 cursor-pointer transition-colors hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
        :disabled="currentPage === totalPages"
        @click="currentPage++"
      >
        下一页
      </button>
    </div>
  </div>
</template>
