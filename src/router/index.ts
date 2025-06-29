// router/index.ts
import { createRouter, createWebHistory } from 'vue-router';
import LoginView from '@/features/auth/login/LoginView.vue';
import RegisterView from '@/features/auth/register/RegisterView.vue';
import TodoView from '@/features/todos/views/TodoView.vue';
import { toast } from '@/utils/toast';
import { i18nInstance } from '@/i18n/i18n';
import type { Composer } from 'vue-i18n';

const routes = [
  {
    path: '/auth',
    children: [
      { path: 'register', component: RegisterView, name: 'Register' },
      { path: 'login', component: LoginView, name: 'Login' },
    ],
  },
  {
    path: '/todos',
    component: TodoView,
    name: 'Todos',
  },
  {
    path: '/',
    redirect: '/todos',
  },
];

const protectedRoutes = ['/todos'];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach(async (to, _from, next) => {
  if (!i18nInstance) {
    return next();
  }
  const t = (i18nInstance.global as Composer).t;
  const isAuth = await isAuthenticated();

  const isProtected = protectedRoutes.some((route) =>
    to.path.startsWith(route),
  );
  const isAuthPage = ['/auth/login', '/auth/register'].includes(to.path);

  if (!isAuth && isProtected) {
    toast.warning(t('errors.pleaseLogin'));
    return next('/auth/login');
  }

  if (isAuth && isAuthPage) {
    return next('/todos');
  }

  return next();
});

export default router;
