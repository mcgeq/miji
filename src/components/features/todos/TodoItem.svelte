<!-- src/components/TodoItem.svelte -->
<script lang="ts">
import { StatusSchema } from '@/lib/schema/common';
import type { TodoRemain } from '@/lib/schema/todos';
import { escapeHTML } from '@/lib/utils/sanitize';
import { CheckCircle, Circle, Pencil, Plus, Trash2 } from '@lucide/svelte';

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
    callback();
    return;
  }
  if (button === 'add') isRotatingAdd = true;
  if (button === 'edit') isRotatingEdit = true;
  if (button === 'remove') isRotatingRemove = true;
  callback();
  setTimeout(() => {
    if (button === 'add') isRotatingAdd = false;
    if (button === 'edit') isRotatingEdit = false;
    if (button === 'remove') isRotatingRemove = false;
  }, 500);
}
</script>

<div
  class="p-4 bg-white rounded-2xl border border-gray-200 flex flex-col h-18 mb-1 relative">
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
        disabled={completed}
        class="transition
         text-blue-500
         hover:text-blue-700
         disabled:(text-gray-300 cursor-not-allowed hover:text-gray-300)"
      >
        <span class:rotating={isRotatingAdd && !completed}>
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

  button:hover > span {
    animation: spin 0.5s linear;
  }

  button:not(:disabled):hover > span {
    animation: spin 0.5s linear;
  }

button:disabled > span.rotating {
  animation: none !important;
}
</style>
