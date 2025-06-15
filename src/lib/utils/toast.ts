import { toast as sonner } from 'svelte-sonner';

const baseClasses = (color: string) => ({
  toast: `bg-${color}/90 text-white rounded-lg shadow border border-${color}/30 p-4 flex items-center gap-2 animate-slide-in`,
  title: 'font-semibold',
  description: 'text-sm',
  actionButton: `bg-white text-${color} hover:bg-${color} hover:text-white rounded-md px-3 py-1`,
  cancelButton: 'bg-transparent text-white underline-hover',
  closeButton: `text-white hover:text-${color}`,
});

export const toast = {
  success: (msg: string) =>
    sonner.success(msg, {
      duration: 3000,
      dismissable: true,
      classes: baseClasses('green'),
    }),
  error: (msg: string) =>
    sonner.error(msg, {
      duration: 4000,
      dismissable: true,
      classes: baseClasses('red'),
    }),
  info: (msg: string) =>
    sonner(msg, {
      duration: 3000,
      dismissable: true,
      classes: baseClasses('blue'),
    }),
};
