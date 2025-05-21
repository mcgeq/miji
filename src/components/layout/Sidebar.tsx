import { useUIStore } from '@/stores/ui';
import { Link, useRouterState } from '@tanstack/react-router';
import clsx from 'clsx';
import { navItems } from './navItems';

export function Sidebar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const { sidebarOpen, setSidebarOpen } = useUIStore();

  return (
    <aside
      className={clsx(
        'flex-col bg-white dark:bg-gray-900 shadow-md transition-all',
        sidebarOpen ? 'w-56' : 'w-16',
      )}
    >
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
              {sidebarOpen && <span>{item.label}</span>}
            </Link>
          );
        })}
      </div>

      {!sidebarOpen && (
        <button
          type="button"
          className="absolute left-2 bottom-4 w-10 h-10 bg-red-500 text-white rounded-full shadow-md"
          onClick={() => setSidebarOpen(true)}
        >
          <i className="i-tabler-menu-2" />
        </button>
      )}
    </aside>
  );
}
