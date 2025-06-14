import { toast as sonner } from 'svelte-sonner';

export const toast = {
  success: (msg: string) =>
    sonner.success(msg, {
      duration: 3000,
      dismissable: true,
    }),
  error: (msg: string) =>
    sonner.error(msg, {
      duration: 4000,
      dismissable: true,
    }),
  info: (msg: string) =>
    sonner(msg, {
      duration: 3000,
      dismissable: true,
    }),
};
