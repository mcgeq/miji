<!-- src/components/TodoInput.svelte -->

<script lang="ts">
import { createTypedEmit } from '@/lib/utils/typedEmit';
import type { TodoInputEvents } from '@/types/events';
import { useTodoInput } from '@/lib/hooks/useTodoInput';

const emit = createTypedEmit<TodoInputEvents>();

let rootEl: HTMLDivElement;

// 使用 Hook 管理输入值和事件触发
const { value, setValue, handleAdd } = useTodoInput(emit);

function onInput(event: Event) {
  setValue((event.target as HTMLInputElement).value);
}

function onKeydown(event: KeyboardEvent) {
  if (event.key === 'Enter') {
    handleAdd(rootEl);
  }
}
</script>

<div
  bind:this={rootEl}
  class="flex items-center gap-2 p-3 rounded-xl bg-gradient-to-r from-blue-50 to-white shadow-inner"
>
  <div class="i-heroicons-plus-circle-20-solid text-blue-500 w-5 h-5"></div>

  <input
    value={value}
    on:input={onInput}
    on:keydown={onKeydown}
    type="text"
    placeholder="Add a new task..."
    class="flex-1 bg-transparent outline-none text-base placeholder-gray-400"
  />

  <button
    on:click={() => handleAdd(rootEl)}
    class="px-4 py-1 bg-blue-500 text-white text-sm font-semibold rounded-full hover:bg-blue-600 transition"
  >
    Add
  </button>
</div>
