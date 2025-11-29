<script setup lang="ts">
import { Camera, Trash2, Upload } from 'lucide-vue-next';
import ConfirmDialog from '@/components/common/ConfirmDialogCompat.vue';
import { Modal } from '@/components/ui';
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
  <Modal
    :open="props.isOpen"
    title="编辑头像"
    size="md"
    :show-footer="false"
    @close="handleClose"
  >
    <!-- 当前头像显示 -->
    <div class="flex justify-center mb-6">
      <div class="relative">
        <div class="w-32 h-32 rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700 flex items-center justify-center">
          <img
            v-if="currentAvatarUrl"
            :src="currentAvatarUrl"
            :alt="user?.name || '用户头像'"
            class="w-full h-full object-cover"
          >
          <div
            v-else
            class="text-4xl font-semibold text-gray-500 dark:text-gray-400"
          >
            {{ userInitial }}
          </div>
        </div>

        <!-- 预览标识 -->
        <div
          v-if="previewUrl"
          class="absolute -top-2 -right-2 bg-blue-600 text-white text-xs px-2 py-1 rounded-full"
        >
          预览
        </div>
      </div>
    </div>

    <!-- 文件选择区域 -->
    <div
      class="border-2 border-dashed rounded-lg p-8 text-center cursor-pointer transition-colors"
      :class="dragActive ? 'border-blue-500 bg-blue-50 dark:bg-blue-900/20' : 'border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500'"
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

      <div class="flex flex-col items-center gap-3">
        <div class="w-12 h-12 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center">
          <Upload class="w-6 h-6 text-gray-600 dark:text-gray-300" />
        </div>
        <div>
          <p class="text-sm font-medium text-gray-900 dark:text-white">
            点击或拖拽上传图片
          </p>
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            支持 JPG、PNG、GIF，最大 5MB
          </p>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="flex flex-col gap-3 mt-6">
      <!-- 上传按钮 -->
      <button
        v-if="selectedFile"
        :disabled="isUploading"
        class="w-full flex items-center justify-center gap-2 px-4 py-3 bg-blue-600 hover:bg-blue-700 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
        @click="handleUpload"
      >
        <Camera class="w-5 h-5" />
        {{ isUploading ? '上传中...' : '确认上传' }}
      </button>

      <div class="flex gap-3">
        <!-- 清除选择 -->
        <button
          v-if="selectedFile"
          :disabled="isUploading"
          class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg disabled:opacity-50 transition-colors"
          @click="clearSelection"
        >
          清除选择
        </button>

        <!-- 删除头像 -->
        <button
          v-if="user?.avatarUrl && !selectedFile"
          :disabled="isUploading"
          class="flex-1 flex items-center justify-center gap-2 px-4 py-2 bg-red-600 hover:bg-red-700 text-white rounded-lg disabled:opacity-50 transition-colors"
          @click="showDeleteConfirmDialog"
        >
          <Trash2 class="w-4 h-4" />
          删除头像
        </button>

        <!-- 关闭按钮 -->
        <button
          :disabled="isUploading"
          class="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg disabled:opacity-50 transition-colors"
          @click="handleClose"
        >
          {{ selectedFile ? '取消' : '关闭' }}
        </button>
      </div>
    </div>
  </Modal>

  <!-- 删除确认对话框 -->
  <ConfirmDialog
    v-model:visible="showDeleteConfirm"
    title="删除头像"
    message="确定要删除当前头像吗？删除后将显示默认头像。"
    type="danger"
    confirm-text="删除"
    cancel-text="取消"
    :loading="isUploading"
    :icon-buttons="true"
    @confirm="confirmDeleteAvatar"
    @cancel="cancelDeleteAvatar"
  />
</template>
