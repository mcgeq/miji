import { Lg } from '@/utils/debugLog';

// ==================== Constants ====================
const COMPOSABLE_MODULE = 'usePagination';

/**
 * 分页配置选项
 */
export interface PaginationOptions {
  /** 默认页码 */
  defaultPage?: number;
  /** 默认每页数量 */
  defaultPageSize?: number;
  /** 可选的每页数量选项 */
  pageSizeOptions?: number[];
  /** 是否同步到 URL 查询参数 */
  syncToUrl?: boolean;
  /** URL 参数名称 */
  urlParams?: {
    page?: string;
    pageSize?: string;
  };
  /** 页码变化回调 */
  onPageChange?: (page: number, pageSize: number) => Promise<void> | void;
}

/**
 * 分页状态和方法
 */
export interface PaginationReturn<T> {
  // 状态
  currentPage: Ref<number>;
  pageSize: Ref<number>;
  totalItems: ComputedRef<number>;
  totalPages: ComputedRef<number>;
  paginatedItems: ComputedRef<T[]>;
  loading: Ref<boolean>;

  // 计算属性
  hasNextPage: ComputedRef<boolean>;
  hasPrevPage: ComputedRef<boolean>;
  isFirstPage: ComputedRef<boolean>;
  isLastPage: ComputedRef<boolean>;
  pageRange: ComputedRef<number[]>;

  // 导航方法
  setPage: (page: number) => Promise<void>;
  nextPage: () => Promise<void>;
  prevPage: () => Promise<void>;
  firstPage: () => Promise<void>;
  lastPage: () => Promise<void>;
  setPageSize: (size: number) => Promise<void>;

  // 工具方法
  refresh: () => Promise<void>;
}

/**
 * 通用分页 Composable
 * 提供客户端分页功能
 *
 * @param items - 返回所有项目的函数
 * @param options - 分页配置选项
 *
 * @example
 * ```typescript
 * const pagination = usePagination(
 *   () => allItems.value,
 *   {
 *     defaultPageSize: 20,
 *     syncToUrl: true,
 *     onPageChange: async (page, pageSize) => {
 *       await fetchItems({ page, pageSize });
 *     },
 *   }
 * );
 *
 * // 在模板中使用
 * <div v-for="item in pagination.paginatedItems.value" :key="item.id">
 *   {{ item.name }}
 * </div>
 *
 * <button @click="pagination.prevPage" :disabled="!pagination.hasPrevPage.value">上一页</button>
 * <button @click="pagination.nextPage" :disabled="!pagination.hasNextPage.value">下一页</button>
 * ```
 */
export function usePagination<T>(
  items: () => T[],
  options: PaginationOptions | number = {},
): PaginationReturn<T> {
  // 兼容旧的 API（直接传入 pageSize 数字）
  const opts: PaginationOptions =
    typeof options === 'number' ? { defaultPageSize: options } : options;

  const {
    defaultPage = 1,
    defaultPageSize = 10,
    pageSizeOptions = [10, 20, 50, 100],
    syncToUrl = false,
    urlParams = { page: 'page', pageSize: 'pageSize' },
    onPageChange,
  } = opts;

  // 状态
  const currentPage = ref(defaultPage);
  const pageSize = ref(defaultPageSize);
  const loading = ref(false);

  // 从 URL 初始化（如果启用）
  if (syncToUrl && typeof window !== 'undefined') {
    const urlSearchParams = new URLSearchParams(window.location.search);
    const urlPage = urlSearchParams.get(urlParams.page || 'page');
    const urlPageSize = urlSearchParams.get(urlParams.pageSize || 'pageSize');

    if (urlPage) {
      const parsedPage = Number.parseInt(urlPage, 10);
      if (!Number.isNaN(parsedPage) && parsedPage > 0) {
        currentPage.value = parsedPage;
      }
    }

    if (urlPageSize) {
      const parsedSize = Number.parseInt(urlPageSize, 10);
      if (!Number.isNaN(parsedSize) && pageSizeOptions.includes(parsedSize)) {
        pageSize.value = parsedSize;
      }
    }
  }

  // 计算属性
  const totalItems = computed(() => items().length);
  const totalPages = computed(() => Math.max(1, Math.ceil(totalItems.value / pageSize.value)));

  const paginatedItems = computed(() => {
    const start = (currentPage.value - 1) * pageSize.value;
    const end = start + pageSize.value;
    return items().slice(start, end);
  });

  const hasNextPage = computed(() => currentPage.value < totalPages.value);
  const hasPrevPage = computed(() => currentPage.value > 1);
  const isFirstPage = computed(() => currentPage.value === 1);
  const isLastPage = computed(() => currentPage.value === totalPages.value);

  /**
   * 生成页码范围（用于分页器显示）
   * 显示当前页前后各2页，共5页
   */
  const pageRange = computed(() => {
    const total = totalPages.value;
    const current = currentPage.value;
    const range: number[] = [];

    let start = Math.max(1, current - 2);
    const end = Math.min(total, start + 4);

    // 调整起始位置以确保显示5个页码（如果可能）
    if (end - start < 4) {
      start = Math.max(1, end - 4);
    }

    for (let i = start; i <= end; i++) {
      range.push(i);
    }

    return range;
  });

  // ==================== URL 同步 ====================

  /**
   * 同步状态到 URL
   */
  function syncToUrlParams() {
    if (!syncToUrl || typeof window === 'undefined') return;

    const url = new URL(window.location.href);
    url.searchParams.set(urlParams.page || 'page', String(currentPage.value));
    url.searchParams.set(urlParams.pageSize || 'pageSize', String(pageSize.value));

    window.history.replaceState({}, '', url.toString());
  }

  // ==================== 导航方法 ====================

  /**
   * 设置页码
   */
  async function setPage(page: number) {
    const validPage = Math.max(1, Math.min(page, totalPages.value));

    if (validPage === currentPage.value) return;

    Lg.d(COMPOSABLE_MODULE, '设置页码', { from: currentPage.value, to: validPage });
    currentPage.value = validPage;
    syncToUrlParams();

    if (onPageChange) {
      loading.value = true;
      try {
        await onPageChange(validPage, pageSize.value);
      } finally {
        loading.value = false;
      }
    }
  }

  /**
   * 下一页
   */
  async function nextPage() {
    if (hasNextPage.value) {
      await setPage(currentPage.value + 1);
    }
  }

  /**
   * 上一页
   */
  async function prevPage() {
    if (hasPrevPage.value) {
      await setPage(currentPage.value - 1);
    }
  }

  /**
   * 第一页
   */
  async function firstPage() {
    await setPage(1);
  }

  /**
   * 最后一页
   */
  async function lastPage() {
    await setPage(totalPages.value);
  }

  /**
   * 设置每页数量
   */
  async function setPageSize(size: number) {
    if (size === pageSize.value) return;

    Lg.d(COMPOSABLE_MODULE, '设置每页数量', { from: pageSize.value, to: size });
    pageSize.value = size;
    currentPage.value = 1; // 重置到第一页
    syncToUrlParams();

    if (onPageChange) {
      loading.value = true;
      try {
        await onPageChange(1, size);
      } finally {
        loading.value = false;
      }
    }
  }

  /**
   * 刷新当前页
   */
  async function refresh() {
    if (onPageChange) {
      loading.value = true;
      try {
        await onPageChange(currentPage.value, pageSize.value);
      } finally {
        loading.value = false;
      }
    }
  }

  // ==================== 监听器 ====================

  // 当数据源变化时，确保当前页有效
  watch(items, () => {
    if (currentPage.value > totalPages.value) {
      currentPage.value = Math.max(1, totalPages.value);
    }
  });

  return {
    // 状态
    currentPage,
    pageSize,
    totalItems,
    totalPages,
    paginatedItems,
    loading,

    // 计算属性
    hasNextPage,
    hasPrevPage,
    isFirstPage,
    isLastPage,
    pageRange,

    // 导航方法
    setPage,
    nextPage,
    prevPage,
    firstPage,
    lastPage,
    setPageSize,

    // 工具方法
    refresh,
  };
}
