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
      version: 1, // ✅ 增加版本号
      storage: createTauriStorage<{ sidebarOpen: boolean }>(),
      migrate: (persistedState, version) => {
        if (version < 1) {
          // ✅ 当没有版本或旧版本时，强制重设默认值
          return {
            ...(persistedState as Partial<UIState>),
            sidebarOpen: true,
          };
        }
        return persistedState as UIState;
      },
    },
  ),
);
