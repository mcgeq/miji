import { create } from 'zustand';
import { persist } from 'zustand/middleware';
import { createTauriStorage } from '@/hooks/useTauriStorage';

type AuthState = {
  token: string | null;
  user: any | null;
  rememberMe: boolean;
  setAuth: (token: string, user: any, remember: boolean) => void;
  logout: () => void;
};

export const useAuthStore = create<AuthState>()(
  persist(
    (set) => ({
      token: null,
      user: null,
      rememberMe: false,
      setAuth: (token, user, rememberMe) => set({ token, user, rememberMe }),
      logout: () => set({ token: null, user: null, rememberMe: false }),
    }),
    {
      name: 'auth-storage',
      storage: createTauriStorage(),
    },
  ),
);
