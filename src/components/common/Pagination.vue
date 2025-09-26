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
      val => {
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

<template>
  <div class="pagination-container">
    <!-- First / Prev -->
    <div class="pagination-group">
      <button
        :disabled="currentPage <= 1"
        :aria-label="t('pagination.home')"
        class="btn-fancy"
        @click="onFirst"
      >
        <ChevronsLeft class="icon" />
      </button>
      <button
        :disabled="currentPage <= 1"
        :aria-label="t('pagination.prev')"
        class="btn-fancy"
        @click="onPrev"
      >
        <ChevronLeft class="icon" />
      </button>
    </div>

    <!-- Page Info -->
    <div class="pagination-info">
      <span class="page-text">{{ modelCurrentPage }}/{{ totalPages }}</span>
      <input
        v-model.number="pageInput"
        type="number"
        :min="1"
        :max="totalPages"
        aria-label="Jump to page"
        class="input-fancy"
        @change="handlePageJump"
        @keydown.enter="handlePageJump"
      >
    </div>

    <!-- Next / Last -->
    <div class="pagination-group">
      <button
        :disabled="currentPage === totalPages"
        :aria-label="t('pagination.next')"
        class="btn-fancy"
        @click="onNext"
      >
        <ChevronRight class="icon" />
      </button>
      <button
        :disabled="currentPage === totalPages"
        :aria-label="t('pagination.last')"
        class="btn-fancy"
        @click="onLast"
      >
        <ChevronsRight class="icon" />
      </button>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.pagination-container {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
  align-items: center;
  justify-content: space-between;
  padding: 1rem;
  border-radius: 0.5rem;
  background: var(--color-base-100);
  box-shadow: 0 4px 6px rgba(0,0,0,0.1);
}
@media (min-width: 640px) {
  .pagination-container {
    flex-wrap: nowrap;
  }
}

.pagination-group {
  display: flex;
  gap: 0.5rem;
}

.pagination-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.page-text {
  font-size: 0.875rem;
  color: var(--color-base-content);
}

/* 按钮样式 */
.btn-fancy {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0.5rem 0.75rem;
  border-radius: 0.75rem;
  border: 1px solid var(--color-neutral);
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
  background: linear-gradient(to bottom,
    var(--color-base-100),
    var(--color-base-200),
    var(--color-base-300)
  );
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.6),
              0 2px 4px rgba(0,0,0,0.1);
  transition: all 0.2s ease-in-out;
  cursor: pointer;
}
.btn-fancy:hover {
  background: linear-gradient(to bottom,
    var(--color-base-200),
    var(--color-base-300)
  );
  box-shadow: inset 0 1px 0 rgba(255,255,255,0.4),
              0 4px 6px rgba(0,0,0,0.15);
}
.btn-fancy:active {
  transform: translateY(1px);
  box-shadow: inset 0 2px 4px rgba(0,0,0,0.15);
}
.btn-fancy:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary),
              0 0 0 4px var(--color-base-100);
}
.btn-fancy:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  box-shadow: none;
}

/* 输入框样式 */
.input-fancy {
  width: 4rem;
  text-align: center;
  font-size: 0.875rem;
  color: var(--color-base-content);
  padding: 0.375rem 0.75rem;
  border-radius: 0.5rem;
  border: 1px solid var(--color-neutral);
  background: linear-gradient(to bottom,
    var(--color-base-100),
    var(--color-base-200)
  );
  box-shadow: inset 0 2px 4px rgba(0,0,0,0.06);
  transition: all 0.2s ease-in-out;
}
.input-fancy:hover {
  border-color: var(--color-neutral-content);
}
.input-fancy:focus {
  outline: none;
  box-shadow: 0 0 0 2px var(--color-primary),
              0 0 0 4px var(--color-base-100);
}
.input-fancy:disabled {
  opacity: 0.5;
}

.icon {
  width: 1rem;
  height: 1rem;
}
</style>
