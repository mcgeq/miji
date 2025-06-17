<!-- src/components/TodoInput.svelte -->
<script lang="ts">
import { t } from 'svelte-i18n';
import { Plus } from '@lucide/svelte';
let { newT = $bindable(''), handleAdd } =
  $props<import('@/types/todos').TodoInputProps>();
</script>


<div
  class="flex items-center gap-2 p-3 rounded-xl bg-gradient-to-r from-blue-50 to-white shadow-inner"
>
  <input
    bind:value={newT}
    maxlength="1000"
    type="text"
    placeholder={$t('todos.input_place')}
    class="flex-1 bg-transparent outline-none text-base placeholder-gray-400"
  />

  <button
    onclick={() => {
      if (newT.trim()) {
        handleAdd(newT);
      }
    }}
    class="px-3 py-1 bg-blue-500 text-white text-sm font-semibold rounded-full hover:bg-blue-600 transition flex items-center gap-1"
  >
    <Plus class="w-4 h-4" />
    Add
  </button>
</div>
