import { SortDirection } from '@/schema/common';
import type { SortOptions } from '@/schema/common';

// 定义 useSort composable
export function useSort(defaultSortOptions: Partial<SortOptions> = {}) {
  // 默认值
  const sortBy = ref<string | undefined>(defaultSortOptions.sortBy);
  const sortDir = ref<SortDirection>(defaultSortOptions.sortDir ?? SortDirection.Desc);
  const desc = ref<boolean>(defaultSortOptions.desc ?? true);
  const customOrderBy = ref<string | undefined>(defaultSortOptions.customOrderBy);

  // 响应式的 sortOptions 对象
  const sortOptions = computed<SortOptions>(() => ({
    sortBy: sortBy.value,
    sortDir: sortDir.value,
    desc: desc.value,
    customOrderBy: customOrderBy.value,
  }));

  // 设置排序字段
  function setSortBy(field: string | undefined) {
    sortBy.value = field;
  }

  // 设置排序方向
  function setSortDirection(direction: SortDirection) {
    sortDir.value = direction;
    desc.value = direction === SortDirection.Desc;
  }

  // 设置自定义排序 SQL
  function setCustomOrderBy(order: string | undefined) {
    customOrderBy.value = order;
  }

  // 切换排序方向（Asc <-> Desc）
  function toggleSortDirection() {
    sortDir.value = sortDir.value === SortDirection.Asc ? SortDirection.Desc : SortDirection.Asc;
    desc.value = sortDir.value === SortDirection.Desc;
  }

  // 重置为默认排序选项
  function resetSort() {
    sortBy.value = defaultSortOptions.sortBy;
    sortDir.value = defaultSortOptions.sortDir ?? SortDirection.Desc;
    desc.value = defaultSortOptions.desc ?? true;
    customOrderBy.value = defaultSortOptions.customOrderBy;
  }

  return {
    sortBy,
    sortDir,
    desc,
    customOrderBy,
    sortOptions,
    setSortBy,
    setSortDirection,
    setCustomOrderBy,
    toggleSortDirection,
    resetSort,
  };
}
