import { RouterProvider } from '@tanstack/react-router';
import type { ReactNode } from 'react';
import { I18nextProvider } from 'react-i18next';
import i18n from './i18n';
import { useTheme } from '@/hooks/useTheme';
import { router } from './router';

// AppProviders 包装器
export function AppProviders({ children }: { children: ReactNode }) {
  useTheme(); // 自动设置暗/亮主题
  return <I18nextProvider i18n={i18n}>{children}</I18nextProvider>;
}

// 包裹整个 app 入口的根组件
export function AppRoot() {
  return (
    <AppProviders>
      <RouterProvider router={router} />
    </AppProviders>
  );
}
