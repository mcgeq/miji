<script setup lang="ts">
import { Input, Modal } from '@/components/ui';
import { DateUtils } from '@/utils/date';

const props = defineProps<{ dueDate: string | undefined; show: boolean }>();
const emit = defineEmits(['save', 'close']);

const localDueDate = ref(
  DateUtils.formatForDisplay(props.dueDate ?? DateUtils.getLocalISODateTimeWithOffset()),
);

const hasChanged = computed(() => {
  if (!props.dueDate) return false;
  return !DateUtils.isDateTimeContaining(props.dueDate, localDueDate.value);
});

function handleSave() {
  emit('save', localDueDate.value);
}
</script>

<template>
  <Modal
    :open="show"
    title="设置到期日期"
    size="md"
    :confirm-disabled="!hasChanged"
    @close="emit('close')"
    @confirm="handleSave"
  >
    <div class="space-y-3">
      <Input
        v-model="localDueDate"
        type="datetime-local"
        label="到期时间"
      />
      <div class="text-sm text-gray-500">
        当前: {{ localDueDate ? new Date(localDueDate).toLocaleString('zh-CN') : '未设置' }}
      </div>
    </div>
  </Modal>
</template>
