import { createRouter, createWebHistory } from 'vue-router';
import LoginView from '@/features/auth/login/LoginView.vue';
import RegisterView from '@/features/auth/register/RegisterView.vue';
import TodoView from '@/features/todos/views/TodoView.vue';
import { isAuthenticated } from '@/stores/auth';
import { toast } from '@/utils/toast';
import { i18nInstance } from '@/i18n/i18n';
import type { Composer } from 'vue-i18n';

const routes = [
  { path: '/auth/register', component: RegisterView, name: 'Register' },
  { path: '/auth/login', component: LoginView, name: 'Login' },
  { path: '/todos', component: TodoView, name: 'Todos' },
  { path: '/', redirect: '/auth/login' },
];

const protectedRoutes = ['/todos'];
const publicRoutes = ['/auth/login', '/auth/register', '/'];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

// 路由守卫，基于 authStore.value.isAuth 同步判断

router.beforeEach(async (to, _from, next) => {
  if (!i18nInstance) {
    return next();
  }

  // 断言 global 为 Composer 类型
  const globalComposer = i18nInstance.global as Composer;

  // 断言 t 函数类型为 (key: string) => string
  const t = globalComposer.t as (key: string) => string;

  const isAuth = await isAuthenticated();

  if (!isAuth && protectedRoutes.some((path) => to.path.startsWith(path))) {
    toast.info(t('errors.pleaseLogin'));
    return next('/auth/login');
  }

  if (isAuth && publicRoutes.includes(to.path)) {
    return next('/todos');
  }

  next();
});
export default router;
