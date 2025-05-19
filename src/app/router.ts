import {
  createRootRoute,
  createRoute,
  createRouter,
} from '@tanstack/react-router';

import { lazy } from 'react';
import { Layout } from './layout';

// 所有页面组件懒加载
const TodoPage = lazy(() => import('@/features/todo/pages/TodoPage'));
const PeriodPage = lazy(() => import('@/features/period/pages/PeriodPage'));
const ChecklistPage = lazy(
  () => import('@/features/checklist/pages/ChecklistPage'),
);
const NotesPage = lazy(() => import('@/features/notes/pages/NotesPage'));
const ProfilePage = lazy(() => import('@/features/profile/pages/ProfilePage'));
const SettingsPage = lazy(
  () => import('@/features/settings/pages/SettingsPage'),
);
const LoginPage = lazy(() => import('@/features/auth/pages/LoginPage'));

// 根布局路由
const rootRoute = createRootRoute({
  component: Layout,
});

// 子路由定义
const homeRoute = createRoute({
  path: '/',
  getParentRoute: () => rootRoute,
  component: TodoPage,
});

const todoRoute = createRoute({
  path: '/todo',
  getParentRoute: () => rootRoute,
  component: TodoPage,
});
const periodRoute = createRoute({
  path: '/period',
  getParentRoute: () => rootRoute,
  component: PeriodPage,
});
const checklistRoute = createRoute({
  path: '/checklist',
  getParentRoute: () => rootRoute,
  component: ChecklistPage,
});
const notesRoute = createRoute({
  path: '/notes',
  getParentRoute: () => rootRoute,
  component: NotesPage,
});
const profileRoute = createRoute({
  path: '/profile',
  getParentRoute: () => rootRoute,
  component: ProfilePage,
});
const settingsRoute = createRoute({
  path: '/settings',
  getParentRoute: () => rootRoute,
  component: SettingsPage,
});
const loginRoute = createRoute({
  path: '/login',
  getParentRoute: () => rootRoute,
  component: LoginPage,
});

const routeTree = rootRoute.addChildren([
  homeRoute,
  todoRoute,
  periodRoute,
  checklistRoute,
  notesRoute,
  profileRoute,
  settingsRoute,
  loginRoute,
]);

// 导出 router 实例
export const router = createRouter({ routeTree });

// 类型注入（推荐）
declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}
