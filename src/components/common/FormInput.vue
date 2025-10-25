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
      class="custom-input"
      @input="onInput"
    >
    <FloatingErrorTip
      :visible="!!errorMsg"
      :message="errorMsg"
      class="error-tip"
    />
  </div>
</template>

<style scoped>
/* 容器样式 */
div.relative {
  position: relative;
}

/* 输入框核心样式 */
.custom-input {
  /* 基础样式 */
  width: 100%;
  padding: 0.5rem 1rem;
  font-size: 1rem;
  line-height: 1.5;

  /* 文字样式 */
  color: var(--color-base-content); /* text-gray-900 */
  background-color: var(--color-base-100); /* bg-white */

  /* 边框样式 */
  border: 1px solid var(--color-neutral); /* border-gray-300 */
  border-radius: 0.375rem; /* rounded-md */

  /* 阴影与过渡 */
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05); /* shadow-sm */
  transition-property: all;
  transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
  transition-duration: 200ms; /* duration-200 */

  /* 其他状态 */
  appearance: none;
  -webkit-appearance: none;
}

/* 焦点状态 */
.custom-input:focus {
  outline: none; /* focus:outline-none */
  border-color: transparent; /* focus:border-transparent */
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.5); /* focus:ring-2 focus:ring-blue-500 */
}

/* 禁用状态 */
.custom-input:disabled {
  opacity: 0.6; /* disabled:opacity-60 */
  cursor: not-allowed; /* disabled:cursor-not-allowed */
}

/* 占位符样式 */
.custom-input::placeholder {
  color: var(--color-gray-400); /* placeholder-gray-400 */
  opacity: 1; /* 防止某些浏览器默认淡化 */
}

/* 黑暗模式适配 */
@media (prefers-color-scheme: dark) {
  .custom-input {
    color: var(--color-base-content); /* dark:text-white */
    background-color: var(--color-gray-800); /* dark:bg-gray-900 */
    border-color: var(--color-gray-600); /* dark:border-gray-700 */
  }

  .custom-input::placeholder {
    color: var(--color-gray-300); /* dark:placeholder-gray-500 */
  }
}

/* 错误提示样式 */
.error-tip {
  /* 定位相关 */
  position: absolute;
  top: 100%;
  left: 0;
  margin-top: 0.25rem;
  z-index: 10; /* 确保显示在输入框上方 */

  /* 文字样式 */
  font-size: 0.875rem;
  line-height: 1.25;
  color: var(--color-error); /* 错误提示红 */

  /* 背景与边框 */
  background-color: var(--color-error-50);
  border: 1px solid var(--color-error-200);
  border-radius: 0.25rem;
  padding: 0.25rem 0.5rem;

  /* 初始隐藏 */
  display: none;
}

/* 显示错误提示 */
.error-tip[visible] {
  display: block;
}
</style>
