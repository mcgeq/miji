import { SortDirection } from '@/schema/common';
import { useTodoStore } from '@/stores/todoStore';
import type { DateRange, Status } from '@/schema/common';
import type { TodoFilters } from '@/services/todo';

/**
 * Todo 筛选和排序的组合式函数
 * 封装筛选、排序相关的逻辑
 */
export function useTodoFilter() {
  const todoStore = useTodoStore();

  /**
   * 设置筛选器
   */
  function setFilter(filters: Partial<TodoFilters>) {
    todoStore.setFilter(filters);
  }

  /**
   * 清除所有筛选
   */
  function clearFilter() {
    todoStore.clearFilter();
  }

  /**
   * 按状态筛选
   */
  function filterByStatus(status: Status | null) {
    todoStore.setStatusFilter(status);
  }

  /**
   * 按日期范围筛选
   */
  function filterByDateRange(dateRange: DateRange | null) {
    todoStore.setDateRangeFilter(dateRange);
  }

  /**
   * 设置排序选项
   */
  function setSortOptions(sortBy: string, sortDir: SortDirection) {
    todoStore.setSortOptions(sortBy, sortDir);
  }

  /**
   * 清除排序
   */
  function clearSort() {
    todoStore.clearSort();
  }

  /**
   * 预设筛选：显示所有待办
   */
  function showAll() {
    clearFilter();
  }

  /**
   * 预设筛选：只显示未完成的待办
   */
  function showIncomplete() {
    setFilter({
      status: 'NotStarted',
    });
  }

  /**
   * 预设筛选：只显示已完成的待办
   */
  function showCompleted() {
    filterByStatus('Completed');
  }

  /**
   * 预设筛选：只显示进行中的待办
   */
  function showInProgress() {
    filterByStatus('InProgress');
  }

  /**
   * 预设筛选：显示今日待办
   */
  function showToday() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    filterByDateRange({
      start: today.toISOString(),
      end: tomorrow.toISOString(),
    });
  }

  /**
   * 预设筛选：显示本周待办
   */
  function showThisWeek() {
    const today = new Date();
    const dayOfWeek = today.getDay();
    const startOfWeek = new Date(today);
    startOfWeek.setDate(today.getDate() - dayOfWeek);
    startOfWeek.setHours(0, 0, 0, 0);

    const endOfWeek = new Date(startOfWeek);
    endOfWeek.setDate(startOfWeek.getDate() + 7);

    filterByDateRange({
      start: startOfWeek.toISOString(),
      end: endOfWeek.toISOString(),
    });
  }

  /**
   * 预设筛选：显示本月待办
   */
  function showThisMonth() {
    const today = new Date();
    const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
    const endOfMonth = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59);

    filterByDateRange({
      start: startOfMonth.toISOString(),
      end: endOfMonth.toISOString(),
    });
  }

  /**
   * 预设排序：按优先级排序
   */
  function sortByPriority(desc = true) {
    setSortOptions('priority', desc ? SortDirection.Desc : SortDirection.Asc);
  }

  /**
   * 预设排序：按截止日期排序
   */
  function sortByDueDate(desc = false) {
    setSortOptions('dueAt', desc ? SortDirection.Desc : SortDirection.Asc);
  }

  /**
   * 预设排序：按创建时间排序
   */
  function sortByCreatedAt(desc = true) {
    setSortOptions('createdAt', desc ? SortDirection.Desc : SortDirection.Asc);
  }

  /**
   * 预设排序：按更新时间排序
   */
  function sortByUpdatedAt(desc = true) {
    setSortOptions('updatedAt', desc ? SortDirection.Desc : SortDirection.Asc);
  }

  return {
    // 基础筛选方法
    setFilter,
    clearFilter,
    filterByStatus,
    filterByDateRange,

    // 预设筛选
    showAll,
    showIncomplete,
    showCompleted,
    showInProgress,
    showToday,
    showThisWeek,
    showThisMonth,

    // 排序方法
    setSortOptions,
    clearSort,
    sortByPriority,
    sortByDueDate,
    sortByCreatedAt,
    sortByUpdatedAt,

    // 计算属性 - 从 store 获取
    filteredTodos: computed(() => todoStore.filteredTodos),
    overdueTodos: computed(() => todoStore.overdueTodos),
    todayTodos: computed(() => todoStore.todayTodos),
    upcomingTodos: computed(() => todoStore.upcomingTodos),
    completedTodos: computed(() => todoStore.completedTodos),
    pinnedTodos: computed(() => todoStore.pinnedTodos),

    // 当前筛选状态
    currentFilters: computed(() => todoStore.filters),
    currentSortBy: computed(() => todoStore.sortBy),
    currentSortDir: computed(() => todoStore.sortDir),
  };
}
