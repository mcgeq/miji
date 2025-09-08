<!-- src/components/SimplePagination.vue -->
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
    // 基础分页属性
    currentPage: {
      type: Number,
      required: true,
    },
    totalPages: {
      type: Number,
      required: true,
    },
    totalItems: {
      type: Number,
      default: 0,
    },
    pageSize: {
      type: Number,
      default: 10,
    },

    // 显示选项
    showPageSize: {
      type: Boolean,
      default: false,
    },
    showTotal: {
      type: Boolean,
      default: false,
    },
    showJump: {
      type: Boolean,
      default: true,
    },
    showFirstLast: {
      type: Boolean,
      default: true,
    },

    // 样式选项
    compact: {
      type: Boolean,
      default: false,
    },
    responsive: {
      type: Boolean,
      default: true,
    },

    // 功能选项
    pageSizeOptions: {
      type: Array as PropType<number[]>,
      default: () => [10, 20, 50, 100],
    },
    disabled: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['pageChange', 'pageSizeChange'],
  setup(props, { emit }) {
    const { t } = useI18n();

    // 页码输入框的值
    const pageInput = ref(props.currentPage);

    // 内部页面大小状态
    const internalPageSize = ref(props.pageSize);

    // 按钮样式类
    const buttonClasses = computed(() => [
      'inline-flex items-center justify-center rounded-xl border border-gray-300',
      'text-sm font-semibold text-gray-800 bg-gradient-to-b from-white via-gray-100 to-gray-200',
      'shadow-[inset_0_1px_0_rgba(255,255,255,0.6),_0_2px_4px_rgba(0,0,0,0.1)]',
      'transition-all duration-200 ease-in-out',
      'hover:from-gray-100 hover:via-gray-200 hover:to-gray-300',
      'hover:shadow-[inset_0_1px_0_rgba(255,255,255,0.4),_0_4px_6px_rgba(0,0,0,0.15)]',
      'active:translate-y-[1px] active:shadow-inner',
      'focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2',
      'disabled:opacity-50 disabled:cursor-not-allowed disabled:shadow-none',
      props.compact ? 'px-2 py-1' : 'px-3 py-2',
    ]);

    // 监听当前页码变化，同步到输入框
    watch(
      () => props.currentPage,
      newPage => {
        pageInput.value = newPage;
      },
      { immediate: true },
    );

    // 监听页面大小变化
    watch(
      () => props.pageSize,
      newSize => {
        internalPageSize.value = newSize;
      },
      { immediate: true },
    );

    // 跳转到第一页
    const goToFirst = () => {
      if (props.disabled || props.currentPage <= 1)
        return;
      emit('pageChange', 1);
    };

    // 跳转到上一页
    const goToPrev = () => {
      if (props.disabled || props.currentPage <= 1)
        return;
      emit('pageChange', props.currentPage - 1);
    };

    // 跳转到下一页
    const goToNext = () => {
      if (props.disabled || props.currentPage >= props.totalPages)
        return;
      emit('pageChange', props.currentPage + 1);
    };

    // 跳转到最后一页
    const goToLast = () => {
      if (props.disabled || props.currentPage >= props.totalPages)
        return;
      emit('pageChange', props.totalPages);
    };

    // 处理页码跳转
    const handlePageJump = () => {
      if (props.disabled)
        return;

      const targetPage = pageInput.value;

      // 验证页码范围
      if (
        targetPage >= 1
        && targetPage <= props.totalPages
        && targetPage !== props.currentPage
      ) {
        emit('pageChange', targetPage);
      } else {
        // 如果输入无效，恢复到当前页码
        pageInput.value = props.currentPage;
      }
    };

    // 处理每页大小变化
    const handlePageSizeChange = () => {
      if (props.disabled)
        return;

      const newSize = internalPageSize.value;
      if (newSize !== props.pageSize) {
        emit('pageSizeChange', newSize);
      }
    };

    return {
      t,
      pageInput,
      internalPageSize,
      buttonClasses,
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

<template>
  <div
    class="p-4 rounded-lg flex gap-4 shadow-md items-center justify-between" :class="[
      compact ? 'bg-transparent shadow-none p-2' : 'bg-white',
      responsive ? 'flex-wrap sm:flex-nowrap' : 'flex-nowrap',
    ]"
  >
    <!-- 左侧：第一页/上一页按钮 -->
    <div class="flex gap-2">
      <button
        v-if="showFirstLast"
        :disabled="currentPage <= 1 || disabled"
        :aria-label="t('pagination.home')"
        :class="buttonClasses"
        @click="goToFirst"
      >
        <ChevronsLeft class="h-4 w-4" />
      </button>
      <button
        :disabled="currentPage <= 1 || disabled"
        :aria-label="t('pagination.prev')"
        :class="buttonClasses"
        @click="goToPrev"
      >
        <ChevronLeft class="h-4 w-4" />
      </button>
    </div>

    <!-- 中间：页码信息和跳转 -->
    <div class="flex gap-3 items-center">
      <!-- 页码显示 -->
      <span :class="compact ? 'text-xs' : 'text-sm'" class="text-gray-700">
        {{ currentPage }}/{{ totalPages }}
      </span>

      <!-- 总数显示 -->
      <span v-if="showTotal && totalItems > 0" :class="compact ? 'text-xs' : 'text-sm'" class="text-gray-500">
        (共 {{ totalItems }} 条)
      </span>

      <!-- 页码跳转输入框 -->
      <input
        v-if="showJump"
        v-model.number="pageInput"
        type="number"
        :min="1"
        :max="totalPages"
        :disabled="disabled"
        aria-label="Jump to page"
        class="text-gray-800 text-center border border-gray-300 rounded-lg shadow-inner transition-all duration-200 ease-in-out focus:outline-none hover:border-gray-400 disabled:opacity-50 disabled:cursor-not-allowed focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
        :class="[
          compact ? 'w-12 px-2 py-1 text-xs' : 'w-16 px-3 py-1.5 text-sm',
        ]"
        @change="handlePageJump" @keydown.enter="handlePageJump"
      >
    </div>

    <!-- 右侧：下一页/最后一页按钮 -->
    <div class="flex gap-2">
      <button
        :disabled="currentPage >= totalPages || disabled"
        :aria-label="t('pagination.next')"
        :class="buttonClasses"
        @click="goToNext"
      >
        <ChevronRight class="h-4 w-4" />
      </button>
      <button
        v-if="showFirstLast"
        :disabled="currentPage >= totalPages || disabled"
        :aria-label="t('pagination.last')"
        :class="buttonClasses"
        @click="goToLast"
      >
        <ChevronsRight class="h-4 w-4" />
      </button>
    </div>

    <!-- 每页大小选择器 -->
    <select
      v-if="showPageSize"
      v-model="internalPageSize"
      :disabled="disabled"
      aria-label="Select items per page"
      class="text-gray-700 border border-gray-300 rounded-md focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
      :class="[
        compact ? 'px-2 py-1 text-xs' : 'px-2 py-1 text-sm',
      ]" @change="handlePageSizeChange"
    >
      <option v-for="size in pageSizeOptions" :key="size" :value="size">
        {{ size }}
      </option>
    </select>
  </div>
</template>

<style scoped lang="postcss">
/* 保持原有样式，现在使用计算属性 */
</style>
