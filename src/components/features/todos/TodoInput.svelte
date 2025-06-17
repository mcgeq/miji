<!-- src/components/TodoInput.svelte -->
<script lang="ts">
import { t } from 'svelte-i18n';

let { newT = $bindable(''), handleAdd } =
  $props<import('@/types/todos').TodoInputProps>();
</script>

<div
  class="flex items-center gap-2 p-3 rounded-xl bg-gradient-to-r from-blue-50 to-white shadow-inner"
>
  <div class=" text-blue-500 w-5 h-5"></div>

  <input
    bind:value={newT}
    maxlength="1000"
    type="text"
    placeholder={$t('todos.input_place')}
    class="flex-1 bg-transparent outline-none text-base placeholder-gray-400"
  />

  <button
    onclick={() => {
      if(newT.trim()){
        handleAdd(newT)
      }
    }}
    class="px-4 py-1 bg-blue-500 text-white text-sm font-semibold rounded-full hover:bg-blue-600 transition"
  >
    Add
  </button>
</div>
