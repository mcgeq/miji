<script setup lang="ts">
  import Input from '@/components/ui/Input.vue';
  import Modal from '@/components/ui/Modal.vue';
  import Textarea from '@/components/ui/Textarea.vue';
  import type { Tags } from '@/schema/tags';
  import type { TagUpdate } from '@/services/tags';

  interface Props {
    open: boolean;
    tag: Tags | null;
  }

  const props = defineProps<Props>();

  const emit = defineEmits<{
    close: [];
    confirm: [serialNum: string, data: TagUpdate];
  }>();

  const formData = ref<TagUpdate>({
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
    return formData.value.name && formData.value.name.trim().length > 0;
  });

  // 加载标签数据
  function loadTagData() {
    if (!props.tag) return;

    formData.value = {
      name: props.tag.name,
      description: props.tag.description,
    };
  }

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
    if (!(isValid.value && props.tag)) return;

    emit('confirm', props.tag.serialNum, {
      name: formData.value.name?.trim(),
      description: formData.value.description?.trim() || null,
    });

    resetForm();
  };

  // 监听 open 变化，打开时加载数据
  watch(
    () => props.open,
    newVal => {
      if (newVal && props.tag) {
        loadTagData();
      } else {
        resetForm();
      }
    },
  );
</script>

<template>
  <Modal
    :open="open"
    title="编辑标签"
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
