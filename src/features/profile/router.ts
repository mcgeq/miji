import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const ProfilePage = lazy(() => import('./pages/ProfilePage'));

export const profileRoute = createRoute({
  path: '/profile',
  getParentRoute: () => rootRoute,
  component: ProfilePage,
});
