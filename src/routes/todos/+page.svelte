<!-- src/routes/todo/+page.svelte -->
<script lang="ts">
import TodoInput from '@/components/features/todos/TodoInput.svelte';
import TodoList from '@/components/features/todos/TodoList.svelte';
import { PrioritySchema, StatusSchema } from '@/lib/schema/common';
import type { Todo } from '@/lib/schema/todos';
import {
  getEndOfTodayISOWithOffset,
  getLocalISODateTimeWithOffset,
} from '@/lib/utils/date';
import { uuid } from '@/lib/utils/uuid';
import type { TodoInputEvents, TodoListEvents } from '@/types/events';

// 初始化任务列表，真实项目从后端或store获取
let todos: Todo[] = [];

// 处理新增任务
function handleAdd(event: CustomEvent<TodoInputEvents['add']>) {
  const { text } = event.detail;
  const now = getLocalISODateTimeWithOffset();
  const newTodo: Todo = {
    serial_num: uuid(38),
    title: text,
    description: null,
    created_at: now,
    updated_at: null,
    due_at: getEndOfTodayISOWithOffset(),
    priority: PrioritySchema.enum.Medium,
    status: StatusSchema.enum.NotStarted,
    repeat: null,
    completed_at: null,
    assignee_id: null,
    progress: 0,
    location: null,
    owner_id: null,
    is_archived: false,
    is_pinned: false,
    estimate_minutes: null,
    reminder_count: 0,
    parent_id: null,
    subtask_order: null,
  };

  todos = [newTodo, ...todos];
}

// 统一事件处理函数，传给 TodoList 组件
function dispatch<K extends keyof TodoListEvents>(
  type: K,
  detail: TodoListEvents[K],
) {
  const upNow = getLocalISODateTimeWithOffset();
  switch (type) {
    case 'toggle':
      todos = todos.map((todo) =>
        todo.serial_num.toString() === detail.serial_num
          ? {
              ...todo,
              status:
                todo.status === StatusSchema.enum.Completed
                  ? StatusSchema.enum.NotStarted
                  : StatusSchema.enum.Completed,
              completed_at:
                todo.status === StatusSchema.enum.Completed ? null : upNow,
              updated_at: upNow,
            }
          : todo,
      );
      break;

    case 'remove':
      todos = todos.filter(
        (todo) => todo.serial_num.toString() !== detail.serial_num,
      );
      break;

    default:
      break;
  }
}
</script>

<main class="max-w-xl mx-auto p-4">
  <!-- TodoInput 监听 add 事件 -->
  <TodoInput on:add={handleAdd} />

  <!-- TodoList 传入 todos 和 dispatch 处理 toggle/remove -->
  <TodoList {todos} {dispatch} />
</main>
