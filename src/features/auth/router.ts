import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const LoginPage = lazy(() => import('./pages/LoginPage'));
const RegisterPage = lazy(() => import('./pages/RegisterPage'));

export const loginRoute = createRoute({
  path: '/login',
  getParentRoute: () => rootRoute,
  component: LoginPage,
});

export const registerRoute = createRoute({
  path: '/register',
  getParentRoute: () => rootRoute,
  component: RegisterPage,
});
