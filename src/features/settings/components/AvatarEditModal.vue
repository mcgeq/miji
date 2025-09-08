<script setup lang="ts">
import { Camera, Trash2, Upload, X } from 'lucide-vue-next';
import ConfirmModal from '@/components/common/ConfirmModal.vue';
import { useAuthStore } from '@/stores/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

interface Props {
  isOpen: boolean;
}

interface Emits {
  (e: 'close'): void;
  (e: 'updated', avatarUrl: string): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

const authStore = useAuthStore();
const user = computed(() => authStore.user);

const fileInput = ref<HTMLInputElement>();
const previewUrl = ref<string>('');
const selectedFile = ref<File | null>(null);
const isUploading = ref(false);
const dragActive = ref(false);

// 确认对话框状态
const showDeleteConfirm = ref(false);

// 文件选择处理
function handleFileSelect(event: Event) {
  const input = event.target as HTMLInputElement;
  if (input.files && input.files[0]) {
    const file = input.files[0];
    handleFile(file);
  }
}

// 处理文件
function handleFile(file: File) {
  // 验证文件类型
  if (!file.type.startsWith('image/')) {
    toast.warning('请选择图片文件');
    return;
  }

  // 验证文件大小（限制为 5MB）
  if (file.size > 5 * 1024 * 1024) {
    toast.warning('图片大小不能超过 5MB');
    return;
  }

  selectedFile.value = file;

  // 创建预览URL
  const reader = new FileReader();
  reader.onload = e => {
    previewUrl.value = e.target?.result as string;
  };
  reader.readAsDataURL(file);
}

// 拖拽处理
function handleDragOver(event: DragEvent) {
  event.preventDefault();
  dragActive.value = true;
}

function handleDragLeave(event: DragEvent) {
  event.preventDefault();
  dragActive.value = false;
}

function handleDrop(event: DragEvent) {
  event.preventDefault();
  dragActive.value = false;

  const files = event.dataTransfer?.files;
  if (files && files[0]) {
    handleFile(files[0]);
  }
}

// 触发文件选择
function triggerFileSelect() {
  fileInput.value?.click();
}

// 清除选择的文件
function clearSelection() {
  selectedFile.value = null;
  previewUrl.value = '';
  if (fileInput.value) {
    fileInput.value.value = '';
  }
}

// 上传头像
async function handleUpload() {
  if (!selectedFile.value)
    return;

  try {
    isUploading.value = true;

    // 这里应该调用 auth store 的 uploadAvatar 方法
    // const avatarUrl = await authStore.uploadAvatar(selectedFile.value);

    // 模拟上传（实际应用中删除这部分）
    await new Promise(resolve => setTimeout(resolve, 2000));
    const avatarUrl = previewUrl.value; // 实际应该是服务器返回的URL

    emit('updated', avatarUrl);
    emit('close');
    clearSelection();
    toast.success('头像上传成功');
  } catch (error) {
    toast.error('头像上传失败');
    Lg.e('Settings', error);
  } finally {
    isUploading.value = false;
  }
}

// 显示删除确认对话框
function showDeleteConfirmDialog() {
  showDeleteConfirm.value = true;
}

// 确认删除头像
async function confirmDeleteAvatar() {
  try {
    isUploading.value = true;

    // 调用 API 删除头像
    // await authStore.updateProfile({ avatarUrl: null });

    // 模拟删除操作
    await new Promise(resolve => setTimeout(resolve, 1000));

    emit('updated', '');
    emit('close');
    toast.success('头像删除成功');
  } catch (error) {
    Lg.e('Settings', '删除头像失败:', error);
    toast.error('删除头像失败，请重试');
  } finally {
    isUploading.value = false;
    showDeleteConfirm.value = false;
  }
}

// 取消删除
function cancelDeleteAvatar() {
  showDeleteConfirm.value = false;
}

// 关闭Modal
function handleClose() {
  if (!isUploading.value) {
    clearSelection();
    emit('close');
  }
}

// 点击遮罩层关闭
function handleOverlayClick(event: MouseEvent) {
  if (event.target === event.currentTarget) {
    handleClose();
  }
}

// 获取当前显示的头像URL，修复类型错误
const currentAvatarUrl = computed(() => {
  return previewUrl.value || user.value?.avatarUrl || '';
});

// 获取用户名首字母
const userInitial = computed(() => {
  return user.value?.name?.charAt(0)?.toUpperCase() || '?';
});
</script>

<template>
  <Teleport to="body">
    <Transition
      enter-active-class="duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="props.isOpen"
        class="p-4 bg-black/50 flex items-center inset-0 justify-center fixed z-50"
        @click="handleOverlayClick"
      >
        <Transition
          enter-active-class="duration-300 ease-out"
          enter-from-class="scale-95 opacity-0"
          enter-to-class="scale-100 opacity-100"
          leave-active-class="duration-200 ease-in"
          leave-from-class="scale-100 opacity-100"
          leave-to-class="scale-95 opacity-0"
        >
          <div
            v-if="props.isOpen"
            class="p-6 rounded-2xl bg-white max-w-md w-full shadow-2xl"
          >
            <!-- Modal 头部 -->
            <div class="mb-6 flex items-center justify-between">
              <h2 class="text-xl text-gray-900 font-bold">
                编辑头像
              </h2>
              <button
                class="text-gray-400 p-2 rounded-full transition-colors hover:text-gray-600 hover:bg-gray-100"
                :disabled="isUploading"
                @click="handleClose"
              >
                <X class="h-5 w-5" />
              </button>
            </div>

            <!-- 当前头像显示 -->
            <div class="mb-6 flex justify-center">
              <div class="relative">
                <div class="border-4 border-gray-200 rounded-full h-32 w-32 overflow-hidden">
                  <img
                    v-if="currentAvatarUrl"
                    :src="currentAvatarUrl"
                    :alt="user?.name || '用户头像'"
                    class="h-full w-full object-cover"
                  >
                  <div
                    v-else
                    class="text-2xl text-gray-500 font-semibold bg-gray-100 flex h-full w-full items-center justify-center"
                  >
                    {{ userInitial }}
                  </div>
                </div>

                <!-- 预览标识 -->
                <div
                  v-if="previewUrl"
                  class="text-xs text-white px-2 py-1 rounded-full bg-blue-500 absolute -right-2 -top-2"
                >
                  预览
                </div>
              </div>
            </div>

            <!-- 文件选择区域 -->
            <div
              class="mb-6 p-6 text-center border-2 rounded-lg border-dashed cursor-pointer transition-colors"
              :class="dragActive ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-gray-400'"
              @click="triggerFileSelect"
              @dragover="handleDragOver"
              @dragleave="handleDragLeave"
              @drop="handleDrop"
            >
              <input
                ref="fileInput"
                type="file"
                accept="image/*"
                class="hidden"
                @change="handleFileSelect"
              >

              <div class="flex flex-col gap-3 items-center">
                <div class="p-3 rounded-full bg-gray-100">
                  <Upload class="text-gray-600 h-6 w-6" />
                </div>
                <div>
                  <p class="text-sm text-gray-900 font-medium">
                    点击或拖拽上传图片
                  </p>
                  <p class="text-xs text-gray-500">
                    支持 JPG、PNG、GIF，最大 5MB
                  </p>
                </div>
              </div>
            </div>

            <!-- 操作按钮 -->
            <div class="space-y-3">
              <!-- 上传按钮 -->
              <button
                v-if="selectedFile"
                :disabled="isUploading"
                class="text-sm text-white font-medium px-4 py-3 rounded-lg bg-blue-600 flex gap-2 w-full transition-colors items-center justify-center focus:outline-none hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed focus:ring-2 focus:ring-blue-500/20"
                @click="handleUpload"
              >
                <Camera class="h-4 w-4" />
                {{ isUploading ? '上传中...' : '确认上传' }}
              </button>

              <div class="flex gap-3">
                <!-- 清除选择 -->
                <button
                  v-if="selectedFile"
                  :disabled="isUploading"
                  class="text-sm text-gray-700 font-medium px-4 py-3 border border-gray-300 rounded-lg flex-1 transition-colors focus:outline-none hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed focus:ring-2 focus:ring-gray-500/20"
                  @click="clearSelection"
                >
                  清除选择
                </button>

                <!-- 删除头像 -->
                <button
                  v-if="user?.avatarUrl && !selectedFile"
                  :disabled="isUploading"
                  class="text-sm text-red-700 font-medium px-4 py-3 border border-red-300 rounded-lg flex flex-1 gap-2 transition-colors items-center justify-center focus:outline-none hover:bg-red-50 disabled:opacity-50 disabled:cursor-not-allowed focus:ring-2 focus:ring-red-500/20"
                  @click="showDeleteConfirmDialog"
                >
                  <Trash2 class="h-4 w-4" />
                  删除头像
                </button>

                <!-- 取消按钮 -->
                <button
                  :disabled="isUploading"
                  class="text-sm text-gray-700 font-medium px-4 py-3 border border-gray-300 rounded-lg flex-1 transition-colors focus:outline-none hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed focus:ring-2 focus:ring-gray-500/20"
                  @click="handleClose"
                >
                  {{ selectedFile ? '取消' : '关闭' }}
                </button>
              </div>
            </div>
          </div>
        </Transition>
      </div>
    </Transition>

    <!-- 删除确认对话框 -->
    <ConfirmModal
      v-model:show="showDeleteConfirm"
      title="删除头像"
      message="确定要删除当前头像吗？删除后将显示默认头像。"
      type="danger"
      confirm-text="删除"
      cancel-text="取消"
      :loading="isUploading"
      @confirm="confirmDeleteAvatar"
      @cancel="cancelDeleteAvatar"
    />
  </Teleport>
</template>
