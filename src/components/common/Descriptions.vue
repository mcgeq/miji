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
  (val) => {
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
  <div class="w-full flex items-center gap-2 border border-gray-200 rounded-lg bg-white px-3 py-2 shadow-md">
    <span v-if="!editable" class="w-full text-gray-700">
      <slot>
        {{ modelValue || placeholder }}
      </slot>
    </span>
    <input
      v-else
      v-model="localValue"
      type="text"
      class="w-full border border-gray-300 rounded-md px-2 py-1 shadow-inner outline-none focus:ring-2 focus:ring-blue-400"
      :placeholder="placeholder"
    >
    <button
      v-if="showToggle"
      class="whitespace-nowrap border border-blue-200 rounded-md bg-white px-3 py-1 text-sm text-blue-600 font-medium shadow transition duration-200 ease-in-out hover:bg-blue-50 hover:shadow-md"
      @click="toggleEdit"
    >
      {{ editable ? t('todos.description.save') : t('todos.description.edit') }}
    </button>
  </div>
</template>
