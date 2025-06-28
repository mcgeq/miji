<!-- src/components/FormInput.vue -->
<template>
  <div class="relative">
    <input
      :id="name"
      :name="name"
      :type="type"
      :placeholder="placeholder"
      :disabled="disabled"
      :value="modelValue"
      @input="onInput"
      class="w-full px-4 py-2 rounded-md border border-gray-300 dark:border-gray-700
             bg-white dark:bg-gray-900 text-gray-900 dark:text-white
             placeholder-gray-400 dark:placeholder-gray-500
             focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent
             transition duration-200 disabled:opacity-60 disabled:cursor-not-allowed shadow-sm"
    />
    <FloatingErrorTip :visible="!!errorMsg" :message="errorMsg" />
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
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
