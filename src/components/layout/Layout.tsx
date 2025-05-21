import { Outlet } from '@tanstack/react-router';
import { Sidebar } from '@/components/layout/Sidebar';
import { BottomNav } from '@/components/layout/BottomNav';
import { useUIStore } from '@/stores/ui';
import { useMediaQuery } from 'react-responsive';

export function Layout() {
  const { sidebarOpen } = useUIStore();
  const isDesktop = useMediaQuery({ minWidth: 1024 }); // lg 断点，1024px

  return (
    <div className="min-h-screen flex flex-col lg:flex-row bg-white dark:bg-gray-900">
      {/* 桌面端侧边栏 */}
      {isDesktop && sidebarOpen && <Sidebar />}

      {/* 主内容区域 */}
      <main className="flex-1 p-4 pb-20 lg:pb-4">
        <Outlet />
      </main>

      {/* 移动端底部导航 */}
      {!isDesktop && <BottomNav />}
    </div>
  );
}
