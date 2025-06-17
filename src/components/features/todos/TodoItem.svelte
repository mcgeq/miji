<!-- src/components/TodoItem.svelte -->

<script lang="ts">
import { CheckCircle, Circle, Trash2 } from '@lucide/svelte';

let {
  text,
  completed,
  onToggle = () => {},
  onRemove = () => {},
} = $props<import('@/types/todos').TodoItemProps>();
</script>

<div class="flex items-center justify-between p-2 border-b border-gray-200">
  <button
    type="button"
    class="flex items-center gap-2 focus:outline-none"
    onclick={onToggle}
    aria-pressed={completed}
  >
    {#if completed}
      <CheckCircle class="w-5 h-5 text-green-500" />
    {:else}
      <Circle class="w-5 h-5 text-gray-400" />
    {/if}
    <span class={completed ? 'line-through text-gray-400' : ''}>{text}</span>
  </button>

  <button
    type="button"
    onclick={onRemove}
    aria-label="Delete task"
    class="text-red-400 hover:text-red-600"
  >
    <Trash2 class="w-5 h-5" />
    <span class="sr-only">Delete</span>
  </button>
</div>
