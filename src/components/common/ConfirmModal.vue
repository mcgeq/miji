<script setup lang="ts">
import { AlertTriangle, CheckCircle, Info, XCircle } from 'lucide-vue-next';

interface Props {
  visible?: boolean;
  title?: string;
  message: string;
  type?: 'info' | 'warning' | 'error' | 'success';
  confirmText?: string;
  cancelText?: string;
  confirmButtonType?: 'primary' | 'danger' | 'warning';
  showCancel?: boolean;
  loading?: boolean;
}

interface Emits {
  confirm: [];
  cancel: [];
  close: [];
}

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  title: '',
  type: 'warning',
  confirmText: '确定',
  cancelText: '取消',
  confirmButtonType: 'primary',
  showCancel: true,
  loading: false,
});

const emit = defineEmits<Emits>();

// 图标映射
const iconMap = {
  info: Info,
  warning: AlertTriangle,
  error: XCircle,
  success: CheckCircle,
};

// 图标颜色映射
const iconColorMap = {
  info: 'text-blue-500',
  warning: 'text-orange-500',
  error: 'text-red-500',
  success: 'text-green-500',
};

// 确认按钮样式映射
const confirmButtonStyleMap = {
  primary: 'bg-blue-600 hover:bg-blue-700 text-white',
  danger: 'bg-red-600 hover:bg-red-700 text-white',
  warning: 'bg-orange-600 hover:bg-orange-700 text-white',
};

// 获取当前图标组件
const IconComponent = computed(() => iconMap[props.type]);

// 获取图标颜色
const iconColor = computed(() => iconColorMap[props.type]);

// 获取确认按钮样式
const confirmButtonStyle = computed(() => confirmButtonStyleMap[props.confirmButtonType]);

// 处理确认
function handleConfirm() {
  if (props.loading)
    return;
  emit('confirm');
}

// 处理取消
function handleCancel() {
  if (props.loading)
    return;
  emit('cancel');
}

// 处理关闭
function handleClose() {
  if (props.loading)
    return;
  emit('close');
}

// 处理背景点击
function handleOverlayClick(event: Event) {
  if (event.target === event.currentTarget) {
    handleClose();
  }
}

// 处理ESC键
function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    handleClose();
  }
}

// 监听键盘事件
onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeydown);
});

// 防止背景滚动
watchEffect(() => {
  if (props.visible) {
    const scrollY = window.scrollY;
    document.body.style.overflow = 'hidden';
    document.body.style.position = 'fixed';
    document.body.style.top = `-${scrollY}px`;
    document.body.style.width = '100%';
  }
  else {
    const scrollY = document.body.style.top;
    document.body.style.overflow = '';
    document.body.style.position = '';
    document.body.style.top = '';
    document.body.style.width = '';
    if (scrollY) {
      window.scrollTo(0, Number.parseInt(scrollY || '0') * -1);
    }
  }
});
</script>

<template>
  <Teleport to="body">
    <Transition
      name="modal"
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="visible"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 p-4"
        @click="handleOverlayClick"
      >
        <!-- Modal content with v-if directive -->
        <div
          v-if="visible"
          class="relative max-w-md w-full transform rounded-lg bg-white shadow-xl transition-all duration-300 ease-out"
          :class="visible ? 'opacity-100 scale-100 translate-y-0' : 'opacity-0 scale-95 translate-y-4'"
          @click.stop
        >
          <!-- 头部 -->
          <div class="flex items-center gap-3 p-6 pb-4">
            <component
              :is="IconComponent"
              :class="iconColor"
              class="h-6 w-6 flex-shrink-0"
            />
            <div class="flex-1">
              <h3 v-if="title" class="text-lg text-gray-900 font-semibold">
                {{ title }}
              </h3>
              <p class="text-gray-700" :class="{ 'mt-1': title }">
                {{ message }}
              </p>
            </div>
          </div>

          <!-- 按钮区域 -->
          <div class="flex justify-end gap-3 px-6 pb-6">
            <button
              v-if="showCancel"
              type="button"
              class="border border-gray-300 rounded-md bg-white px-4 py-2 text-sm text-gray-700 font-medium transition-colors disabled:cursor-not-allowed hover:bg-gray-50 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              :disabled="loading"
              @click="handleCancel"
            >
              {{ cancelText }}
            </button>
            <button
              type="button"
              :class="confirmButtonStyle"
              class="flex items-center gap-2 rounded-md px-4 py-2 text-sm font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              :disabled="loading"
              @click="handleConfirm"
            >
              <div
                v-if="loading"
                class="h-4 w-4 animate-spin border-2 border-white border-t-transparent rounded-full"
              />
              {{ confirmText }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
/* 动画样式已通过Transition组件的class处理 */
</style>
