<script setup lang="ts">
  import ColorSelector from '@/components/common/ColorSelector.vue';
  import TagSelector from '@/components/common/TagSelector.vue';
  import Input from '@/components/ui/Input.vue';
  import Modal from '@/components/ui/Modal.vue';
  import Textarea from '@/components/ui/Textarea.vue';
  import type { ProjectCreate } from '@/services/projects';

  interface Props {
    open: boolean;
  }

  const props = defineProps<Props>();

  const emit = defineEmits<{
    close: [];
    confirm: [data: ProjectCreate, tags: string[]];
  }>();

  const formData = ref<ProjectCreate>({
    name: '',
    description: null,
    ownerId: null,
    color: '#3b82f6',
    isArchived: false,
  });

  // 选中的标签
  const selectedTags = ref<string[]>([]);

  // 颜色选择器专用的计算属性
  const projectColor = computed({
    get: () => formData.value.color || '#3b82f6',
    set: (value: string) => {
      formData.value.color = value;
    },
  });

  // 描述字段的计算属性（处理 null 值）
  const projectDescription = computed({
    get: () => formData.value.description || '',
    set: (value: string) => {
      formData.value.description = value || null;
    },
  });

  // 验证表单
  const isValid = computed(() => {
    return formData.value.name.trim().length > 0;
  });

  // 重置表单
  const resetForm = () => {
    formData.value = {
      name: '',
      description: null,
      ownerId: null,
      color: '#3b82f6',
      isArchived: false,
    };
    selectedTags.value = [];
  };

  // 处理关闭
  const handleClose = () => {
    resetForm();
    emit('close');
  };

  // 处理确认
  const handleConfirm = () => {
    if (!isValid.value) return;
    emit('confirm', formData.value, selectedTags.value);
    resetForm();
  };

  // 监听 open 变化，打开时重置表单
  watch(
    () => props.open,
    newVal => {
      if (newVal) {
        resetForm();
      }
    },
  );
</script>

<template>
  <Modal
    :open="open"
    title="创建项目"
    :confirm-disabled="!isValid"
    @close="handleClose"
    @cancel="handleClose"
    @confirm="handleConfirm"
  >
    <div class="space-y-4">
      <!-- 项目名称 -->
      <Input
        v-model="formData.name"
        label="项目名称"
        placeholder="请输入项目名称"
        :max-length="200"
        :required="true"
        full-width
      />

      <!-- 项目描述 -->
      <Textarea
        v-model="projectDescription"
        placeholder="请输入项目描述（可选）"
        :rows="3"
        :max-length="500"
        :show-count="true"
        full-width
      />

      <!-- 项目颜色 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          项目颜色
        </label>
        <ColorSelector
          v-model="projectColor"
          :show-custom-color="true"
          :show-random-button="true"
          width="full"
        />
      </div>

      <!-- 项目标签 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
          项目标签
        </label>
        <TagSelector v-model="selectedTags" placeholder="为项目添加标签..." />
      </div>
    </div>
  </Modal>
</template>
