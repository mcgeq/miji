import type { MessageObject } from 'svelte-i18n';

declare module 'svelte-i18n';
{
  interface MessageObject {
    min?: number | string;
    max?: number | string;
  }
}
