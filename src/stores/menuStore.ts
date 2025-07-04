// src/stores/menuStore.ts
import { defineStore } from 'pinia';

export const useMenuStore = defineStore('menu', {
  state: () => ({
    openMenuSerialNum: '' as string,
  }),
  actions: {
    setMenuSerialNum(serialNum: string) {
      this.openMenuSerialNum = serialNum;
    },
  },
  getters: {
    getMenuSerialNum: (state) => state.openMenuSerialNum,
  },
});
