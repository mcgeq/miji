import type { Status } from '@/schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import { useTodoStore } from '@/stores/todoStore';

/**
 * Todo 操作的组合式函数
 * 封装常用的 todo 操作逻辑
 */
export function useTodoActions() {
  const todoStore = useTodoStore();

  /**
   * 创建新的待办任务
   */
  async function createTodo(todo: TodoCreate): Promise<Todo> {
    return await todoStore.createTodo(todo);
  }

  /**
   * 更新待办任务
   */
  async function updateTodo(serialNum: string, update: TodoUpdate): Promise<Todo> {
    return await todoStore.updateTodo(serialNum, update);
  }

  /**
   * 删除待办任务
   */
  async function deleteTodo(serialNum: string): Promise<void> {
    return await todoStore.deleteTodo(serialNum);
  }

  /**
   * 切换待办任务的完成状态
   */
  async function toggleTodo(serialNum: string, status: Status): Promise<Todo> {
    return await todoStore.toggleTodo(serialNum, status);
  }

  /**
   * 标记待办任务为完成
   */
  async function completeTodo(serialNum: string): Promise<Todo> {
    return await todoStore.toggleTodo(serialNum, 'Completed');
  }

  /**
   * 标记待办任务为未完成
   */
  async function uncompleteTodo(serialNum: string): Promise<Todo> {
    return await todoStore.toggleTodo(serialNum, 'NotStarted');
  }

  /**
   * 归档待办任务
   */
  async function archiveTodo(serialNum: string): Promise<Todo> {
    return await todoStore.updateTodo(serialNum, { isArchived: true });
  }

  /**
   * 取消归档待办任务
   */
  async function unarchiveTodo(serialNum: string): Promise<Todo> {
    return await todoStore.updateTodo(serialNum, { isArchived: false });
  }

  /**
   * 置顶待办任务
   */
  async function pinTodo(serialNum: string): Promise<Todo> {
    return await todoStore.updateTodo(serialNum, { isPinned: true });
  }

  /**
   * 取消置顶待办任务
   */
  async function unpinTodo(serialNum: string): Promise<Todo> {
    return await todoStore.updateTodo(serialNum, { isPinned: false });
  }

  /**
   * 批量完成待办任务
   */
  async function batchCompleteTodos(serialNums: string[]): Promise<void> {
    await Promise.all(serialNums.map(id => completeTodo(id)));
  }

  /**
   * 批量删除待办任务
   */
  async function batchDeleteTodos(serialNums: string[]): Promise<void> {
    await Promise.all(serialNums.map(id => deleteTodo(id)));
  }

  /**
   * 批量归档待办任务
   */
  async function batchArchiveTodos(serialNums: string[]): Promise<void> {
    await Promise.all(serialNums.map(id => archiveTodo(id)));
  }

  /**
   * 创建子任务
   */
  async function createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
    return await todoStore.createSubtask(parentId, todo);
  }

  /**
   * 获取子任务列表
   */
  async function listSubtasks(parentId: string): Promise<Todo[]> {
    return await todoStore.listSubtasks(parentId);
  }

  /**
   * 快速创建待办任务（使用默认值）
   */
  async function quickCreateTodo(title: string): Promise<Todo> {
    const defaultTodo: TodoCreate = {
      title,
      description: null,
      dueAt: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), // 默认明天到期
      priority: 'Medium',
      status: 'NotStarted',
      repeatPeriodType: 'None',
      repeat: { type: 'None' },
      completedAt: null,
      assigneeId: null,
      progress: 0,
      location: null,
      ownerId: null,
      isArchived: false,
      isPinned: false,
      estimateMinutes: null,
      reminderCount: 0,
      parentId: null,
      subtaskOrder: null,
      reminderEnabled: false,
      reminderAdvanceValue: null,
      reminderAdvanceUnit: null,
      lastReminderSentAt: null,
      reminderFrequency: null,
      snoozeUntil: null,
      reminderMethods: null,
      timezone: null,
      smartReminderEnabled: false,
      locationBasedReminder: false,
      weatherDependent: false,
      priorityBoostEnabled: false,
      batchReminderId: null,
    };
    return await createTodo(defaultTodo);
  }

  return {
    // 基础操作
    createTodo,
    updateTodo,
    deleteTodo,
    toggleTodo,

    // 快捷操作
    completeTodo,
    uncompleteTodo,
    archiveTodo,
    unarchiveTodo,
    pinTodo,
    unpinTodo,

    // 批量操作
    batchCompleteTodos,
    batchDeleteTodos,
    batchArchiveTodos,

    // 子任务操作
    createSubtask,
    listSubtasks,

    // 工具方法
    quickCreateTodo,

    // 状态
    loading: computed(() => todoStore.loading),
    error: computed(() => todoStore.error),
  };
}
