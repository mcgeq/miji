import { Outlet } from '@tanstack/react-router';
import { Sidebar } from './Sidebar';
import { BottomNav } from './BottomNav';

export function ResponsiveLayout() {
  return (
    <div className="min-h-screen flex flex-col md:flex-row">
      <Sidebar />
      <main className="flex-1 p-4 pt-4 pb-16 md:pb-4 md:pt-4 overflow-y-auto">
        <Outlet />
      </main>
      <BottomNav />
    </div>
  );
}
