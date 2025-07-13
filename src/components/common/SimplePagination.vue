<!-- src/components/SimplePagination.vue -->
<template>
  <div
    class="flex flex-wrap sm:flex-nowrap items-center justify-between p-4 bg-white rounded-lg shadow-md gap-4"
  >
    <!-- First / Prev -->
    <div class="flex gap-2">
      <button
        @click="goToFirst"
        :disabled="currentPage <= 1"
        :aria-label="t('pagination.home')"
        class="btn-fancy"
      >
        <ChevronsLeft class="w-4 h-4" />
      </button>
      <button
        @click="goToPrev"
        :disabled="currentPage <= 1"
        :aria-label="t('pagination.prev')"
        class="btn-fancy"
      >
        <ChevronLeft class="w-4 h-4" />
      </button>
    </div>

    <!-- Page Info -->
    <div class="flex items-center gap-3">
      <span class="text-sm text-gray-700">{{ currentPage }}/{{ totalPages }}</span>
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
        @click="goToNext"
        :disabled="currentPage >= totalPages"
        :aria-label="t('pagination.next')"
        class="btn-fancy"
      >
        <ChevronRight class="w-4 h-4" />
      </button>
      <button
        @click="goToLast"
        :disabled="currentPage >= totalPages"
        :aria-label="t('pagination.last')"
        class="btn-fancy"
      >
        <ChevronsRight class="w-4 h-4" />
      </button>
    </div>

    <!-- Page size selector (可选显示) -->
    <select
      v-if="showPageSize"
      v-model="internalPageSize"
      @change="handlePageSizeChange"
      aria-label="Select items per page"
      class="px-2 py-1 border border-gray-300 rounded-md text-sm"
    >
      <option v-for="size in pageSizeOptions" :key="size" :value="size">
        {{ size }}
      </option>
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
  name: 'SimplePagination',
  components: {
    ChevronLeft,
    ChevronRight,
    ChevronsLeft,
    ChevronsRight,
  },
  props: {
    // 当前页码
    currentPage: {
      type: Number,
      required: true,
    },
    // 总页数
    totalPages: {
      type: Number,
      required: true,
    },
    // 总条目数 (可选)
    totalItems: {
      type: Number,
      default: 0,
    },
    // 每页大小
    pageSize: {
      type: Number,
      default: 10,
    },
    // 是否显示每页大小选择器
    showPageSize: {
      type: Boolean,
      default: false,
    },
    // 每页大小选项
    pageSizeOptions: {
      type: Array as PropType<number[]>,
      default: () => [10, 20, 50, 100],
    },
    // 禁用状态
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['page-change', 'page-size-change'],
  setup(props, { emit }) {
    const { t } = useI18n();

    // 页码输入框的值
    const pageInput = ref(props.currentPage);

    // 内部页面大小状态
    const internalPageSize = ref(props.pageSize);

    // 监听当前页码变化，同步到输入框
    watch(
      () => props.currentPage,
      (newPage) => {
        pageInput.value = newPage;
      },
      { immediate: true },
    );

    // 监听页面大小变化
    watch(
      () => props.pageSize,
      (newSize) => {
        internalPageSize.value = newSize;
      },
      { immediate: true },
    );

    // 跳转到第一页
    const goToFirst = () => {
      if (props.disabled || props.currentPage <= 1) return;
      emit('page-change', 1);
    };

    // 跳转到上一页
    const goToPrev = () => {
      if (props.disabled || props.currentPage <= 1) return;
      emit('page-change', props.currentPage - 1);
    };

    // 跳转到下一页
    const goToNext = () => {
      if (props.disabled || props.currentPage >= props.totalPages) return;
      emit('page-change', props.currentPage + 1);
    };

    // 跳转到最后一页
    const goToLast = () => {
      if (props.disabled || props.currentPage >= props.totalPages) return;
      emit('page-change', props.totalPages);
    };

    // 处理页码跳转
    const handlePageJump = () => {
      if (props.disabled) return;

      const targetPage = pageInput.value;

      // 验证页码范围
      if (
        targetPage >= 1 &&
        targetPage <= props.totalPages &&
        targetPage !== props.currentPage
      ) {
        emit('page-change', targetPage);
      } else {
        // 如果输入无效，恢复到当前页码
        pageInput.value = props.currentPage;
      }
    };

    // 处理每页大小变化
    const handlePageSizeChange = () => {
      if (props.disabled) return;

      const newSize = internalPageSize.value;
      if (newSize !== props.pageSize) {
        emit('page-size-change', newSize);
      }
    };

    return {
      t,
      pageInput,
      internalPageSize,
      goToFirst,
      goToPrev,
      goToNext,
      goToLast,
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
