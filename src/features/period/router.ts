import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const PeriodPage = lazy(() => import('./pages/PeriodPage'));

export const periodRoute = createRoute({
  path: '/period',
  getParentRoute: () => rootRoute,
  component: PeriodPage,
});
