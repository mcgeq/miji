import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const LoginPage = lazy(() => import('./pages/LoginPage'));

export const loginRoute = createRoute({
  path: '/login',
  getParentRoute: () => rootRoute,
  component: LoginPage,
});
