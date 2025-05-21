import { persist } from 'zustand/middleware';
import { create } from 'zustand';
import { createTauriStorage } from '@/hooks/useTauriStorage';

interface UIState {
  sidebarOpen: boolean;
  toggleSidebar: () => void;
  setSidebarOpen: (open: boolean) => void;
}

export const useUIStore = create<UIState>()(
  persist(
    (set) => ({
      sidebarOpen: true,
      toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
      setSidebarOpen: (open) => set(() => ({ sidebarOpen: open })),
    }),
    {
      name: 'ui-store',
      storage: createTauriStorage<UIState>(),
    },
  ),
);
