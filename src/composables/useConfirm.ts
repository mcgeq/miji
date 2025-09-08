// src/composables/useConfirm.ts

interface ConfirmOptions {
  title?: string;
  message: string;
  type?: 'info' | 'warning' | 'error' | 'success';
  confirmText?: string;
  cancelText?: string;
  confirmButtonType?: 'primary' | 'danger' | 'warning';
  showCancel?: boolean;
}

interface ConfirmState {
  visible: boolean;
  title: string;
  message: string;
  type: 'info' | 'warning' | 'error' | 'success';
  confirmText: string;
  cancelText: string;
  confirmButtonType: 'primary' | 'danger' | 'warning';
  showCancel: boolean;
  loading: boolean;
  resolve?: (value: boolean) => void;
}

// 全局状态
const confirmState = ref<ConfirmState>({
  visible: false,
  title: '',
  message: '',
  type: 'warning',
  confirmText: '确定',
  cancelText: '取消',
  confirmButtonType: 'primary',
  showCancel: true,
  loading: false,
});

export function useConfirm() {
  // 显示确认框
  const confirm = (options: ConfirmOptions): Promise<boolean> => {
    return new Promise(resolve => {
      confirmState.value = {
        visible: true,
        title: options.title || '',
        message: options.message,
        type: options.type || 'warning',
        confirmText: options.confirmText || '确定',
        cancelText: options.cancelText || '取消',
        confirmButtonType:
          options.confirmButtonType
          || (options.type === 'error' ? 'danger' : 'primary'),
        showCancel: options.showCancel ?? true,
        loading: false,
        resolve,
      };
    });
  };

  // 处理确认
  const handleConfirm = async () => {
    if (confirmState.value.loading)
      return;

    confirmState.value.loading = true;

    // 模拟异步操作延迟（可选）
    await nextTick();

    confirmState.value.visible = false;
    confirmState.value.loading = false;
    confirmState.value.resolve?.(true);
  };

  // 处理取消
  const handleCancel = () => {
    if (confirmState.value.loading)
      return;

    confirmState.value.visible = false;
    confirmState.value.resolve?.(false);
  };

  // 处理关闭
  const handleClose = () => {
    if (confirmState.value.loading)
      return;

    confirmState.value.visible = false;
    confirmState.value.resolve?.(false);
  };

  // 快捷方法
  const confirmDelete = (itemName?: string) => {
    return confirm({
      title: '确认删除',
      message: itemName
        ? `确定要删除"${itemName}"吗？此操作不可撤销。`
        : '确定要删除此项目吗？此操作不可撤销。',
      type: 'error',
      confirmText: '删除',
      confirmButtonType: 'danger',
    });
  };

  const confirmAction = (message: string, title?: string) => {
    return confirm({
      title: title || '确认操作',
      message,
      type: 'warning',
    });
  };

  const showInfo = (message: string, title?: string) => {
    return confirm({
      title: title || '信息',
      message,
      type: 'info',
      showCancel: false,
      confirmText: '知道了',
    });
  };

  const showSuccess = (message: string, title?: string) => {
    return confirm({
      title: title || '成功',
      message,
      type: 'success',
      showCancel: false,
      confirmText: '确定',
    });
  };

  const showError = (message: string, title?: string) => {
    return confirm({
      title: title || '错误',
      message,
      type: 'error',
      showCancel: false,
      confirmText: '确定',
    });
  };

  return {
    // 状态
    confirmState: readonly(confirmState),

    // 方法
    confirm,
    handleConfirm,
    handleCancel,
    handleClose,

    // 快捷方法
    confirmDelete,
    confirmAction,
    showInfo,
    showSuccess,
    showError,
  };
}
