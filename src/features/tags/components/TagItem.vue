<template>
  <div
    class="relative w-26 p-3 ml-2 rounded-lg shadow-md bg-white border border-gray-200 hover:shadow-lg transition-shadow duration-200"
  >
    <div
      class="absolute -top-2 -left-2 w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center text-xs font-bold"
    >
      {{ 8 }}
    </div>

    <div class="mb-0">
      <input
        :value="modelValue?.name"
        @input="onNameInput"
        class="w-20 px-3 py-2 border border-gray-300 rounded-md text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent bg-gray-50 placeholder-gray-400"
        :readonly="readonly"
        placeholder="标签"
        :title="modelValue?.name"
      />
    </div>

    <div class="absolute -top-2 -right-2">
      <X
        class="w-6 h-6 text-red-500 bg-white rounded-full flex items-center justify-center hover:text-red-700 cursor-pointer hover:scale-110 transition-transform duration-200"
        @click="$emit('remove')"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { Tags } from '@/schema/tags';
import { X } from 'lucide-vue-next';
import { computed } from 'vue';

const props = defineProps<{
  modelValue: Tags;
  readonly?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', val: Tags): void;
  (e: 'remove'): void;
}>();

const modelValue = computed({
  get: () => props.modelValue,
  set: (val: Tags) => emit('update:modelValue', val),
});

const onNameInput = (event: Event) => {
  const newName = (event.target as HTMLInputElement).value;
  modelValue.value = {
    ...modelValue.value,
    name: newName,
  };
};
</script>
