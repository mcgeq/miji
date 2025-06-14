// Tauri doesn't have a Node.js server to do proper SSR
// so we will use adapter-static to prerender the app (SSG)
// See: https://v2.tauri.app/start/frontend/sveltekit/ for more info

import '$lib/i18n/i18n';
export const prerender = true;
export const ssr = false;

export const load = async () => {
  return {};
};
