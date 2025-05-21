import { useUIStore } from '@/stores/ui';
import { Link, useRouterState } from '@tanstack/react-router';
import clsx from 'clsx';
import { navItems } from './navItems';

export function Sidebar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { sidebarOpen, setSidebarOpen } = useUIStore();

  const toggleSidebar = () => setSidebarOpen(!sidebarOpen);

  // 浮动打开按钮（Sidebar 关闭状态）
  if (!sidebarOpen) {
    return (
      <button
        type="button"
        className="fixed bottom-2 left-2 w-8 h-8 rounded-full shadow-xl bg-white/80 dark:bg-gray-800/80 backdrop-blur-md hover:scale-110 transition-transform z-50 flex items-center justify-center border border-white/30 dark:border-gray-600"
        onClick={toggleSidebar}
      >
        <span className="flex flex-col items-center justify-center space-y-0.5">
          <span className="w-5 h-0.5 bg-blue-500 rounded" />
          <span className="w-5 h-0.5 bg-blue-500 rounded" />
          <span className="w-5 h-0.5 bg-blue-500 rounded" />
        </span>
      </button>
    );
  }

  return (
    <>
      {/* Sidebar 主体 */}
      <aside className="fixed top-0 left-0 h-full w-48 bg-white/60 dark:bg-gray-900/60 backdrop-blur-md shadow-2xl rounded-r-3xl border-r border-white/20 dark:border-gray-700 z-50 transition-all duration-300">
        {/* Logo 区域 */}
        <div className="flex items-center gap-3 px-5 py-5 border-b border-white/20 dark:border-gray-700">
          <img src="/logo.png" alt="Logo" className="w-7 h-7 rounded-full" />
          <span className="text-xl font-bold text-gray-800 dark:text-white tracking-wide">
            MiJi
          </span>
        </div>

        {/* 导航项 */}
        <nav className="flex flex-col mt-4">
          {navItems.map((item) => {
            const isActive = pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                onClick={toggleSidebar}
                className={clsx(
                  'group flex items-center gap-3 px-5 py-3 rounded-xl mx-3 my-1 transition-all',
                  'hover:bg-white/50 dark:hover:bg-gray-700/40 hover:backdrop-blur-sm hover:translate-x-1',
                  isActive
                    ? 'bg-blue-100 dark:bg-blue-900/50 text-blue-600 dark:text-blue-300 font-semibold shadow-sm'
                    : 'text-gray-700 dark:text-gray-300',
                )}
              >
                <i
                  className={clsx(
                    'text-xl transition-transform group-hover:scale-110',
                    item.icon,
                  )}
                />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* 关闭按钮 */}
        <button
          type="button"
          className="absolute bottom-2 left-2 w-8 h-8 rounded-full shadow-xl bg-white/80 dark:bg-gray-800/80 backdrop-blur-md hover:scale-110 transition-transform flex items-center justify-center border border-white/30 dark:border-gray-600"
          onClick={toggleSidebar}
        >
          <span className="flex flex-col items-center justify-center space-y-0.5">
            <span className="w-5 h-0.5 bg-blue-500 rounded" />
            <span className="w-5 h-0.5 bg-blue-500 rounded" />
            <span className="w-5 h-0.5 bg-blue-500 rounded" />
          </span>
        </button>
      </aside>

      {/* 遮罩层 */}
      <button
        type="button"
        className="fixed inset-0 bg-black/40 z-40 backdrop-blur-sm transition-opacity"
        onClick={toggleSidebar}
      />
    </>
  );
}
