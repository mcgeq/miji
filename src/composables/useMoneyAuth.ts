/**
 * Money模块认证Composable
 *
 * 提供当前用户信息和账本信息
 */

import { computed } from 'vue';
import { useAuthStore } from '@/stores/auth';

export function useMoneyAuth() {
  const authStore = useAuthStore();

  /**
   * 当前用户串号
   */
  const currentUserSerialNum = computed(() => {
    return authStore.user?.serialNum || '';
  });

  /**
   * 当前用户信息
   */
  const currentUser = computed(() => {
    return authStore.user;
  });

  /**
   * 是否已登录
   */
  const isAuthenticated = computed(() => {
    return authStore.isAuthenticated;
  });

  /**
   * 当前账本串号 (从localStorage或默认值获取)
   * TODO: 考虑创建一个专门的ledger store
   */
  const currentLedgerSerialNum = computed(() => {
    const stored = localStorage.getItem('current_ledger_serial_num');
    return stored || 'FL001'; // 默认值
  });

  /**
   * 设置当前账本
   */
  function setCurrentLedger(serialNum: string) {
    localStorage.setItem('current_ledger_serial_num', serialNum);
  }

  /**
   * 当前成员串号（在家庭账本中的成员ID）
   * TODO: 这应该从family_ledger_member表中查询
   */
  const currentMemberSerialNum = computed(() => {
    const stored = localStorage.getItem('current_member_serial_num');
    return stored || currentUserSerialNum.value || 'M001'; // 默认值
  });

  /**
   * 设置当前成员
   */
  function setCurrentMember(serialNum: string) {
    localStorage.setItem('current_member_serial_num', serialNum);
  }

  return {
    // 用户信息
    currentUser,
    currentUserSerialNum,
    isAuthenticated,

    // 账本信息
    currentLedgerSerialNum,
    setCurrentLedger,

    // 成员信息
    currentMemberSerialNum,
    setCurrentMember,
  };
}
