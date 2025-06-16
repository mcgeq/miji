<!-- src/components/TodoItem.svelte -->

<script lang="ts">
import { createTypedEmit } from '@/lib/utils/typedEmit';
import type { TodoListEvents } from '@/types/events';

const emit = createTypedEmit<TodoListEvents>();

export let serial_num: string;
export let text: string;
export let completed: boolean;

let rootEl: HTMLDivElement;

const toggle = () => emit(rootEl, 'toggle', { serial_num });
const remove = () => emit(rootEl, 'remove', { serial_num });
</script>

<div
  bind:this={rootEl}
  class="flex items-center justify-between p-2 border-b border-gray-200"
>
  <div class="flex items-center gap-2">
    <input type="checkbox" checked={completed} on:change={toggle} />
    <span class={completed ? 'line-through text-gray-400' : ''}>{text}</span>
  </div>

  <button
    on:click={remove}
    aria-label="Delete task"
    class="text-red-400 hover:text-red-600"
  >
    <i class="i-heroicons-trash-20-solid w-5 h-5" aria-hidden="true"></i>
    <span class="sr-only">Delete</span>
  </button>
</div>
