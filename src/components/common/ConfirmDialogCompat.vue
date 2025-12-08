<script setup lang="ts">
  /**
   * ConfirmDialog 兼容层组件
   *
   * 将旧版 ConfirmDialog/ConfirmModal 的 API 转换为新版 ConfirmDialog (UI) 的 API
   * 使现有代码无需修改即可使用新版组件
   */

  import { computed } from 'vue';
  import { ConfirmDialog } from '@/components/ui';

  interface Props {
    // 旧版支持的所有 props
    show?: boolean;
    visible?: boolean;
    title?: string;
    message?: string;
    type?: 'info' | 'warning' | 'danger' | 'error' | 'success';
    size?: 'sm' | 'md' | 'lg' | 'xl';
    closable?: boolean;
    loading?: boolean;
    showCancel?: boolean;
    confirmText?: string;
    cancelText?: string;
    confirmIcon?: string;
    canConfirm?: boolean;
    persistent?: boolean;
    zIndex?: number;
    confirmButtonType?: 'primary' | 'danger' | 'warning' | 'success';
    iconButtons?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    show: false,
    visible: false,
    title: '确认操作',
    message: '',
    type: 'info',
    size: 'md',
    closable: true,
    loading: false,
    showCancel: true,
    confirmText: '确认',
    cancelText: '取消',
    confirmIcon: '',
    canConfirm: true,
    persistent: false,
    zIndex: 1000,
    confirmButtonType: 'primary',
    iconButtons: false,
  });

  const emit = defineEmits<{
    'update:show': [show: boolean];
    'update:visible': [visible: boolean];
    confirm: [];
    cancel: [];
    close: [];
  }>();

  // 计算实际的 open 状态
  const isOpen = computed(() => props.show || props.visible);

  // 转换 type: 'danger' -> 'error'
  const normalizedType = computed(() => {
    if (props.type === 'danger') {
      return 'error';
    }
    return props.type as 'info' | 'success' | 'warning' | 'error';
  });

  // 转换 canConfirm -> confirmDisabled（逻辑相反）
  const confirmDisabled = computed(() => !props.canConfirm);

  function handleClose() {
    emit('update:show', false);
    emit('update:visible', false);
    emit('close');
  }

  function handleConfirm() {
    emit('confirm');
  }

  function handleCancel() {
    emit('cancel');
    handleClose();
  }
</script>

<template>
  <ConfirmDialog
    :open="isOpen"
    :type="normalizedType"
    :title="title"
    :message="message"
    :confirm-text="confirmText"
    :cancel-text="cancelText"
    :show-cancel="showCancel"
    :loading="loading"
    :confirm-disabled="confirmDisabled"
    :icon-buttons="iconButtons"
    @close="handleClose"
    @confirm="handleConfirm"
    @cancel="handleCancel"
  >
    <!-- 透传默认插槽 -->
    <slot />
  </ConfirmDialog>
</template>
