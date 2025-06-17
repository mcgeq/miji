<!-- src/components/TodoItem.svelte -->

<script lang="ts">
let {
  text,
  completed,
  onToggle = () => {},
  onRemove = () => {},
} = $props<import('@/types/todos').TodoItemProps>();
</script>

<div
  class="flex items-center justify-between p-2 border-b border-gray-200"
>
  <h3>Item</h3>
  <div class="flex items-center gap-2">
    <input type="checkbox" checked={completed} onclick={onToggle} />
    <span class={completed ? 'line-through text-gray-400' : ''}>{text}</span>
  </div>

  <button
    onclick={onRemove}
    aria-label="Delete task"
    class="text-red-400 hover:text-red-600"
  >
    <i class="w-5 h-5" aria-hidden="true"></i>
    <span class="sr-only">Delete</span>
  </button>
</div>
