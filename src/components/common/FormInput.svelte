<script lang="ts">
export let name: string;
export let type = 'text';
export let placeholder = '';
export let disabled = false;
export let errors: Record<string, string[] | null> = {};
</script>

<div class="flex flex-col gap-1">
  <input
    class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
    {type}
    {name}
    {placeholder}
    {disabled}
  />
  {#if errors?.[name]?.length}
    <p class="text-red-500 text-sm"> {errors[name]?.[0]} </p>
  {/if}
</div>
