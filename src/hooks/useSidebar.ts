import { useSidebarStore } from '@/stores/sidebar';

export const useSidebar = () => {
  const { isOpen, toggle, close } = useSidebarStore();
  return { isOpen, toggle, close };
};
