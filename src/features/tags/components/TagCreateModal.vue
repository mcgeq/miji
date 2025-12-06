<script setup lang="ts">
  import Input from '@/components/ui/Input.vue';
  import Modal from '@/components/ui/Modal.vue';
  import Textarea from '@/components/ui/Textarea.vue';
  import type { TagCreate } from '@/services/tags';

  interface Props {
    open: boolean;
  }

  const props = defineProps<Props>();

  const emit = defineEmits<{
    close: [];
    confirm: [data: TagCreate];
  }>();

  const formData = ref<TagCreate>({
    name: '',
    description: null,
  });

  // 描述字段的计算属性（处理 null 值）
  const tagDescription = computed({
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
    };
  };

  // 处理关闭
  const handleClose = () => {
    resetForm();
    emit('close');
  };

  // 处理确认
  const handleConfirm = () => {
    if (!isValid.value) return;

    emit('confirm', {
      name: formData.value.name.trim(),
      description: formData.value.description?.trim() || null,
    });

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
    title="创建标签"
    :confirm-disabled="!isValid"
    @close="handleClose"
    @cancel="handleClose"
    @confirm="handleConfirm"
  >
    <div class="space-y-4">
      <!-- 标签名称 -->
      <Input
        v-model="formData.name"
        label="标签名称"
        placeholder="请输入标签名称"
        :max-length="200"
        :required="true"
        full-width
      />

      <!-- 标签描述 -->
      <Textarea
        v-model="tagDescription"
        placeholder="请输入标签描述（可选）"
        :rows="3"
        :max-length="500"
        :show-count="true"
        full-width
      />
    </div>
  </Modal>
</template>
