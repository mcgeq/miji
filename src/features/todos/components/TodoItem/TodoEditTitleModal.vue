<script setup lang="ts">
import { Input, Modal } from '@/components/ui';

const props = defineProps<{ title: string; show: boolean }>();
const emit = defineEmits(['save', 'close']);

const localTitle = ref(props.title);
const hasChanged = computed(
  () => localTitle.value.trim() !== props.title.trim(),
);

function handleSave() {
  if (hasChanged.value) {
    emit('save', localTitle.value);
  }
}
</script>

<template>
  <Modal
    :open="show"
    title="编辑标题"
    size="md"
    :confirm-disabled="!hasChanged"
    @close="emit('close')"
    @confirm="handleSave"
  >
    <div class="space-y-3">
      <Input
        v-model="localTitle"
        placeholder="输入任务标题"
        :maxlength="100"
        autofocus
      />
      <div class="text-sm text-gray-500">
        {{ localTitle.length }}/100
      </div>
    </div>
  </Modal>
</template>
