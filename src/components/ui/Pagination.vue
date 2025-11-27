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
    class="pagination-container"
    :class="[{ compact: props.compact, responsive: props.responsive }]"
  >
    <!-- 左侧按钮 -->
    <div class="pagination-left">
      <button
        v-if="showFirstLast && !mediaQueries.isMobile"
        :disabled="currentPage <= 1 || disabled"
        class="pagination-button"
        :aria-label="t('pagination.home')"
        @click="goToFirst"
      >
        <ChevronsLeft class="icon" />
      </button>
      <button
        :disabled="currentPage <= 1 || disabled"
        class="pagination-button"
        :aria-label="t('pagination.prev')"
        @click="goToPrev"
      >
        <ChevronLeft class="icon" />
      </button>
    </div>

    <!-- 中间页码/跳转 -->
    <div class="pagination-center">
      <span class="page-info">{{ currentPage }}/{{ totalPages }}</span>
      <span v-if="showTotal && totalItems > 0" class="total-info">(共 {{ totalItems }} 条)</span>
      <input
        v-if="showJump"
        v-model.number="pageInput"
        type="number"
        :min="1"
        :max="totalPages"
        :disabled="disabled"
        class="page-jump-input"
        aria-label="Jump to page"
        @change="handlePageJump"
        @keydown.enter="handlePageJump"
      >
    </div>

    <!-- 右侧按钮 -->
    <div class="pagination-right">
      <button
        :disabled="currentPage >= totalPages || disabled"
        class="pagination-button"
        :aria-label="t('pagination.next')"
        @click="goToNext"
      >
        <ChevronRight class="icon" />
      </button>
      <button
        v-if="showFirstLast && !mediaQueries.isMobile"
        :disabled="currentPage >= totalPages || disabled"
        class="pagination-button"
        :aria-label="t('pagination.last')"
        @click="goToLast"
      >
        <ChevronsRight class="icon" />
      </button>
    </div>

    <!-- 每页大小选择器 -->
    <select
      v-if="showPageSize"
      v-model="internalPageSize"
      :disabled="disabled"
      class="page-size-select"
      aria-label="Select items per page"
      @change="handlePageSizeChange"
    >
      <option v-for="size in pageSizeOptions" :key="size" :value="size">
        {{ size }}
      </option>
    </select>
  </div>
</template>

<style lang="postcss" scoped>
.pagination-container {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem;
  border-radius: 0.8rem;
  background-color: var(--color-base-100);
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
  gap: 0.75rem;
}

/* 控制 compact 模式 */
.pagination-container.compact {
  padding: 0.5rem;
  background-color: transparent;
  box-shadow: none;
}

/* 左/中/右布局 */
.pagination-left,
.pagination-center,
.pagination-right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.pagination-center {
  flex-wrap: wrap;
  gap: 0.5rem;
}

.page-info {
  font-weight: 600;
  color: var(--color-base-content);
  font-size: 0.875rem;
}

.total-info {
  font-size: 0.875rem;
  color: var(--color-neutral-content);
}

.page-jump-input,
.page-size-select {
  --mix-ratio: clamp(15%, 20%, 25%);
  padding: 0.25rem 0.5rem;
  font-size: 0.875rem;
  border-radius: 0.375rem;
  border: 1px solid var(--color-base-content);
  color: var(--color-base-content);
  background: linear-gradient(
    180deg,
    color-mix(in oklch, var(--color-base-200) var(--mix-ratio), var(--color-base-100)) 0%,
    var(--color-base-200) 100%
  );
  outline: none;
  transition: all 0.2s ease-in-out;
}

.page-jump-input:focus,
.page-size-select:focus {
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px color-mix(in oklch, var(--color-primary) var(--mix-ratio), var(--color-base-200));
}

.page-jump-input:disabled,
.page-size-select:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.pagination-button {
  --mix-ratio: clamp(15%, 20%, 25%);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.75rem;
  border: 1px solid var(--color-base-content);
  font-size: 0.875rem;
  font-weight: 600;
  padding: 0.5rem 0.75rem;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  /* 默认动态渐变 */
  background: linear-gradient(
    180deg,
    color-mix(in oklch, var(--color-base-200) var(--mix-ratio), var(--color-base-100)) 0%,
    var(--color-base-200) 100%
  );
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.6), 0 2px 4px rgba(0,0,0,0.1);
  color: var(--color-base-content);
}

.pagination-button:hover:not(:disabled) {
  background: linear-gradient(
    180deg,
    var(--color-base-200) 0%,
    color-mix(in oklch, var(--color-base-200) var(--mix-ratio), var(--color-base-100)) 100%
  );
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.4), 0 4px 6px rgba(0,0,0,0.15);
}

.pagination-button:active:not(:disabled) {
  transform: translateY(1px);
  box-shadow: inset 0 2px 4px rgba(0,0,0,0.2);
}

.pagination-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  box-shadow: none;
}

.icon {
  width: 1rem;
  height: 1rem;
}

/* 大屏幕调整按钮渐变角度 */
@media (min-width: 768px) {
  .pagination-left .pagination-button { --gradient-angle: 135deg; }
  .pagination-right .pagination-button { --gradient-angle: 225deg; }
  .pagination-center .page-jump-input,
  .pagination-center .page-size-select { --gradient-angle: 180deg; }

  .pagination-button {
    background: linear-gradient(
      var(--gradient-angle, 180deg),
      color-mix(in oklch, var(--color-base-200) var(--mix-ratio), var(--color-base-100)) 0%,
      var(--color-base-200) 100%
    );
  }

  .pagination-button:hover:not(:disabled) {
    background: linear-gradient(
      var(--gradient-angle, 180deg),
      var(--color-base-200) 0%,
      color-mix(in oklch, var(--color-base-200) var(--mix-ratio), var(--color-base-100)) 100%
    );
  }
}
</style>
