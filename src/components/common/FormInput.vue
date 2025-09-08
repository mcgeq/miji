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
      class="text-gray-900 px-4 py-2 border border-gray-300 rounded-md bg-white w-full shadow-sm transition duration-200 dark:text-white focus:outline-none dark:border-gray-700 focus:border-transparent dark:bg-gray-900 disabled:opacity-60 disabled:cursor-not-allowed focus:ring-2 focus:ring-blue-500 placeholder-gray-400 dark:placeholder-gray-500"
      @input="onInput"
    >
    <FloatingErrorTip :visible="!!errorMsg" :message="errorMsg" />
  </div>
</template>
