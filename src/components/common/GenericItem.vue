<script lang="ts" setup generic="T extends { [key: string]: unknown }">
import { X } from 'lucide-vue-next';
import { computed } from 'vue';

const props = defineProps<{
  modelValue: T;
  readonly?: boolean;
  displayKey?: keyof T;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: T): void;
  (e: 'remove'): void;
}>();

const modelValue = computed({
  get: () => props.modelValue,
  set: (val: T) => emit('update:modelValue', val),
});

const keyToEdit = computed(() => props.displayKey ?? ('name' as keyof T));

const totalUsageCount = computed(() => {
  const usage = modelValue.value.usage;

  if (!usage || typeof usage !== 'object')
    return 0;

  return Object.values(usage).reduce((sum, entry) => {
    const count
      = typeof entry === 'object' && 'count' in entry ? Number(entry.count) : 0;
    return sum + (Number.isNaN(count) ? 0 : count);
  }, 0);
});

function onInput(event: Event) {
  const newValue = (event.target as HTMLInputElement).value;
  modelValue.value = {
    ...modelValue.value,
    [keyToEdit.value]: newValue,
  };
}
</script>

<template>
  <div
    class="ml-2 p-3 border border-gray-200 rounded-lg bg-white w-26 shadow-md transition-shadow duration-200 relative hover:shadow-lg"
  >
    <div
      class="text-xs text-white font-bold rounded-full bg-blue-500 flex h-6 w-6 items-center justify-center absolute -left-2 -top-2"
    >
      {{ totalUsageCount }}
    </div>

    <div class="mb-0">
      <input
        :value="modelValue[keyToEdit]"
        class="text-gray-700 px-3 py-2 border border-gray-300 rounded-md bg-gray-50 w-20 focus:outline-none focus:border-transparent focus:ring-2 focus:ring-blue-500 placeholder-gray-400"
        :readonly="readonly"
        :placeholder="String(keyToEdit)"
        :title="String(modelValue[keyToEdit])"
        @input="onInput"
      >
    </div>

    <div class="absolute -right-2 -top-2">
      <X
        class="text-red-500 rounded-full bg-white flex h-6 w-6 cursor-pointer transition-transform duration-200 items-center justify-center hover:text-red-700 hover:scale-110"
        @click="$emit('remove')"
      />
    </div>
  </div>
</template>
