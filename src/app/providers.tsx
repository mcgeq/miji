import { RouterProvider } from '@tanstack/react-router';
import type { ReactNode } from 'react';
import { I18nextProvider } from 'react-i18next';
import i18n from './i18n';
import { useTheme } from '@/hooks/useTheme';
import { router } from './router';

export function AppProviders({ children }: { children: ReactNode }) {
  useTheme();
  return <I18nextProvider i18n={i18n}>{children}</I18nextProvider>;
}

export function AppRoot() {
  return (
    <AppProviders>
      <RouterProvider router={router} />
    </AppProviders>
  );
}
