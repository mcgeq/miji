import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const SettingsPage = lazy(() => import('./pages/SettingsPage'));

export const settingsRoute = createRoute({
  path: '/settings',
  getParentRoute: () => rootRoute,
  component: SettingsPage,
});
