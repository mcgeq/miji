import { onMounted, onUnmounted, ref } from 'vue';
import { TransactionTypeSchema } from '@/schema/common';
import type { TransactionType } from '@/schema/common';

export interface KeyboardShortcut {
  key: string;
  label: string;
  action: string;
}

export function useKeyboardShortcuts() {
  const showKeyboardHelp = ref(false);

  // 键盘快捷键配置
  const keyboardShortcuts: KeyboardShortcut[] = [
    { key: 'A', label: '添加账户', action: 'showAccountModal' },
    { key: 'I', label: '记录收入', action: 'showIncomeModal' },
    { key: 'E', label: '记录支出', action: 'showExpenseModal' },
    { key: 'T', label: '记录转账', action: 'showTransferModal' },
    { key: 'B', label: '设置预算', action: 'showBudgetModal' },
    { key: 'R', label: '设置提醒', action: 'showReminderModal' },
    { key: '?', label: '显示帮助', action: 'toggleHelp' },
  ];

  // 键盘事件处理函数
  function createKeyboardHandler(
    modalStates: {
      showTransaction: Ref<boolean>;
      showAccount: Ref<boolean>;
      showBudget: Ref<boolean>;
      showReminder: Ref<boolean>;
    },
    actions: {
      showAccountModal: () => void;
      showTransactionModal: (type: TransactionType) => void;
      showBudgetModal: () => void;
      showReminderModal: () => void;
      closeAllModals: () => void;
    },
  ) {
    return function handleKeyPress(event: KeyboardEvent) {
      // 如果任何模态框已打开，只处理 ESC 键
      const anyModalOpen = modalStates.showTransaction.value ||
        modalStates.showAccount.value ||
        modalStates.showBudget.value ||
        modalStates.showReminder.value;

      if (anyModalOpen) {
        if (event.key === 'Escape') {
          event.preventDefault();
          actions.closeAllModals();
        }
        return;
      }

      // 排除在输入框中的情况
      const target = event.target as HTMLElement;
      if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') {
        return;
      }

      const key = event.key.toUpperCase();

      switch (key) {
        case 'A':
          event.preventDefault();
          actions.showAccountModal();
          break;
        case 'I':
          event.preventDefault();
          actions.showTransactionModal(TransactionTypeSchema.enum.Income);
          break;
        case 'E':
          event.preventDefault();
          actions.showTransactionModal(TransactionTypeSchema.enum.Expense);
          break;
        case 'T':
          event.preventDefault();
          actions.showTransactionModal(TransactionTypeSchema.enum.Transfer);
          break;
        case 'B':
          event.preventDefault();
          actions.showBudgetModal();
          break;
        case 'R':
          event.preventDefault();
          actions.showReminderModal();
          break;
        case '?':
          event.preventDefault();
          showKeyboardHelp.value = !showKeyboardHelp.value;
          break;
      }
    };
  }

  // 添加键盘事件监听器
  function addKeyboardListener(handler: (event: KeyboardEvent) => void) {
    onMounted(() => {
      window.addEventListener('keydown', handler);
    });

    onUnmounted(() => {
      window.removeEventListener('keydown', handler);
    });
  }

  return {
    // 状态
    showKeyboardHelp,
    keyboardShortcuts,

    // 方法
    createKeyboardHandler,
    addKeyboardListener,
  };
}
