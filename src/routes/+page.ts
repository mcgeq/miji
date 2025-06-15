// src/routes/+page.ts
// import { goto } from '$app/navigation';
// import { isAuthenticated } from '$lib/stores/auth';
// import { Lg } from '@/lib/utils/debugLog';
//
// export const load = async () => {
//   const auth = await isAuthenticated();
//   Lg.i('Page', auth);
//
//   // 注意：load 函数里不能用 `throw redirect`，因为这是客户端环境。
//   if (auth) {
//     goto('/todos');
//   } else {
//     goto('/auth/login');
//   }
//
//   return {};
// };
