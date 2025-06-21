<!-- src/components/TodoItem.svelte -->
<script lang="ts">
import { StatusSchema } from '@/lib/schema/common';
import type { TodoRemain } from '@/lib/schema/todos';
import { escapeHTML } from '@/lib/utils/sanitize';
import { CheckCircle, Circle, Pencil, Plus, Trash2 } from '@lucide/svelte';
import { t } from 'svelte-i18n';

let {
  todo = $bindable({} as TodoRemain),
  onToggle = () => {},
  onRemove = () => {},
  onEdit = () => {},
} = $props<import('@/types/todos').TodoItemProps>();

let completed = $derived(todo.status === StatusSchema.enum.Completed);
let maxChars = $state(18);
let displayText = $derived.by(() => {
  return todo.title.length > maxChars
    ? `${todo.title.slice(0, maxChars)}...`
    : todo.title;
});

let isRotatingAdd = $state(false);
let isRotatingEdit = $state(false);
let isRotatingRemove = $state(false);
function handleRotate(button: 'add' | 'edit' | 'remove', callback: () => void) {
  if (completed) {
    callback(); // 如果任务已完成，直接执行回调
    return;
  }

  // 定义按钮类型与旋转状态的映射关系
  const rotationMap = {
    add: isRotatingAdd,
    edit: isRotatingEdit,
    remove: isRotatingRemove,
  };

  // 从映射中获取对应的状态变量
  const key = button;

  // 设置旋转状态为 true
  (rotationMap[key] as boolean) = true;

  callback(); // 执行操作（如编辑、添加、删除）

  // 在动画结束后重置旋转状态
  setTimeout(() => {
    (rotationMap[key] as boolean) = false;
  }, 500);
}

const priorityChar = (priority: string) => {
  switch (priority.toUpperCase()) {
    case 'MEDIUM':
      return $t('todos.priority.medium');
    case 'HIGH':
      return $t('todos.priority.high');
    case 'URGENT':
      return $t('todos.priority.urgent');
    default:
      return $t('todos.priority.low');
  }
};
</script>

<div
  class="p-4 bg-white rounded-2xl border border-gray-200 flex flex-col h-18 mb-1 relative">
<!-- 优先级标签 -->
{#if todo.priority}
<div class="absolute left-1 top-1 w-4 h-4 rounded-full flex items-center justify-center text-xs font-medium
  transition-all duration-300 hover:scale-110
  bg-opacity-80 backdrop-blur-sm
  [border:2px_solid_transparent] [border-image:linear-gradient(45deg,var(--priority-gradient))] [border-image-slice:1]
  shadow-[0_0_12px_rgba(0,0,0,0.1)] dark:shadow-[0_0_12px_rgba(255,255,255,0.1)]
"
  class:bg-gradient-to-br={
    todo.priority === 'Low'
      ? 'from-green-200 to-emerald-100'
      : todo.priority === 'Medium'
        ? 'from-yellow-200 to-amber-100'
        : todo.priority === 'High'
          ? 'from-red-200 to-rose-100'
          : 'from-red-300 to-rose-200'
  }
  class:text-green-800={todo.priority === 'Low'}
  class:text-yellow-800={todo.priority === 'Medium'}
  class:text-red-800={todo.priority === 'High'}
  class:text-red-900={todo.priority === 'Urgent'}
  >
  {priorityChar(todo.priority)}
</div>
{/if}
  <!-- 上半部分：主内容 -->
  <div class="flex items-center justify-between flex-1">
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="flex items-center focus:outline-none"
        onclick={onToggle}
        aria-pressed={completed}
      >
        {#if completed}
          <CheckCircle class="w-5 h-5 text-green-500" />
        {:else}
          <Circle class="w-5 h-5 text-gray-400" />
        {/if}
      </button>
      <span
        class="text-left text-sm leading-snug line-clamp-1"
        class:text-gray-400={completed}
        title={todo.title}
      >
        {@html escapeHTML(displayText)}
      </span>
    </div>

    <div class="flex items-center gap-3">  <!-- 右侧按钮，垂直居中 -->
      <button
        type="button"
        onclick={() => !completed && handleRotate('edit', onEdit)}
        aria-label="Edit task"
        class="transition
         text-gray-400
         hover:text-blue-500
         disabled:(text-gray-300 cursor-not-allowed hover:text-gray-300)"
        disabled={completed}
      >
        <span class:rotating={isRotatingEdit && !completed}>
          <Pencil class="w-4 h-4" />
        </span>
        <span class="sr-only">Edit</span>
      </button>

      <button
        type="button"
        aria-label="Add task"
        class="transition
         text-blue-500
         hover:text-blue-700
         disabled:(text-gray-300 cursor-not-allowed hover:text-gray-300)"
      >
        <span class:rotating={isRotatingAdd}>
          <Plus class="w-5 h-5" />
        </span>
        <span class="sr-only">Add</span>
      </button>

      <button
        type="button"
        onclick={() => !completed && handleRotate('remove', onRemove)}
        aria-label="Delete task"
        disabled={completed}
        class="transition
         text-red-400
         hover:text-red-600
         disabled:(text-gray-300 cursor-not-allowed hover:text-gray-300)"
      >
        <span class:rotating={isRotatingRemove && !completed}>
          <Trash2 class="w-5 h-5" />
        </span>
        <span class="sr-only">Delete</span>
      </button>
    </div>
  </div>

  <!-- 底部右下角 dueAt -->
  {#if todo.dueAt}
    <div class="text-xs text-gray-500 absolute right-4 bottom-1">
      {todo.remainingTime}
    </div>
  {/if}
</div>


<style>
  @keyframes spin {
    from { transform: rotate(0deg);}
    to { transform: rotate(360deg);}
  }
  .rotating {
    display: inline-block;
    animation: spin 0.5s linear !important;
  }

  button > span {
    display: inline-block;
  }

  button[disabled] > span {
    animation: none !important;
  }

  button:hover > span {
    animation: spin 0.5s linear;
  }
</style>
