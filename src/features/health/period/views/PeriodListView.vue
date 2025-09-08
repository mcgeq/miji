<script setup lang="ts">
import { ListFilterPlus, ListRestart } from 'lucide-vue-next';
import { usePeriodStore } from '@/stores/periodStore';
import type { PeriodRecords } from '@/schema/health/period';

// Emits
const emit = defineEmits<{
  addRecord: [];
  editRecord: [record: PeriodRecords];
  deleteRecord: [serialNum: string];
}>();

// Store
const periodStore = usePeriodStore();

// Reactive state
const searchQuery = ref('');
const sortBy = ref<'startDate' | 'duration' | 'cycleLength'>('startDate');
const sortOrder = ref<'asc' | 'desc'>('desc');
const showFilters = ref(false);
const currentPage = ref(1);
const pageSize = ref(10);

const filters = ref({
  startDate: '',
  endDate: '',
  minDuration: undefined as number | undefined,
  maxDuration: undefined as number | undefined,
  minCycle: undefined as number | undefined,
  maxCycle: undefined as number | undefined,
});

// Computed
const hasActiveFilters = computed(() => {
  return Object.values(filters.value).some(
    value => value !== '' && value !== undefined && value !== null,
  );
});

const filteredRecords = computed(() => {
  let records = [...periodStore.periodRecords];

  // 搜索过滤
  if (searchQuery.value) {
    const query = searchQuery.value.toLowerCase();
    records = records.filter(record => {
      const startDate = new Date(record.startDate).toLocaleDateString();
      const endDate = new Date(record.endDate).toLocaleDateString();
      return startDate.includes(query) || endDate.includes(query);
    });
  }

  // 高级筛选
  if (filters.value.startDate) {
    records = records.filter(
      record => record.startDate >= filters.value.startDate,
    );
  }
  if (filters.value.endDate) {
    records = records.filter(
      record => record.startDate <= filters.value.endDate,
    );
  }
  if (filters.value.minDuration) {
    records = records.filter(
      record => calculateDuration(record) >= filters.value.minDuration!,
    );
  }
  if (filters.value.maxDuration) {
    records = records.filter(
      record => calculateDuration(record) <= filters.value.maxDuration!,
    );
  }
  if (filters.value.minCycle) {
    records = records.filter(record => {
      const cycle = calculateCycleLength(record);
      return cycle === 0 || cycle >= filters.value.minCycle!;
    });
  }
  if (filters.value.maxCycle) {
    records = records.filter(record => {
      const cycle = calculateCycleLength(record);
      return cycle === 0 || cycle <= filters.value.maxCycle!;
    });
  }

  // 排序
  records.sort((a, b) => {
    let aValue: number, bValue: number;

    switch (sortBy.value) {
      case 'startDate':
        aValue = new Date(a.startDate).getTime();
        bValue = new Date(b.startDate).getTime();
        break;
      case 'duration':
        aValue = calculateDuration(a);
        bValue = calculateDuration(b);
        break;
      case 'cycleLength':
        aValue = calculateCycleLength(a);
        bValue = calculateCycleLength(b);
        break;
      default:
        return 0;
    }

    return sortOrder.value === 'asc' ? aValue - bValue : bValue - aValue;
  });

  return records;
});

const totalPages = computed(() =>
  Math.ceil(filteredRecords.value.length / pageSize.value),
);

const startIndex = computed(() => (currentPage.value - 1) * pageSize.value);
const endIndex = computed(() => startIndex.value + pageSize.value);

const paginatedRecords = computed(() => {
  return filteredRecords.value.slice(startIndex.value, endIndex.value);
});

const averageDuration = computed(() => {
  if (filteredRecords.value.length === 0)
    return 0;
  const total = filteredRecords.value.reduce(
    (sum, record) => sum + calculateDuration(record),
    0,
  );
  return total / filteredRecords.value.length;
});

const averageCycle = computed(() => {
  if (filteredRecords.value.length < 2)
    return 0;

  const cycles = filteredRecords.value
    .map(record => calculateCycleLength(record))
    .filter(cycle => cycle > 0);

  if (cycles.length === 0)
    return 0;

  const total = cycles.reduce((sum, cycle) => sum + cycle, 0);
  return total / cycles.length;
});

const regularity = computed(() => {
  if (filteredRecords.value.length < 3)
    return 0;

  const cycles = filteredRecords.value
    .map(record => calculateCycleLength(record))
    .filter(cycle => cycle > 0);

  if (cycles.length < 2)
    return 0;

  const average = cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length;
  const variance
    = cycles.reduce((sum, cycle) => sum + (cycle - average) ** 2, 0)
      / cycles.length;
  const standardDeviation = Math.sqrt(variance);

  return Math.max(0, Math.round(100 - standardDeviation * 5));
});

// Methods
function calculateDuration(record: PeriodRecords): number {
  const start = new Date(record.startDate);
  const end = new Date(record.endDate);
  return (
    Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1
  );
}

function calculateCycleLength(record: PeriodRecords): number {
  const allRecords = periodStore.periodRecords
    .slice()
    .sort(
      (a, b) =>
        new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

  const index = allRecords.findIndex(r => r.serialNum === record.serialNum);
  if (index <= 0)
    return 0;

  const current = new Date(record.startDate);
  const previous = new Date(allRecords[index - 1].startDate);

  return Math.ceil(
    (current.getTime() - previous.getTime()) / (1000 * 60 * 60 * 24),
  );
}

function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return `${date.getMonth() + 1}月${date.getDate()}日`;
}

function formatDateRange(startDate: string, endDate: string): string {
  const start = new Date(startDate);
  const end = new Date(endDate);

  if (start.getMonth() === end.getMonth()) {
    return `${start.getMonth() + 1}月${start.getDate()}-${end.getDate()}日`;
  } else {
    return `${start.getMonth() + 1}月${start.getDate()}日-${end.getMonth() + 1}月${end.getDate()}日`;
  }
}

function getRecordSymptoms(record: PeriodRecords): string[] {
  // 这里应该从相关的症状记录中获取
  // 暂时返回模拟数据
  if (record) {
    return [];
  }
  return [];
}

function clearFilters() {
  filters.value = {
    startDate: '',
    endDate: '',
    minDuration: undefined,
    maxDuration: undefined,
    minCycle: undefined,
    maxCycle: undefined,
  };
  searchQuery.value = '';
  currentPage.value = 1;
}

// Watchers
watch(
  [searchQuery, filters, sortBy, sortOrder],
  () => {
    currentPage.value = 1;
  },
  { deep: true },
);
</script>

<template>
  <div class="period-list-view">
    <!-- 过滤和搜索 -->
    <div class="filters-section mb-6 p-4 card-base">
      <div class="flex flex-col gap-4 items-start sm:flex-row sm:items-center">
        <div class="flex-1">
          <div class="relative">
            <i class="i-tabler-search text-gray-400 wh-4 transform left-3 top-1/2 absolute -translate-y-1/2" />
            <input v-model="searchQuery" type="text" placeholder="搜索记录..." class="input-base pl-10 w-full">
          </div>
        </div>
        <div class="flex flex-wrap gap-2">
          <select v-model="sortBy" class="select-base">
            <option value="startDate">
              按开始日期
            </option>
            <option value="duration">
              按持续时间
            </option>
            <option value="cycleLength">
              按周期长度
            </option>
          </select>
          <select v-model="sortOrder" class="select-base">
            <option value="desc">
              降序
            </option>
            <option value="asc">
              升序
            </option>
          </select>
          <button
            class="btn-secondary" :class="{ 'bg-blue-50 dark:bg-blue-900/30': hasActiveFilters }"
            @click="showFilters = !showFilters"
          >
            <ListFilterPlus class="ml-2 wh-5" />
          </button>
          <div v-if="showFilters">
            <button class="text-sm btn-secondary self-end" @click="clearFilters">
              <ListRestart class="ml-2 wh-5" />
            </button>
          </div>
        </div>
      </div>
      <!-- 高级筛选 -->
      <div v-if="showFilters" class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
        <div class="gap-4 grid grid-cols-1 sm:grid-cols-3">
          <!-- 第一组：日期范围 -->
          <div class="flex flex-col gap-2">
            <label class="filter-label">日期范围</label>
            <input v-model="filters.startDate" type="date" class="text-sm input-base w-full" placeholder="开始">
            <input v-model="filters.endDate" type="date" class="text-sm input-base w-full" placeholder="结束">
          </div>

          <!-- 第二组：持续时间 -->
          <div class="flex flex-col gap-2">
            <label class="filter-label">持续时间</label>
            <input
              v-model.number="filters.minDuration" type="number" class="text-sm input-base w-full" placeholder="最少天数"
              min="1"
            >
            <input
              v-model.number="filters.maxDuration" type="number" class="text-sm input-base w-full" placeholder="最多天数"
              min="1"
            >
          </div>

          <!-- 第三组：周期长度 + 按钮 -->
          <div class="flex flex-col gap-4 justify-between">
            <div class="flex flex-col gap-2">
              <label class="filter-label">周期长度</label>
              <input
                v-model.number="filters.minCycle" type="number" class="text-sm input-base w-full" placeholder="最短周期"
                min="1"
              >
              <input
                v-model.number="filters.maxCycle" type="number" class="text-sm input-base w-full" placeholder="最长周期"
                min="1"
              >
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 统计概览 -->
    <div class="stats-overview mb-2 gap-2 grid grid-cols-4">
      <div class="stat-card">
        <div class="stat-icon bg-red-100 dark:bg-red-900/30">
          <i class="i-tabler-calendar-heart text-red-600 wh-5 dark:text-red-400" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ filteredRecords.length }}
          </div>
          <div class="stat-label">
            总记录数
          </div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon bg-blue-100 dark:bg-blue-900/30">
          <i class="i-tabler-clock text-blue-600 wh-5 dark:text-blue-400" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ averageDuration.toFixed(1) }}
          </div>
          <div class="stat-label">
            平均持续天数
          </div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon bg-green-100 dark:bg-green-900/30">
          <i class="i-tabler-repeat text-green-600 wh-5 dark:text-green-400" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ averageCycle.toFixed(1) }}
          </div>
          <div class="stat-label">
            平均周期天数
          </div>
        </div>
      </div>
      <div class="stat-card">
        <div class="stat-icon bg-purple-100 dark:bg-purple-900/30">
          <i class="i-tabler-trending-up text-purple-600 wh-5 dark:text-purple-400" />
        </div>
        <div class="stat-content">
          <div class="stat-value">
            {{ regularity }}%
          </div>
          <div class="stat-label">
            规律性
          </div>
        </div>
      </div>
    </div>

    <!-- 记录列表 -->
    <div class="records-list">
      <div v-if="filteredRecords.length === 0" class="empty-state p-8 card-base">
        <i class="i-tabler-calendar-off wh-16 text-gray-400 mx-auto mb-4" />
        <h3 class="text-lg text-gray-900 font-medium mb-2 dark:text-white">
          {{ searchQuery || hasActiveFilters ? '未找到匹配的记录' : '还没有经期记录' }}
        </h3>
        <p class="text-gray-500 mb-4 dark:text-gray-400">
          {{ searchQuery || hasActiveFilters ? '试试调整搜索条件或筛选器' : '开始记录你的经期数据吧' }}
        </p>
        <button v-if="!searchQuery && !hasActiveFilters" class="btn-primary" @click="emit('addRecord')">
          <i class="i-tabler-plus mr-2 wh-4" />
          添加记录
        </button>
      </div>

      <div v-else class="space-y-4">
        <div
          v-for="record in paginatedRecords" :key="record.serialNum"
          class="record-card p-4 card-base cursor-pointer transition-shadow hover:shadow-md"
          @click="emit('editRecord', record)"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1">
              <div class="record-header">
                <h3 class="record-title">
                  {{ formatDateRange(record.startDate, record.endDate) }}
                </h3>
                <div class="record-badges">
                  <span class="duration-badge">
                    {{ calculateDuration(record) }}天
                  </span>
                  <span v-if="calculateCycleLength(record) > 0" class="cycle-badge">
                    周期{{ calculateCycleLength(record) }}天
                  </span>
                </div>
              </div>
              <div class="record-details">
                <div class="detail-item">
                  <i class="i-tabler-calendar text-gray-400 wh-4" />
                  <span>{{ formatDate(record.startDate) }} - {{ formatDate(record.endDate) }}</span>
                </div>
                <div v-if="getRecordSymptoms(record).length > 0" class="detail-item">
                  <i class="i-tabler-medical-cross text-gray-400 wh-4" />
                  <span>{{ getRecordSymptoms(record).join(', ') }}</span>
                </div>
              </div>
            </div>
            <div class="record-actions">
              <button class="action-btn" title="编辑" @click.stop="emit('editRecord', record)">
                <i class="i-tabler-edit wh-4" />
              </button>
              <button
                class="action-btn text-red-500 hover:text-red-700"
                title="删除" @click.stop="emit('deleteRecord', record.serialNum)"
              >
                <i class="i-tabler-trash wh-4" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页 -->
    <div v-if="totalPages > 1" class="pagination-section mt-6">
      <div class="flex items-center justify-between">
        <div class="text-sm text-gray-500 dark:text-gray-400">
          显示 {{ startIndex + 1 }}-{{ Math.min(endIndex, filteredRecords.length) }}
          共 {{ filteredRecords.length }} 条记录
        </div>
        <div class="flex gap-2">
          <button :disabled="currentPage === 1" class="pagination-btn" @click="currentPage = 1">
            <i class="i-tabler-chevrons-left wh-4" />
          </button>
          <button :disabled="currentPage === 1" class="pagination-btn" @click="currentPage--">
            <i class="i-tabler-chevron-left wh-4" />
          </button>
          <span class="pagination-info">
            {{ currentPage }} / {{ totalPages }}
          </span>
          <button :disabled="currentPage === totalPages" class="pagination-btn" @click="currentPage++">
            <i class="i-tabler-chevron-right wh-4" />
          </button>
          <button :disabled="currentPage === totalPages" class="pagination-btn" @click="currentPage = totalPages">
            <i class="i-tabler-chevrons-right wh-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.card-base {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm;
}

.input-base {
  @apply px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:focus:ring-blue-400 dark:focus:border-blue-400 transition-colors;
}

.select-base {
  @apply px-3 py-2 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:focus:ring-blue-400 dark:focus:border-blue-400 transition-colors;
}

.btn-secondary {
  @apply px-3 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 focus:ring-2 focus:ring-gray-500 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600 transition-colors flex items-center;
}

.btn-primary {
  @apply px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 transition-colors flex items-center;
}

.filter-label {
  @apply block text-xs font-medium text-gray-700 dark:text-gray-300 mb-1;
}

.stats-overview .stat-card {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4 flex items-center gap-3;
}

.stat-icon {
  @apply w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0;
}

.stat-content {
  @apply flex-1;
}

.stat-value {
  @apply text-lg font-bold text-gray-900 dark:text-white;
}

.stat-label {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

.empty-state {
  @apply text-center;
}

.record-card {
  @apply transition-all duration-200;
}

.record-card:hover {
  @apply transform -translate-y-1;
}

.record-header {
  @apply flex items-start justify-between mb-2;
}

.record-title {
  @apply text-lg font-semibold text-gray-900 dark:text-white;
}

.record-badges {
  @apply flex gap-2;
}

.duration-badge {
  @apply px-2 py-1 bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 rounded-full text-xs font-medium;
}

.cycle-badge {
  @apply px-2 py-1 bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400 rounded-full text-xs font-medium;
}

.record-details {
  @apply space-y-1;
}

.detail-item {
  @apply flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400;
}

.record-actions {
  @apply flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity;
}

.record-card:hover .record-actions {
  @apply opacity-100;
}

.action-btn {
  @apply p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300 transition-colors;
}

.pagination-section {
  @apply flex items-center justify-center;
}

.pagination-btn {
  @apply p-2 rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors;
}

.pagination-info {
  @apply px-3 py-2 text-sm text-gray-600 dark:text-gray-400;
}

@media (max-width: 640px) {
  .stats-overview {
    @apply grid-cols-2 gap-2;
  }

  .stat-card {
    @apply p-3;
  }

  .stat-value {
    @apply text-base;
  }

  .record-header {
    @apply flex-col items-start gap-2;
  }

  .record-actions {
    @apply opacity-100;
  }

  .filters-section .flex {
    @apply flex-col items-stretch;
  }

  .filters-section .grid {
    @apply grid-cols-1 gap-2;
  }
}

@media (max-width: 768px) {
  .stats-overview {
    @apply grid-cols-1;
  }
}
</style>
