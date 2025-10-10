<script setup lang="ts">
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
            <LucideListFilterPlus class="ml-2 wh-5" />
          </button>
          <div v-if="showFilters">
            <button class="text-sm btn-secondary self-end" @click="clearFilters">
              <LucideListRestart class="ml-2 wh-5" />
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
  background-color: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.dark .card-base {
  background-color: #1f2937;
  border-color: #374151;
}

.input-base {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
}

.input-base:focus {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6;
  border-color: #3b82f6;
}

.dark .input-base {
  border-color: #4b5563;
  background-color: #1f2937;
  color: white;
}

.dark .input-base:focus {
  box-shadow: 0 0 0 2px #60a5fa;
  border-color: #60a5fa;
}

.select-base {
  padding: 0.5rem 0.75rem;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  background-color: white;
  transition: all 0.2s ease-in-out;
}

.select-base:focus {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6;
  border-color: #3b82f6;
}

.dark .select-base {
  border-color: #4b5563;
  background-color: #1f2937;
  color: white;
}

.dark .select-base:focus {
  box-shadow: 0 0 0 2px #60a5fa;
  border-color: #60a5fa;
}

.btn-secondary {
  padding: 0.5rem 0.75rem;
  background-color: #e5e7eb;
  color: #374151;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.btn-secondary:hover {
  background-color: #d1d5db;
}

.btn-secondary:focus {
  outline: none;
  box-shadow: 0 0 0 2px #6b7280;
}

.dark .btn-secondary {
  background-color: #374151;
  color: #d1d5db;
}

.dark .btn-secondary:hover {
  background-color: #4b5563;
}

.btn-primary {
  padding: 0.5rem 1rem;
  background-color: #2563eb;
  color: white;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.btn-primary:hover {
  background-color: #1d4ed8;
}

.btn-primary:focus {
  outline: none;
  box-shadow: 0 0 0 2px #3b82f6;
}

.filter-label {
  display: block;
  font-size: 0.75rem;
  font-weight: 500;
  color: #374151;
  margin-bottom: 0.25rem;
}

.dark .filter-label {
  color: #d1d5db;
}

.stats-overview .stat-card {
  background-color: white;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  padding: 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.dark .stats-overview .stat-card {
  background-color: #1f2937;
  border-color: #374151;
}

.stat-icon {
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.stat-content {
  flex: 1;
}

.stat-value {
  font-size: 1.125rem;
  font-weight: 700;
  color: #111827;
}

.dark .stat-value {
  color: white;
}

.stat-label {
  font-size: 0.75rem;
  color: #6b7280;
}

.dark .stat-label {
  color: #9ca3af;
}

.empty-state {
  text-align: center;
}

.record-card {
  transition: all 0.2s ease-in-out;
}

.record-card:hover {
  transform: translateY(-0.25rem);
}

.record-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  margin-bottom: 0.5rem;
}

.record-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #111827;
}

.dark .record-title {
  color: white;
}

.record-badges {
  display: flex;
  gap: 0.5rem;
}

.duration-badge {
  padding: 0.25rem 0.5rem;
  background-color: #fee2e2;
  color: #dc2626;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.dark .duration-badge {
  background-color: rgba(69, 10, 10, 0.3);
  color: #f87171;
}

.cycle-badge {
  padding: 0.25rem 0.5rem;
  background-color: #dbeafe;
  color: #1d4ed8;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.dark .cycle-badge {
  background-color: rgba(30, 58, 138, 0.3);
  color: #60a5fa;
}

.record-details {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.detail-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  color: #4b5563;
}

.dark .detail-item {
  color: #9ca3af;
}

.record-actions {
  display: flex;
  gap: 0.25rem;
  opacity: 0;
  transition: opacity 0.2s ease-in-out;
}

.record-card:hover .record-actions {
  opacity: 1;
}

.action-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  color: #6b7280;
}

.action-btn:hover {
  background-color: #f3f4f6;
  color: #374151;
}

.dark .action-btn {
  color: #9ca3af;
}

.dark .action-btn:hover {
  background-color: #374151;
  color: #d1d5db;
}

.pagination-section {
  display: flex;
  align-items: center;
  justify-content: center;
}

.pagination-btn {
  padding: 0.5rem;
  border-radius: 0.5rem;
  border: 1px solid #d1d5db;
  transition: all 0.2s ease-in-out;
}

.pagination-btn:hover {
  background-color: #f9fafb;
}

.pagination-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.dark .pagination-btn {
  border-color: #4b5563;
}

.dark .pagination-btn:hover {
  background-color: #374151;
}

.pagination-info {
  padding: 0.5rem 0.75rem;
  font-size: 0.875rem;
  color: #4b5563;
}

.dark .pagination-info {
  color: #9ca3af;
}

@media (max-width: 640px) {
  .stats-overview {
    grid-template-columns: repeat(2, 1fr);
    gap: 0.5rem;
  }

  .stat-card {
    padding: 0.75rem;
  }

  .stat-value {
    font-size: 1rem;
  }

  .record-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .record-actions {
    opacity: 1;
  }

  .filters-section .flex {
    flex-direction: column;
    align-items: stretch;
  }

  .filters-section .grid {
    grid-template-columns: 1fr;
    gap: 0.5rem;
  }
}

@media (max-width: 768px) {
  .stats-overview {
    grid-template-columns: 1fr;
  }
}
</style>
