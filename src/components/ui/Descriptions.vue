<script setup>
const props = defineProps({
  modelValue: {
    type: String,
    default: '',
  },
  placeholder: {
    type: String,
    default: '',
  },
  showToggle: {
    type: Boolean,
    default: true,
  },
});
const emit = defineEmits(['update:modelValue', 'close']);
const { t } = useI18n();
const editable = ref(false);
const localValue = ref(props.modelValue);

watch(
  () => props.modelValue,
  val => {
    if (!editable.value) {
      localValue.value = val;
    }
  },
);
if (!props.modelValue || props.modelValue.trim() === '') {
  editable.value = true;
}
function toggleEdit() {
  if (editable.value) {
    emit('update:modelValue', localValue.value.trim());
    emit('close');
  }
  editable.value = !editable.value;
}
</script>

<template>
  <div class="input-container">
    <transition name="fade">
      <span v-if="!editable" key="display" class="input-display">
        <slot>{{ modelValue || placeholder }}</slot>
      </span>
    </transition>
    <transition name="fade">
      <input
        v-if="editable"
        key="input"
        v-model="localValue"
        type="text"
        class="input-field"
        :placeholder="placeholder"
      >
    </transition>
    <button
      v-if="showToggle"
      class="input-toggle-btn"
      @click="toggleEdit"
    >
      {{ editable ? t('todos.description.save') : t('todos.description.edit') }}
    </button>
  </div>
</template>

<style scoped lang="postcss">
/* 容器 */
.input-container {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  background-color: #fff;
  box-shadow: 0 2px 6px rgba(0,0,0,0.1);
  transition: box-shadow 0.3s ease, border-color 0.3s ease;
}

/* 显示文本 */
.input-display {
  color: #374151;
  flex: 1;
  word-break: break-word;
  transition: opacity 0.3s ease;
}

/* 输入框 */
.input-field {
  flex: 1;
  padding: 0.25rem 0.5rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  outline: none;
  box-shadow: inset 0 1px 2px rgba(0,0,0,0.05);
  transition: border-color 0.3s ease, box-shadow 0.3s ease, transform 0.15s ease;
}

.input-field:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 2px rgba(59,130,246,0.3);
  transform: scale(1.02);
}

/* 切换按钮 */
.input-toggle-btn {
  padding: 0.25rem 0.75rem;
  border-radius: 0.375rem;
  border: 1px solid #bfdbfe;
  background-color: #ffffff;
  color: #2563eb;
  font-size: 0.875rem;
  font-weight: 500;
  white-space: nowrap;
  cursor: pointer;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  transition: background-color 0.2s ease, box-shadow 0.2s ease, transform 0.15s ease;
}

.input-toggle-btn:hover {
  background-color: #eff6ff;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.input-toggle-btn:active {
  transform: scale(0.95);
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}

/* Fade 动画 */
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.25s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
.fade-enter-to, .fade-leave-from {
  opacity: 1;
}

/* 响应式 */
@media (max-width: 640px) {
  .input-container {
    flex-direction: column;
    align-items: stretch;
  }
  .input-toggle-btn {
    width: 100%;
    justify-content: center;
  }
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  .input-container { border-width: 2px; border-color: #000; }
  .input-field, .input-toggle-btn { border-width: 2px; }
}

/* 打印优化 */
@media print {
  .input-toggle-btn { display: none; }
}
</style>
