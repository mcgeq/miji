<!-- src/routes/+layout.svelte -->
<script lang="ts">
import { storeStart } from '$lib/stores';
import { isAuthenticated } from '$lib/stores/auth';
import { Lg } from '$lib/utils/debugLog';
import { beforeNavigate } from '$app/navigation';
import { goto } from '$app/navigation';
import { onMount } from 'svelte';
import { t } from 'svelte-i18n';
import { toast, Toaster } from 'svelte-sonner';
import { checkAndCleanSession } from '@/lib/api/auth';

let isLoading = true;
let isAuth = false;
let hasRedirected = false;

onMount(async () => {
  try {
    await storeStart();
    await checkAndCleanSession();
    isAuth = await isAuthenticated();
    Lg.i('Auth status on mount:', isAuth);

    if (!isAuth && !hasRedirected) {
      hasRedirected = true;
      toast.warning($t('errors.please_login'));
      goto('/auth/login');
      return;
    }
    goto('/todos');
    return;
  } catch (error) {
    Lg.e('Routes Store initialization', error);
    toast.error($t('errors.init_failed'));
  } finally {
    isLoading = false;
  }
});

beforeNavigate(async ({ to, cancel }) => {
  if (!to?.url.pathname) return;

  const protectedRoutes = [
    '/todos',
    '/profile',
    '/settings',
    '/notes',
    '/money',
    '/health',
    '/checklist',
  ];

  const auth = await isAuthenticated();
  Lg.d('Auth status before navigate:', auth, 'to:', to.url.pathname);

  if (
    !auth &&
    protectedRoutes.some((route) => to.url.pathname.startsWith(route))
  ) {
    cancel();
    toast.info($t('errors.please_login'));
    goto('/auth/login');
  }
});
</script>



{#if isLoading}
  <div class="loading">{$t('loading')}</div>
{:else}
  <slot />
{/if}

<Toaster richColors position="top-center" duration={3500} expand closeButton theme="system" />

<style>
  .loading {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    font-size: 1.2rem;
    color: var(--text-color, #333);
  }
</style>
