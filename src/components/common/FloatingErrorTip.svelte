<script lang="ts">
export let message = '';
export let visible = false;
</script>

{#if visible && message}
  <div
    class="absolute top-1/2 right-2 transform -translate-y-1/2 text-xs text-red-500
           whitespace-nowrap pointer-events-none select-none z-10"
  >
    {message}
  </div>
{/if}
