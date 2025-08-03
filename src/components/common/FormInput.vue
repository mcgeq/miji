<!-- src/components/FormInput.vue -->
<script setup lang="ts">
import FloatingErrorTip from './FloatingErrorTip.vue';

const props = defineProps<{
  modelValue: string;
  name: string;
  type?: string;
  placeholder?: string;
  disabled?: boolean;
  errors?: Record<string, string[] | null>;
}>();

const emit = defineEmits(['update:modelValue']);

const type = props.type ?? 'text';
const placeholder = props.placeholder ?? '';
const disabled = props.disabled ?? false;
const errors = props.errors ?? {};

const errorMsg = computed(() => {
  return errors?.[props.name]?.[0] ?? '';
});

function onInput(event: Event) {
  const target = event.target as HTMLInputElement | null;
  if (target) {
    emit('update:modelValue', target.value);
  }
}
</script>

<template>
  <div class="relative">
    <input
      :id="name"
      :name="name"
      :type="type"
      :placeholder="placeholder"
      :disabled="disabled"
      :value="modelValue"
      class="w-full border border-gray-300 rounded-md bg-white px-4 py-2 text-gray-900 shadow-sm transition duration-200 disabled:cursor-not-allowed dark:border-gray-700 focus:border-transparent dark:bg-gray-900 dark:text-white disabled:opacity-60 focus:outline-none focus:ring-2 focus:ring-blue-500 placeholder-gray-400 dark:placeholder-gray-500"
      @input="onInput"
    >
    <FloatingErrorTip :visible="!!errorMsg" :message="errorMsg" />
  </div>
</template>
