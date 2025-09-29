import type { PagedMapResult, PagedResult } from '@/services/money/baseManager';

export function usePaginationFilters<T>(
  items: () => PagedResult<T> | PagedMapResult<T>,
  defaultPageSize = 10,
) {
  const paged = computed(() => items());
  const currentPage = ref(paged.value.currentPage);
  const pageSize = ref(defaultPageSize);

  const totalItems = computed(() => paged.value.totalCount);
  const totalPages = computed(() => paged.value.totalPages);
  const paginatedItems = computed(() => paged.value.rows);

  // 当数据源变化时，自动回第一页
  watch(items, () => {
    currentPage.value = paged.value.currentPage;
  });

  watch(pageSize, () => {
    currentPage.value = 1;
  });

  function setPage(page: number) {
    currentPage.value = page;
  }

  return {
    currentPage,
    pageSize,
    totalItems,
    totalPages,
    paginatedItems,
    setPage,
  };
}
