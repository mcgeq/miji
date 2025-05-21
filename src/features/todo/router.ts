import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const TodoPage = lazy(() => import('./pages/TodoPage'));

export const todoRoute = createRoute({
  path: '/todo',
  getParentRoute: () => rootRoute,
  component: TodoPage,
});

export const homeRoute = createRoute({
  path: '/',
  getParentRoute: () => rootRoute,
  component: TodoPage,
});
