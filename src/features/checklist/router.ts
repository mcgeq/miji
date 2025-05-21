import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const ChecklistPage = lazy(() => import('./pages/ChecklistPage'));

export const checklistRoute = createRoute({
  path: '/checklist',
  getParentRoute: () => rootRoute,
  component: ChecklistPage,
});
