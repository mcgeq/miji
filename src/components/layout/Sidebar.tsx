import { useUIStore } from '@/stores/ui';
import { Link, useRouterState } from '@tanstack/react-router';
import clsx from 'clsx';
import { navItems } from './navItems';

export function Sidebar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { sidebarOpen, setSidebarOpen } = useUIStore();

  // Only render the button when sidebar is closed
  if (!sidebarOpen) {
    return (
      <button
        type="button"
        className="fixed bottom-4 left-4 w-12 h-12 bg-red-500 text-white rounded-full shadow-md z-50"
        onClick={() => setSidebarOpen(true)}
      >
        <i className="i-tabler-menu-2 text-xl" />
      </button>
    );
  }

  // Render sidebar as an overlay when open
  return (
    <>
      <aside className="fixed top-0 left-0 h-full w-36 bg-white dark:bg-gray-900 shadow-md z-50 transition-transform transform translate-x-0">
        <div className="flex-1">
          {navItems.map((item) => {
            const isActive = pathname === item.path;
            return (
              <Link
                key={item.path}
                to={item.path}
                onClick={() => setSidebarOpen(false)}
                className={clsx(
                  'flex items-center gap-2 px-4 py-3 hover:bg-gray-100 dark:hover:bg-gray-800',
                  isActive ? 'text-red-500' : 'text-gray-500',
                )}
              >
                <i className={clsx('text-xl', item.icon)} />
                <span>{item.label}</span>
              </Link>
            );
          })}
        </div>
        <button
          type="button"
          className="absolute left-2 bottom-4 w-10 h-10 bg-red-500 text-white rounded-full shadow-md"
          onClick={() => setSidebarOpen(false)}
        >
          <i className="i-tabler-menu-2" />
        </button>
      </aside>
      {/* Backdrop to disable interaction with main content */}
      <button
        type="button"
        className="fixed inset-0 bg-black bg-opacity-50 z-40"
        onClick={() => setSidebarOpen(false)}
      />
    </>
  );
}
