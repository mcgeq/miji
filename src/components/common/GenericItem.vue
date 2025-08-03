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
    class="relative ml-2 w-26 border border-gray-200 rounded-lg bg-white p-3 shadow-md transition-shadow duration-200 hover:shadow-lg"
  >
    <div
      class="absolute h-6 w-6 flex items-center justify-center rounded-full bg-blue-500 text-xs text-white font-bold -left-2 -top-2"
    >
      {{ totalUsageCount }}
    </div>

    <div class="mb-0">
      <input
        :value="modelValue[keyToEdit]"
        class="w-20 border border-gray-300 rounded-md bg-gray-50 px-3 py-2 text-gray-700 focus:border-transparent focus:outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-400"
        :readonly="readonly"
        :placeholder="String(keyToEdit)"
        :title="String(modelValue[keyToEdit])"
        @input="onInput"
      >
    </div>

    <div class="absolute -right-2 -top-2">
      <X
        class="h-6 w-6 flex cursor-pointer items-center justify-center rounded-full bg-white text-red-500 transition-transform duration-200 hover:scale-110 hover:text-red-700"
        @click="$emit('remove')"
      />
    </div>
  </div>
</template>
