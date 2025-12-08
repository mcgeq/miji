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
  <div
    class="flex items-center gap-2 w-full px-3 py-2 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 shadow-sm transition-all duration-300 max-sm:flex-col max-sm:items-stretch"
  >
    <transition
      enter-active-class="transition-opacity duration-250"
      leave-active-class="transition-opacity duration-250"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <span
        v-if="!editable"
        key="display"
        class="flex-1 text-gray-700 dark:text-gray-300 wrap-break-word transition-opacity duration-300"
      >
        <slot>{{ modelValue || placeholder }}</slot>
      </span>
    </transition>
    <transition
      enter-active-class="transition-opacity duration-250"
      leave-active-class="transition-opacity duration-250"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <input
        v-if="editable"
        key="input"
        v-model="localValue"
        type="text"
        class="flex-1 px-2 py-1 border border-gray-300 dark:border-gray-600 rounded-md outline-none shadow-inner bg-white dark:bg-gray-700 text-gray-900 dark:text-white transition-all duration-300 focus:border-blue-500 focus:ring-2 focus:ring-blue-500/30 focus:scale-[1.02]"
        :placeholder="placeholder"
      />
    </transition>
    <button
      v-if="showToggle"
      class="px-3 py-1 rounded-md border border-blue-200 dark:border-blue-800 bg-white dark:bg-gray-800 text-blue-600 dark:text-blue-400 text-sm font-medium whitespace-nowrap cursor-pointer shadow-sm transition-all duration-200 hover:bg-blue-50 dark:hover:bg-blue-900/30 hover:shadow-md active:scale-95 active:shadow-sm max-sm:w-full max-sm:justify-center print:hidden"
      @click="toggleEdit"
    >
      {{ editable ? t('todos.description.save') : t('todos.description.edit') }}
    </button>
  </div>
</template>
