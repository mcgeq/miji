import { navItems } from './navItems';
import { Link, useRouterState } from '@tanstack/react-router';
import clsx from 'clsx';

export function BottomNav() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <nav
      className={clsx(
        'fixed bottom-0 inset-x-0 z-50',
        'h-16 flex justify-around items-end px-2',
        'bg-white/90 dark:bg-gray-800/90',
        'backdrop-blur-md border-t border-gray-200 dark:border-gray-700',
        'shadow-[0_-2px_12px_rgba(0,0,0,0.08)]',
        'rounded-t-xl',
      )}
    >
      {navItems.map((item) => {
        const isActive = pathname === item.path;

        return (
          <Link
            key={item.path}
            to={item.path}
            className="relative flex flex-col items-center justify-end w-1/4 h-full transition-all duration-300"
          >
            {isActive ? (
              <>
                <div
                  className={clsx(
                    'absolute -top-3 w-10 h-10 rounded-full flex items-center justify-center',
                    'bg-blue-600 dark:bg-blue-400 text-white shadow-md border-[3px] border-white dark:border-gray-800',
                    'animate-bounce-short transition-transform duration-300',
                  )}
                >
                  <i className={clsx('text-lg', item.icon)} />
                </div>
                <span className="mt-7 mb-3 text-xs font-semibold text-gray-900 dark:text-white">
                  {item.label}
                </span>
              </>
            ) : (
              <>
                <i
                  className={clsx(
                    'text-lg',
                    'text-gray-500 dark:text-gray-300',
                    'transition-transform duration-300 hover:scale-110',
                    item.icon,
                  )}
                />
                <span className="text-xs mt-2 mb-3 text-gray-500 dark:text-gray-300">
                  {item.label}
                </span>
              </>
            )}
          </Link>
        );
      })}
    </nav>
  );
}
