import { Outlet } from '@tanstack/react-router';

export function Layout() {
  return (
    <div className="min-h-screen flex flex-col bg-white dark:bg-gray-900">
      {/* 可选：顶部导航栏 */}
      <header className="p-4 shadow-md">App Header</header>

      {/* 路由页面容器 */}
      <main className="flex-1 p-4">
        <Outlet />
      </main>

      {/* 可选：底部 TabBar */}
      <footer className="p-4 shadow-inner">Tab Navigation</footer>
    </div>
  );
}
