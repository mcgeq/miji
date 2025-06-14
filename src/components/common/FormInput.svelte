
<script lang="ts">
import FloatingErrorTip from './FloatingErrorTip.svelte';

export let name: string;
export let type = 'text';
export let placeholder = '';
export let disabled = false;
export let errors: Record<string, string[] | null> = {};
$: errorMsg = errors?.[name]?.[0] ?? '';
</script>

<div class="relative">
  <input
    id={name}
    name={name}
    {type}
    {placeholder}
    {disabled}
    class="w-full px-4 py-2 rounded-md border border-gray-300 dark:border-gray-700
           bg-white dark:bg-gray-900 text-gray-900 dark:text-white
           placeholder-gray-400 dark:placeholder-gray-500
           focus:(outline-none ring-2 ring-blue-500 border-transparent)
           transition duration-200 disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
  />

  <!-- 右侧错误提示 -->
  <FloatingErrorTip visible={!!errorMsg} message={errorMsg} />
</div>
