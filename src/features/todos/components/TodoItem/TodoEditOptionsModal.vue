<script setup lang="ts">
import { Calendar, Pencil, Repeat } from 'lucide-vue-next';
import { Modal } from '@/components/ui';

defineProps<{ show: boolean }>();
const emit = defineEmits(['editTitle', 'editDueDate', 'editRepeat', 'close']);

const options = [
  { icon: Pencil, label: '编辑标题', action: 'editTitle' },
  { icon: Calendar, label: '设置日期', action: 'editDueDate' },
  { icon: Repeat, label: '设置重复', action: 'editRepeat' },
];

function handleOption(action: string) {
  emit(action as any);
  emit('close');
}
</script>

<template>
  <Modal
    :open="show"
    title="编辑选项"
    size="sm"
    :show-footer="false"
    @close="emit('close')"
  >
    <div class="space-y-2">
      <button
        v-for="option in options"
        :key="option.action"
        class="w-full flex items-center gap-3 px-4 py-3 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        @click="handleOption(option.action)"
      >
        <component :is="option.icon" class="w-5 h-5" />
        <span>{{ option.label }}</span>
      </button>
    </div>
  </Modal>
</template>
