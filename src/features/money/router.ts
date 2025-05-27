import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const MoneyPage = lazy(() => import('./pages/MoneyPage'));

export const moneyRoute = createRoute({
  path: '/money',
  getParentRoute: () => rootRoute,
  component: MoneyPage,
});
