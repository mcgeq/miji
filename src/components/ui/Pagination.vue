<!-- src/components/SimplePagination.vue -->
<script lang="ts" setup>
import {
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
} from 'lucide-vue-next';
import { useI18n } from 'vue-i18n';
import { useMediaQueriesStore } from '@/stores/mediaQueries';

interface Props {
  currentPage: number;
  totalPages: number;
  totalItems?: number;
  pageSize?: number;
  showPageSize?: boolean;
  showTotal?: boolean;
  showJump?: boolean;
  showFirstLast?: boolean;
  compact?: boolean;
  responsive?: boolean;
  pageSizeOptions?: number[];
  disabled?: boolean;
}

interface Emits {
  pageChange: [page: number];
  pageSizeChange: [size: number];
}

const props = withDefaults(defineProps<Props>(), {
  totalItems: 0,
  pageSize: 10,
  showPageSize: false,
  showTotal: false,
  showJump: true,
  showFirstLast: true,
  compact: false,
  responsive: true,
  pageSizeOptions: () => [10, 20, 50, 100],
});

const emit = defineEmits<Emits>();
const { t } = useI18n();
const mediaQueries = useMediaQueriesStore();

const pageInput = ref(props.currentPage);
const internalPageSize = ref(props.pageSize);

watch(() => props.currentPage, newPage => {
  pageInput.value = newPage;
}, { immediate: true });

watch(() => props.pageSize, newSize => {
  internalPageSize.value = newSize;
}, { immediate: true });

function goToFirst() {
  if (!props.disabled && pageInput.value > 1)
    emit('pageChange', 1);
}
function goToPrev() {
  if (!props.disabled && pageInput.value > 1) emit('pageChange', props.currentPage - 1);
}
function goToNext() {
  if (!props.disabled && pageInput.value < props.totalPages)
    emit('pageChange', props.currentPage + 1);
}
function goToLast() {
  if (!props.disabled && pageInput.value < props.totalPages)
    emit('pageChange', props.totalPages);
}

function handlePageJump() {
  if (props.disabled) return;
  const targetPage = pageInput.value;
  if (targetPage >= 1 && targetPage <= props.totalPages && targetPage !== props.currentPage) {
    emit('pageChange', targetPage);
  } else {
    pageInput.value = props.currentPage;
  }
}

function handlePageSizeChange() {
  if (props.disabled) return;
  emit('pageSizeChange', internalPageSize.value);
}
</script>

<template>
  <div
    class="flex flex-wrap justify-between items-center gap-3"
    :class="[
      compact ? 'p-2 bg-transparent' : 'p-2 rounded-xl bg-white dark:bg-gray-800 shadow-md',
    ]"
  >
    <!-- 左侧按钮 -->
    <div class="flex items-center gap-2">
      <button
        v-if="showFirstLast && !mediaQueries.isMobile"
        :disabled="currentPage <= 1 || disabled"
        class="inline-flex items-center justify-center rounded-xl border px-3 py-2 text-sm font-semibold transition-all duration-200 bg-gradient-to-b from-gray-50 to-gray-100 dark:from-gray-700 dark:to-gray-800 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 shadow-sm hover:shadow-md hover:from-gray-100 hover:to-gray-50 dark:hover:from-gray-800 dark:hover:to-gray-700 active:translate-y-0.5 active:shadow-inner disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none"
        :aria-label="t('pagination.home')"
        @click="goToFirst"
      >
        <ChevronsLeft class="w-4 h-4" />
      </button>
      <button
        :disabled="currentPage <= 1 || disabled"
        class="inline-flex items-center justify-center rounded-xl border px-3 py-2 text-sm font-semibold transition-all duration-200 bg-gradient-to-b from-gray-50 to-gray-100 dark:from-gray-700 dark:to-gray-800 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 shadow-sm hover:shadow-md hover:from-gray-100 hover:to-gray-50 dark:hover:from-gray-800 dark:hover:to-gray-700 active:translate-y-0.5 active:shadow-inner disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none"
        :aria-label="t('pagination.prev')"
        @click="goToPrev"
      >
        <ChevronLeft class="w-4 h-4" />
      </button>
    </div>

    <!-- 中间页码/跳转 -->
    <div class="flex flex-wrap items-center gap-2">
      <span class="text-sm font-semibold text-gray-900 dark:text-white">{{ currentPage }}/{{ totalPages }}</span>
      <span v-if="showTotal && totalItems > 0" class="text-sm text-gray-600 dark:text-gray-400">(共 {{ totalItems }} 条)</span>
      <input
        v-if="showJump"
        v-model.number="pageInput"
        type="number"
        :min="1"
        :max="totalPages"
        :disabled="disabled"
        class="w-16 px-2 py-1 text-sm rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        aria-label="Jump to page"
        @change="handlePageJump"
        @keydown.enter="handlePageJump"
      >
    </div>

    <!-- 右侧按钮 -->
    <div class="flex items-center gap-2">
      <button
        :disabled="currentPage >= totalPages || disabled"
        class="inline-flex items-center justify-center rounded-xl border px-3 py-2 text-sm font-semibold transition-all duration-200 bg-gradient-to-b from-gray-50 to-gray-100 dark:from-gray-700 dark:to-gray-800 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 shadow-sm hover:shadow-md hover:from-gray-100 hover:to-gray-50 dark:hover:from-gray-800 dark:hover:to-gray-700 active:translate-y-0.5 active:shadow-inner disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none"
        :aria-label="t('pagination.next')"
        @click="goToNext"
      >
        <ChevronRight class="w-4 h-4" />
      </button>
      <button
        v-if="showFirstLast && !mediaQueries.isMobile"
        :disabled="currentPage >= totalPages || disabled"
        class="inline-flex items-center justify-center rounded-xl border px-3 py-2 text-sm font-semibold transition-all duration-200 bg-gradient-to-b from-gray-50 to-gray-100 dark:from-gray-700 dark:to-gray-800 border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-200 shadow-sm hover:shadow-md hover:from-gray-100 hover:to-gray-50 dark:hover:from-gray-800 dark:hover:to-gray-700 active:translate-y-0.5 active:shadow-inner disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none"
        :aria-label="t('pagination.last')"
        @click="goToLast"
      >
        <ChevronsRight class="w-4 h-4" />
      </button>
    </div>

    <!-- 每页大小选择器 -->
    <select
      v-if="showPageSize"
      v-model="internalPageSize"
      :disabled="disabled"
      class="px-2 py-1 text-sm rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      aria-label="Select items per page"
      @change="handlePageSizeChange"
    >
      <option v-for="size in pageSizeOptions" :key="size" :value="size">
        {{ size }}
      </option>
    </select>
  </div>
</template>
