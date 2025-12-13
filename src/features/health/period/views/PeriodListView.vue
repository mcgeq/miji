<script setup lang="ts">
  import {
    Calendar,
    CalendarHeart,
    Clock,
    Edit,
    ListFilter,
    Plus,
    Repeat,
    RotateCcw,
    Search,
    Stethoscope,
    Trash,
    TrendingUp,
  } from 'lucide-vue-next';
  import { Badge, Button, Card, Input, Pagination, Select } from '@/components/ui';
  import type { PeriodRecords } from '@/schema/health/period';
  import { usePeriodStore } from '@/stores/periodStore';
  import { DateUtils } from '@/utils/date';

  interface SortOption {
    value: 'startDate' | 'duration' | 'cycleLength';
    label: string;
  }

  interface OrderOption {
    value: 'asc' | 'desc';
    label: string;
  }

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

  // 排序选项
  const sortOptions: SortOption[] = [
    { value: 'startDate', label: '按开始日期' },
    { value: 'duration', label: '按持续时间' },
    { value: 'cycleLength', label: '按周期长度' },
  ];

  const orderOptions: OrderOption[] = [
    { value: 'desc', label: '降序' },
    { value: 'asc', label: '升序' },
  ];

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
      records = records.filter(record => record.startDate >= filters.value.startDate);
    }
    if (filters.value.endDate) {
      records = records.filter(record => record.startDate <= filters.value.endDate);
    }
    if (filters.value.minDuration) {
      const minDuration = filters.value.minDuration;
      records = records.filter(
        record => DateUtils.daysBetweenInclusive(record.startDate, record.endDate) >= minDuration,
      );
    }
    if (filters.value.maxDuration) {
      const maxDuration = filters.value.maxDuration;
      records = records.filter(
        record => DateUtils.daysBetweenInclusive(record.startDate, record.endDate) <= maxDuration,
      );
    }
    if (filters.value.minCycle) {
      const minCycle = filters.value.minCycle;
      records = records.filter(record => {
        const cycle = calculateCycleLength(record);
        return cycle === 0 || cycle >= minCycle;
      });
    }
    if (filters.value.maxCycle) {
      const maxCycle = filters.value.maxCycle;
      records = records.filter(record => {
        const cycle = calculateCycleLength(record);
        return cycle === 0 || cycle <= maxCycle;
      });
    }

    // 排序
    records.sort((a, b) => {
      let aValue: number;
      let bValue: number;

      switch (sortBy.value) {
        case 'startDate':
          aValue = new Date(a.startDate).getTime();
          bValue = new Date(b.startDate).getTime();
          break;
        case 'duration':
          aValue = DateUtils.daysBetweenInclusive(a.startDate, a.endDate);
          bValue = DateUtils.daysBetweenInclusive(b.startDate, b.endDate);
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

  const totalPages = computed(() => Math.ceil(filteredRecords.value.length / pageSize.value));

  const startIndex = computed(() => (currentPage.value - 1) * pageSize.value);
  const endIndex = computed(() => startIndex.value + pageSize.value);

  const paginatedRecords = computed(() => {
    return filteredRecords.value.slice(startIndex.value, endIndex.value);
  });

  const averageDuration = computed(() => {
    if (filteredRecords.value.length === 0) return 0;
    const total = filteredRecords.value.reduce(
      (sum, record) => sum + DateUtils.daysBetweenInclusive(record.startDate, record.endDate),
      0,
    );
    return total / filteredRecords.value.length;
  });

  const averageCycle = computed(() => {
    if (filteredRecords.value.length < 2) return 0;

    const cycles = filteredRecords.value
      .map(record => calculateCycleLength(record))
      .filter(cycle => cycle > 0);

    if (cycles.length === 0) return 0;

    const total = cycles.reduce((sum, cycle) => sum + cycle, 0);
    return total / cycles.length;
  });

  const regularity = computed(() => {
    if (filteredRecords.value.length < 3) return 0;

    const cycles = filteredRecords.value
      .map(record => calculateCycleLength(record))
      .filter(cycle => cycle > 0);

    if (cycles.length < 2) return 0;

    const average = cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length;
    const variance = cycles.reduce((sum, cycle) => sum + (cycle - average) ** 2, 0) / cycles.length;
    const standardDeviation = Math.sqrt(variance);

    return Math.max(0, Math.round(100 - standardDeviation * 5));
  });

  // Methods
  function calculateCycleLength(record: PeriodRecords): number {
    const allRecords = periodStore.periodRecords
      .slice()
      .sort((a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime());

    const index = allRecords.findIndex(r => r.serialNum === record.serialNum);
    if (index <= 0) return 0;

    const current = new Date(record.startDate);
    const previous = new Date(allRecords[index - 1].startDate);

    return Math.ceil((current.getTime() - previous.getTime()) / (1000 * 60 * 60 * 24));
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
    }
    return `${start.getMonth() + 1}月${start.getDate()}日-${end.getMonth() + 1}月${end.getDate()}日`;
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
  <div class="flex flex-col gap-6">
    <!-- 过滤和搜索 -->
    <Card shadow="sm" padding="md">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-center">
        <!-- 搜索框 -->
        <div class="flex-1">
          <Input
            v-model="searchQuery"
            type="search"
            placeholder="搜索记录..."
            :prefix-icon="Search"
            full-width
          />
        </div>

        <!-- 排序和筛选按钮 -->
        <div class="flex flex-wrap gap-2">
          <Select v-model="sortBy" :options="sortOptions" size="sm" />
          <Select v-model="sortOrder" :options="orderOptions" size="sm" />
          <Button
            variant="secondary"
            size="sm"
            :class="{ 'bg-blue-50 dark:bg-blue-900/30': hasActiveFilters }"
            @click="showFilters = !showFilters"
          >
            <ListFilter class="w-5 h-5" />
          </Button>
          <Button v-if="showFilters" variant="secondary" size="sm" @click="clearFilters">
            <RotateCcw class="w-5 h-5" />
          </Button>
        </div>
      </div>

      <!-- 高级筛选 -->
      <div v-if="showFilters" class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <!-- 日期范围 -->
          <div class="flex flex-col gap-2">
            <label class="text-xs font-medium text-gray-700 dark:text-gray-300">日期范围</label>
            <Input v-model="filters.startDate" type="date" size="sm" full-width />
            <Input v-model="filters.endDate" type="date" size="sm" full-width />
          </div>

          <!-- 持续时间 -->
          <div class="flex flex-col gap-2">
            <label class="text-xs font-medium text-gray-700 dark:text-gray-300">持续时间</label>
            <Input
              v-model="filters.minDuration"
              type="number"
              placeholder="最少天数"
              min="1"
              size="sm"
              full-width
            />
            <Input
              v-model="filters.maxDuration"
              type="number"
              placeholder="最多天数"
              min="1"
              size="sm"
              full-width
            />
          </div>

          <!-- 周期长度 -->
          <div class="flex flex-col gap-2">
            <label class="text-xs font-medium text-gray-700 dark:text-gray-300">周期长度</label>
            <Input
              v-model="filters.minCycle"
              type="number"
              placeholder="最短周期"
              min="1"
              size="sm"
              full-width
            />
            <Input
              v-model="filters.maxCycle"
              type="number"
              placeholder="最长周期"
              min="1"
              size="sm"
              full-width
            />
          </div>
        </div>
      </div>
    </Card>

    <!-- 统计概览 -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-3">
      <Card shadow="sm" padding="md" class="flex items-center gap-3">
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-rose-100 dark:bg-rose-900/30 shrink-0"
        >
          <CalendarHeart class="w-5 h-5 text-rose-600 dark:text-rose-400" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-lg font-bold text-gray-900 dark:text-white">
            {{ filteredRecords.length }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400">总记录数</div>
        </div>
      </Card>

      <Card shadow="sm" padding="md" class="flex items-center gap-3">
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-blue-100 dark:bg-blue-900/30 shrink-0"
        >
          <Clock class="w-5 h-5 text-blue-600 dark:text-blue-400" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-lg font-bold text-gray-900 dark:text-white">
            {{ averageDuration.toFixed(1) }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400">平均持续天数</div>
        </div>
      </Card>

      <Card shadow="sm" padding="md" class="flex items-center gap-3">
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-green-100 dark:bg-green-900/30 shrink-0"
        >
          <Repeat class="w-5 h-5 text-green-600 dark:text-green-400" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-lg font-bold text-gray-900 dark:text-white">
            {{ averageCycle.toFixed(1) }}
          </div>
          <div class="text-xs text-gray-500 dark:text-gray-400">平均周期天数</div>
        </div>
      </Card>

      <Card shadow="sm" padding="md" class="flex items-center gap-3">
        <div
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-purple-100 dark:bg-purple-900/30 shrink-0"
        >
          <TrendingUp class="w-5 h-5 text-purple-600 dark:text-purple-400" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-lg font-bold text-gray-900 dark:text-white">{{ regularity }}%</div>
          <div class="text-xs text-gray-500 dark:text-gray-400">规律性</div>
        </div>
      </Card>
    </div>

    <!-- 记录列表 -->
    <div>
      <!-- 空状态 -->
      <Card v-if="filteredRecords.length === 0" shadow="sm" padding="lg" class="text-center">
        <h3 class="text-lg font-medium text-gray-900 dark:text-white mb-2">
          {{ searchQuery || hasActiveFilters ? '未找到匹配的记录' : '还没有经期记录' }}
        </h3>
        <p class="text-sm text-gray-500 dark:text-gray-400 mb-4">
          {{ searchQuery || hasActiveFilters ? '试试调整搜索条件或筛选器' : '开始记录你的经期数据吧' }}
        </p>
        <Button
          v-if="!searchQuery && !hasActiveFilters"
          variant="primary"
          @click="emit('addRecord')"
        >
          <Plus class="w-4 h-4 mr-2" />
          添加记录
        </Button>
      </Card>

      <!-- 记录列表 -->
      <div v-else class="flex flex-col gap-3">
        <Card
          v-for="record in paginatedRecords"
          :key="record.serialNum"
          shadow="sm"
          padding="md"
          hoverable
          class="cursor-pointer"
          @click="emit('editRecord', record)"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="flex-1 min-w-0">
              <!-- 记录头部 -->
              <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-2 mb-3">
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                  {{ formatDateRange(record.startDate, record.endDate) }}
                </h3>
                <div class="flex gap-2">
                  <Badge variant="danger" size="sm">
                    {{ DateUtils.daysBetweenInclusive(record.startDate, record.endDate) }}天
                  </Badge>
                  <Badge v-if="calculateCycleLength(record) > 0" variant="info" size="sm">
                    周期{{ calculateCycleLength(record) }}天
                  </Badge>
                </div>
              </div>

              <!-- 记录详情 -->
              <div class="flex flex-col gap-1">
                <div class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400">
                  <Calendar class="w-4 h-4 shrink-0" />
                  <span>{{ formatDate(record.startDate) }}- {{ formatDate(record.endDate) }}</span>
                </div>
                <div
                  v-if="getRecordSymptoms(record).length > 0"
                  class="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400"
                >
                  <Stethoscope class="w-4 h-4 shrink-0" />
                  <span>{{ getRecordSymptoms(record).join(', ') }}</span>
                </div>
              </div>
            </div>

            <!-- 操作按钮 -->
            <div
              class="flex items-center gap-1 opacity-0 sm:opacity-100 group-hover:opacity-100 transition-opacity"
            >
              <button
                class="p-2 rounded-lg transition-colors hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-600 dark:text-gray-400"
                title="编辑"
                @click.stop="emit('editRecord', record)"
              >
                <Edit class="w-4 h-4" />
              </button>
              <button
                class="p-2 rounded-lg transition-colors hover:bg-rose-100 dark:hover:bg-rose-900/30 text-rose-600 dark:text-rose-400"
                title="删除"
                @click.stop="emit('deleteRecord', record.serialNum)"
              >
                <Trash class="w-4 h-4" />
              </button>
            </div>
          </div>
        </Card>
      </div>
    </div>

    <!-- 分页 -->
    <Pagination
      v-if="totalPages > 1"
      :current-page="currentPage"
      :total-pages="totalPages"
      :total-items="filteredRecords.length"
      :page-size="pageSize"
      show-total
      @page-change="currentPage = $event"
    />
  </div>
</template>
