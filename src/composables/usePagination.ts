export function usePagination<T>(items: () => T[], defaultPageSize = 10) {
  const currentPage = ref(1);
  const pageSize = ref(defaultPageSize);

  const totalItems = ref(items().length);
  const totalPages = ref(Math.ceil(totalItems.value / pageSize.value));

  const paginatedItems = computed(() => {
    const start = (currentPage.value - 1) * pageSize.value;
    const end = start + pageSize.value;
    return items().slice(start, end);
  });

  // 当数据源变化时，自动回第一页
  watch(items, () => {
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
