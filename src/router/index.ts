// router/index.ts
import { createRouter, createWebHashHistory } from 'vue-router';
import { routes } from 'vue-router/auto-routes';
import { i18nInstance } from '@/i18n/i18n';
import { useAuthStore } from '@/stores/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { Composer } from 'vue-i18n';

const router = createRouter({
  history: createWebHashHistory(),
  routes,
});

router.beforeEach(async (to, _from) => {
  if (!i18nInstance) {
    return true;
  }
  const t = (i18nInstance.global as Composer).t;
  const authStore = useAuthStore();
  let isAuth = false;
  try {
    isAuth = await authStore.checkAuthStatus();
  } catch (error) {
    Lg.e('Router', 'Failed to check auth:', error);
  }
  const routeName = typeof to.name === 'string' ? to.name : '';
  const isAuthPage = ['auth-login', 'auth-register'].includes(routeName);

  if (!isAuth && to.meta.requiresAuth) {
    toast.warning(t('messages.pleaseLogin'));
    return { name: 'auth-login' };
  }

  if (isAuth && isAuthPage) {
    return { name: 'home' };
  }

  return true;
});

export default router;
