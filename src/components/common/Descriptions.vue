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
  <div class="px-3 py-2 border border-gray-200 rounded-lg bg-white flex gap-2 w-full shadow-md items-center">
    <span v-if="!editable" class="text-gray-700 w-full">
      <slot>
        {{ modelValue || placeholder }}
      </slot>
    </span>
    <input
      v-else
      v-model="localValue"
      type="text"
      class="px-2 py-1 outline-none border border-gray-300 rounded-md w-full shadow-inner focus:ring-2 focus:ring-blue-400"
      :placeholder="placeholder"
    >
    <button
      v-if="showToggle"
      class="text-sm text-blue-600 font-medium px-3 py-1 border border-blue-200 rounded-md bg-white whitespace-nowrap shadow transition duration-200 ease-in-out hover:bg-blue-50 hover:shadow-md"
      @click="toggleEdit"
    >
      {{ editable ? t('todos.description.save') : t('todos.description.edit') }}
    </button>
  </div>
</template>
