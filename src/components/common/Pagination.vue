<!--
  -----------------------------------------------------------------------------
  Copyright (C) 2025 mcge. All rights reserved.
  Author:         mcge
  Email:          <mcgeq@outlook.com>
  File:           Pagination.svelte
  Description:    About Pagination
  Create   Date:  2025-06-22 13:34:56
  Last Modified:  2025-06-22 13:34:56
  Modified   By:  mcge <mcgeq@outlook.com>
  -----------------------------------------------------------------------------
-->
<!-- src/components/Pagination.vue -->

<template>
  <div
    class="flex flex-wrap sm:flex-nowrap items-center justify-between p-4 bg-white rounded-lg shadow-md gap-4"
  >
    <!-- First / Prev -->
    <div class="flex gap-2">
      <button
        @click="onFirst"
        :disabled="currentPage <= 1"
        :aria-label="t('pagination.home')"
        class="btn-fancy"
      >
        <ChevronsLeft class="w-4 h-4" />
      </button>
      <button
        @click="onPrev"
        :disabled="currentPage <= 1"
        :aria-label="t('pagination.prev')"
        class="btn-fancy"
      >
        <ChevronLeft class="w-4 h-4" />
      </button>
    </div>

    <!-- Page Info -->
    <div class="flex items-center gap-3">
      <span class="text-sm text-gray-700">{{ modelCurrentPage }}/{{ totalPages }}</span>
      <input
        type="number"
        v-model.number="pageInput"
        @change="handlePageJump"
        @keydown.enter="handlePageJump"
        :min="1"
        :max="totalPages"
        aria-label="Jump to page"
        class="input-fancy"
      />
    </div>

    <!-- Next / Last -->
    <div class="flex gap-2">
      <button
        @click="onNext"
        :disabled="currentPage === totalPages"
        :aria-label="t('pagination.next')"
        class="btn-fancy"
      >
        <ChevronRight class="w-4 h-4" />
      </button>
      <button
        @click="onLast"
        :disabled="currentPage === totalPages"
        :aria-label="t('pagination.last')"
        class="btn-fancy"
      >
        <ChevronsRight class="w-4 h-4" />
      </button>
    </div>

    <!-- Page size selector (hidden) -->
    <select
      v-model="modelPageSize"
      @change="handlePageSizeChange"
      hidden
      disabled
      aria-label="Select items per page"
      class="px-2 py-1 border border-gray-300 rounded-md text-sm"
    >
      <option v-for="size in modelPageSize" :key="size" :value="size">{{ size }}</option>
    </select>
  </div>
</template>

<script lang="ts">
import {
  ChevronLeft,
  ChevronRight,
  ChevronsLeft,
  ChevronsRight,
} from 'lucide-vue-next';
import { useI18n } from 'vue-i18n';

export default defineComponent({
  name: 'Pagination',
  components: {
    ChevronLeft,
    ChevronRight,
    ChevronsLeft,
    ChevronsRight,
  },
  props: {
    currentPage: { type: Number, required: true },
    pageSize: { type: Number, required: true },
    totalPages: { type: Number, required: true },
    onFirst: { type: Function as PropType<() => void>, required: true },
    onLast: { type: Function as PropType<() => void>, required: true },
    onNext: { type: Function as PropType<() => void>, required: true },
    onPrev: { type: Function as PropType<() => void>, required: true },
    onPageJump: {
      type: Function as PropType<(page: number) => void>,
      required: true,
    },
    onPageSizeChange: {
      type: Function as PropType<(size: number) => void>,
      required: true,
    },
  },
  emits: ['update:currentPage', 'update:pageSize'],
  setup(props, { emit }) {
    const { t } = useI18n();

    const pageInput = ref(props.currentPage);

    const modelCurrentPage = computed({
      get: () => props.currentPage,
      set: (val: number) => {
        emit('update:currentPage', val);
      },
    });

    // 代理 pageSize
    const modelPageSize = computed({
      get: () => props.pageSize,
      set: (val: number) => {
        emit('update:pageSize', val);
      },
    });

    watch(
      () => props.currentPage,
      (val) => {
        pageInput.value = val;
      },
    );

    const handlePageJump = () => {
      const value = pageInput.value;
      if (value >= 1 && value <= props.totalPages) {
        modelCurrentPage.value = value;
        props.onPageJump(value);
      } else {
        pageInput.value = props.currentPage;
      }
    };

    const handlePageSizeChange = () => {
      const value = modelPageSize.value;
      if (value !== props.pageSize) {
        emit('update:pageSize', value);
        props.onPageSizeChange(value);
      }
    };

    return {
      t,
      pageInput,
      modelCurrentPage,
      modelPageSize,
      handlePageJump,
      handlePageSizeChange,
    };
  },
});
</script>

<style scoped lang="postcss">
.btn-fancy {
  @apply inline-flex items-center justify-center px-3 py-2 rounded-xl border border-gray-300
    text-sm font-semibold text-gray-800 bg-gradient-to-b from-white via-gray-100 to-gray-200
    shadow-[inset_0_1px_0_rgba(255,255,255,0.6),_0_2px_4px_rgba(0,0,0,0.1)]
    transition-all duration-200 ease-in-out
    hover:from-gray-100 hover:via-gray-200 hover:to-gray-300
    hover:shadow-[inset_0_1px_0_rgba(255,255,255,0.4),_0_4px_6px_rgba(0,0,0,0.15)]
    active:translate-y-[1px] active:shadow-inner
    focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
    disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none;
}

.input-fancy {
  @apply w-16 text-center text-sm text-gray-800 px-3 py-1.5 rounded-lg border border-gray-300
    bg-gradient-to-b from-white to-gray-100 shadow-inner
    focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
    transition-all duration-200 ease-in-out hover:border-gray-400 disabled:opacity-50;
}
</style>
