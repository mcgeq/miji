import { createRoute } from '@tanstack/react-router';
import { lazy } from 'react';
import { rootRoute } from '@/app/router';

const NotesPage = lazy(() => import('./pages/NotesPage'));

export const notesRoute = createRoute({
  path: '/notes',
  getParentRoute: () => rootRoute,
  component: NotesPage,
});
