import { authStore } from './auth';

export const storeStart = async () => {
  authStore.start();
};
