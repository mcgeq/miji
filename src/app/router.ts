import { Layout } from '@/components/layout/Layout';
import { loginRoute, registerRoute } from '@/features/auth/router';
import { checklistRoute } from '@/features/checklist/router';
import { moneyRoute } from '@/features/money/router';
import { notesRoute } from '@/features/notes/router';
import { periodRoute } from '@/features/period/router';
import { profileRoute } from '@/features/profile/router';
import { settingsRoute } from '@/features/settings/router';
import { homeRoute, todoRoute } from '@/features/todo/router';
import { createRootRoute, createRouter } from '@tanstack/react-router';

export const rootRoute = createRootRoute({
  component: Layout,
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
  registerRoute,
  moneyRoute,
]);

export const router = createRouter({ routeTree });

declare module '@tanstack/react-router' {
  interface Register {
    router: typeof router;
  }
}
