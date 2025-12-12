<script setup lang="ts">
  import Modal from '@/components/ui/Modal.vue';

  const props = defineProps<{
    open: boolean;
  }>();

  const emit = defineEmits<{
    close: [];
    confirm: [name: string, icon: string];
  }>();

  const formData = reactive({
    name: '',
    icon: '',
  });

  // 重置表单
  function resetForm() {
    formData.name = '';
    formData.icon = '';
  }

  // 关闭模态框
  function handleClose() {
    resetForm();
    emit('close');
  }

  // 确认添加
  function handleConfirm() {
    if (!formData.name.trim()) {
      return;
    }
    emit('confirm', formData.name.trim(), formData.icon.trim());
    resetForm();
  }

  // 表单验证
  const isValid = computed(() => {
    return formData.name.trim().length >= 2 && formData.name.trim().length <= 20;
  });
</script>

<template>
  <Modal
    :open="props.open"
    title="添加分类"
    size="sm"
    :confirm-disabled="!isValid"
    @close="handleClose"
    @cancel="handleClose"
    @confirm="handleConfirm"
  >
    <div class="space-y-4">
      <!-- 名称输入 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          分类名称 <span class="text-red-500">*</span>
        </label>
        <input
          v-model="formData.name"
          type="text"
          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="请输入分类名称 (2-20字符)"
          maxlength="20"
          @keyup.enter="isValid && handleConfirm()"
        />
        <p class="mt-1 text-xs text-gray-500">{{ formData.name.length }}/20 字符</p>
      </div>

      <!-- 图标输入 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          图标 (Emoji)
        </label>
        <input
          v-model="formData.icon"
          type="text"
          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 text-2xl text-center"
          placeholder="🎁"
          maxlength="2"
        />
        <p class="mt-1 text-xs text-gray-500">可选，留空将使用默认图标</p>
      </div>
    </div>
  </Modal>
</template>
