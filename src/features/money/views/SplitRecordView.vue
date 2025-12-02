<script setup lang="ts">
import {
  LucideCalendar,
  LucideCheck,
  LucideClock,
  LucideDownload,
  LucideFilter,
  LucideSearch,
  LucideUsers,
} from 'lucide-vue-next';
import Button from '@/components/ui/Button.vue';
import type { SplitRecord } from '@/schema/money';

// 搜索和筛选
const searchKeyword = ref('');
const filterStatus = ref<'all' | 'pending' | 'completed'>('all');
const filterMember = ref<string>('');
const dateRange = ref<{ start: string; end: string }>({
  start: '',
  end: '',
});

// 显示筛选器
const showFilters = ref(false);

// 加载状态
const loading = ref(true);

// 分摊记录列表
const splitRecords = ref<SplitRecord[]>([]);

// 加载分摊记录
onMounted(async () => {
  await loadSplitRecords();
});

async function loadSplitRecords() {
  loading.value = true;
  try {
    // TODO: 调用 API 获取分摊记录
    // const records = await splitStore.fetchSplitRecords();
    // splitRecords.value = records;

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

  // 按关键词搜索
  if (searchKeyword.value) {
    const keyword = searchKeyword.value.toLowerCase();
    result = result.filter(record =>
      record.serialNum.toLowerCase().includes(keyword),
    );
  }

  // 按状态筛选
  if (filterStatus.value !== 'all') {
    result = result.filter(record => {
      const allPaid = record.splitDetails.every(d => d.isPaid);
      return filterStatus.value === 'completed' ? allPaid : !allPaid;
    });
  }

  // 按成员筛选
  if (filterMember.value) {
    result = result.filter(record =>
      record.splitDetails.some(d => d.memberSerialNum === filterMember.value),
    );
  }

  // 按日期范围筛选
  if (dateRange.value.start && dateRange.value.end) {
    result = result.filter(record => {
      const recordDate = new Date(record.createdAt);
      const startDate = new Date(dateRange.value.start);
      const endDate = new Date(dateRange.value.end);
      return recordDate >= startDate && recordDate <= endDate;
    });
  }

  return result;
});

// 统计信息
const statistics = computed(() => {
  const total = filteredRecords.value.length;
  const completed = filteredRecords.value.filter(r =>
    r.splitDetails.every(d => d.isPaid),
  ).length;
  const pending = total - completed;
  const totalAmount = filteredRecords.value.reduce((sum, r) => sum + r.totalAmount, 0);

  return {
    total,
    completed,
    pending,
    totalAmount,
  };
});

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 格式化日期
function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

// 获取记录状态
function getRecordStatus(record: SplitRecord): 'completed' | 'pending' {
  return record.splitDetails.every(d => d.isPaid) ? 'completed' : 'pending';
}

// 导出数据
function exportData() {
  // TODO: 实现导出功能
  // eslint-disable-next-line no-console
  console.log('Exporting data...');
}

// 查看详情
function viewDetail(record: SplitRecord) {
  // TODO: 打开详情弹窗
  // eslint-disable-next-line no-console
  console.log('View detail:', record);
}

// 重置筛选
function resetFilters() {
  searchKeyword.value = '';
  filterStatus.value = 'all';
  filterMember.value = '';
  dateRange.value = { start: '', end: '' };
}
</script>

<template>
  <div class="flex flex-col gap-6 p-8 max-w-7xl mx-auto">
    <!-- 页面头部 -->
    <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
      <div>
        <h1 class="text-3xl font-semibold text-gray-900 dark:text-gray-100 mb-2">
          分摊记录
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          查看和管理所有费用分摊记录
        </p>
      </div>

      <Button variant="primary" @click="exportData">
        <LucideDownload class="w-4 h-4" />
        导出数据
      </Button>
    </div>

    <!-- 统计卡片 -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
      <div class="flex items-center gap-4 p-6 bg-white dark:bg-gray-800 border-2 border-gray-300 dark:border-gray-700 rounded-xl shadow-sm">
        <LucideUsers class="w-8 h-8 text-gray-700 dark:text-gray-300 flex-shrink-0" />
        <div class="flex flex-col gap-1">
          <label class="text-sm text-gray-600 dark:text-gray-400">总记录数</label>
          <strong class="text-2xl font-semibold text-gray-900 dark:text-gray-100">{{ statistics.total }}</strong>
        </div>
      </div>

      <div class="flex items-center gap-4 p-6 bg-green-100 dark:bg-green-900/30 border-2 border-green-600 dark:border-green-700 rounded-xl shadow-sm">
        <LucideCheck class="w-8 h-8 text-green-600 dark:text-green-400 flex-shrink-0" />
        <div class="flex flex-col gap-1">
          <label class="text-sm text-gray-600 dark:text-gray-400">已完成</label>
          <strong class="text-2xl font-semibold text-gray-900 dark:text-gray-100">{{ statistics.completed }}</strong>
        </div>
      </div>

      <div class="flex items-center gap-4 p-6 bg-yellow-100 dark:bg-yellow-900/30 border-2 border-yellow-500 dark:border-yellow-700 rounded-xl shadow-sm">
        <LucideClock class="w-8 h-8 text-yellow-600 dark:text-yellow-400 flex-shrink-0" />
        <div class="flex flex-col gap-1">
          <label class="text-sm text-gray-600 dark:text-gray-400">进行中</label>
          <strong class="text-2xl font-semibold text-gray-900 dark:text-gray-100">{{ statistics.pending }}</strong>
        </div>
      </div>

      <div class="flex items-center gap-4 p-6 bg-blue-100 dark:bg-blue-900/30 border-2 border-blue-600 dark:border-blue-700 rounded-xl shadow-sm">
        <LucideCalendar class="w-8 h-8 text-blue-600 dark:text-blue-400 flex-shrink-0" />
        <div class="flex flex-col gap-1">
          <label class="text-sm text-gray-600 dark:text-gray-400">总金额</label>
          <strong class="text-2xl font-semibold text-gray-900 dark:text-gray-100">{{ formatAmount(statistics.totalAmount) }}</strong>
        </div>
      </div>
    </div>

    <!-- 搜索和筛选栏 -->
    <div class="flex flex-col sm:flex-row gap-4 items-center">
      <div class="flex-1 relative w-full">
        <LucideSearch class="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          v-model="searchKeyword"
          type="text"
          placeholder="搜索分摊记录..."
          class="w-full pl-12 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-2 focus:outline-blue-600 focus:outline-offset-2 focus:border-transparent"
        >
      </div>

      <button
        class="relative flex items-center gap-2 px-6 py-3 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg text-sm transition-all" :class="[
          showFilters ? 'bg-gray-100 dark:bg-gray-700 border-blue-600 dark:border-blue-500' : 'hover:bg-gray-100 dark:hover:bg-gray-700',
        ]"
        @click="showFilters = !showFilters"
      >
        <LucideFilter class="w-4 h-4" />
        筛选
        <span v-if="filterStatus !== 'all' || filterMember" class="absolute -top-2 -right-2 w-5 h-5 bg-blue-600 text-white rounded-full text-xs flex items-center justify-center">
          {{ (filterStatus !== 'all' ? 1 : 0) + (filterMember ? 1 : 0) }}
        </span>
      </button>
    </div>

    <!-- 筛选面板 -->
    <div v-if="showFilters" class="flex flex-col sm:flex-row gap-4 p-6 bg-white dark:bg-gray-800 rounded-xl border border-gray-300 dark:border-gray-700">
      <div class="flex-1 flex flex-col gap-2">
        <label class="text-sm font-medium text-gray-700 dark:text-gray-300">状态</label>
        <select v-model="filterStatus" class="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100">
          <option value="all">
            全部
          </option>
          <option value="pending">
            进行中
          </option>
          <option value="completed">
            已完成
          </option>
        </select>
      </div>

      <div class="flex-1 flex flex-col gap-2">
        <label class="text-sm font-medium text-gray-700 dark:text-gray-300">日期范围</label>
        <div class="flex items-center gap-2">
          <input
            v-model="dateRange.start"
            type="date"
            class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
          <span class="text-gray-600 dark:text-gray-400">至</span>
          <input
            v-model="dateRange.end"
            type="date"
            class="flex-1 px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md text-sm bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100"
          >
        </div>
      </div>

      <div class="flex items-end">
        <button class="px-4 py-2 bg-transparent border border-gray-300 dark:border-gray-600 rounded-md text-sm transition-colors hover:bg-gray-100 dark:hover:bg-gray-700" @click="resetFilters">
          重置
        </button>
      </div>
    </div>

    <!-- 记录列表 -->
    <div v-if="loading" class="flex flex-col items-center gap-4 py-12">
      <div class="w-8 h-8 border-3 border-gray-300 dark:border-gray-600 border-t-blue-600 rounded-full animate-spin" />
      <span class="text-gray-600 dark:text-gray-400">加载中...</span>
    </div>

    <div v-else-if="filteredRecords.length > 0" class="flex flex-col gap-4">
      <div
        v-for="record in filteredRecords"
        :key="record.serialNum"
        class="p-6 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-700 rounded-xl cursor-pointer transition-all hover:shadow-md hover:-translate-y-0.5"
        @click="viewDetail(record)"
      >
        <div class="flex justify-between items-center mb-4">
          <div class="flex flex-col gap-1">
            <h3 class="text-base font-semibold text-gray-900 dark:text-gray-100">
              分摊记录
            </h3>
            <span class="text-xs text-gray-500 dark:text-gray-400">{{ formatDate(record.createdAt) }}</span>
          </div>
          <div
            class="flex items-center gap-2 px-4 py-2 rounded-full text-xs font-medium" :class="[
              getRecordStatus(record) === 'completed'
                ? 'bg-green-100 dark:bg-green-900/30 text-green-800 dark:text-green-300'
                : 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-800 dark:text-yellow-300',
            ]"
          >
            <component
              :is="getRecordStatus(record) === 'completed' ? LucideCheck : LucideClock"
              class="w-3.5 h-3.5"
            />
            <span>{{ getRecordStatus(record) === 'completed' ? '已完成' : '进行中' }}</span>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <label class="block mb-2 text-xs text-gray-600 dark:text-gray-400">总金额</label>
            <strong class="text-xl font-semibold text-blue-600 dark:text-blue-400">{{ formatAmount(record.totalAmount) }}</strong>
          </div>

          <div>
            <label class="block mb-2 text-xs text-gray-600 dark:text-gray-400">参与成员</label>
            <div class="flex items-center">
              <div
                v-for="(detail, index) in record.splitDetails.slice(0, 3)"
                :key="detail.memberSerialNum"
                class="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-sm font-semibold border-2 border-white dark:border-gray-800 -ml-2 first:ml-0"
                :style="{ zIndex: 10 - index }"
              >
                {{ detail.memberSerialNum.charAt(0) }}
              </div>
              <div v-if="record.splitDetails.length > 3" class="w-8 h-8 rounded-full bg-gray-300 dark:bg-gray-600 text-gray-700 dark:text-gray-300 flex items-center justify-center text-xs font-semibold border-2 border-white dark:border-gray-800 -ml-2">
                +{{ record.splitDetails.length - 3 }}
              </div>
            </div>
          </div>

          <div>
            <label class="block mb-2 text-xs text-gray-600 dark:text-gray-400">支付进度</label>
            <div class="h-2 bg-gray-300 dark:bg-gray-600 rounded-full overflow-hidden mb-2">
              <div
                class="h-full bg-gradient-to-r from-blue-600 to-green-500 rounded-full transition-all"
                :style="{
                  width: `${(record.splitDetails.filter(d => d.isPaid).length / record.splitDetails.length) * 100}%`,
                }"
              />
            </div>
            <span class="text-xs text-gray-600 dark:text-gray-400">
              {{ record.splitDetails.filter(d => d.isPaid).length }} / {{ record.splitDetails.length }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <div v-else class="flex flex-col items-center gap-4 py-16 text-center">
      <LucideUsers class="w-16 h-16 text-gray-300 dark:text-gray-600" />
      <p class="text-lg text-gray-600 dark:text-gray-400">
        暂无分摊记录
      </p>
      <span class="text-sm text-gray-400 dark:text-gray-500">创建交易并启用分摊后，记录将显示在这里</span>
    </div>
  </div>
</template>
