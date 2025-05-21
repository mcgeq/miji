import { navItems } from './navItems';
import { Link, useRouterState } from '@tanstack/react-router';
import clsx from 'clsx';

export function BottomNav() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });

  return (
    <nav className="fixed bottom-0 inset-x-0 flex justify-around bg-white dark:bg-gray-900 shadow h-14 z-50">
      {navItems.map((item) => {
        const isActive = pathname === item.path;
        return (
          <Link
            key={item.path}
            to={item.path}
            className={clsx(
              'flex flex-col items-center justify-center text-xs flex-1',
              isActive ? 'text-red-500' : 'text-gray-400',
            )}
          >
            <i className={clsx('text-xl', item.icon)} />
            {<span>{item.label}</span>}
          </Link>
        );
      })}
    </nav>
  );
}
