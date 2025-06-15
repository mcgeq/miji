<script lang="ts">
import { storeStart } from '@/lib/stores';
import { Lg } from '@/lib/utils/debugLog';
import { onMount } from 'svelte';
import { Toaster } from 'svelte-sonner';
onMount(async () => {
  try {
    storeStart();
  } catch (error) {
    Lg.e('Routes Store initialization', error);
  }
});
</script>

<slot />
<Toaster richColors position="top-center" duration={3500} expand closeButton theme="system"/>
