<template>
  <div class="flex items-center gap-2 bg-white shadow-md rounded-lg px-3 py-2 w-full border border-gray-200">
    <span v-if="!editable" class="w-full text-gray-700">
      <slot>
        {{ modelValue || placeholder }}
      </slot>
    </span>
    <input
      v-else
      v-model="localValue"
      type="text"
      class="border border-gray-300 rounded-md px-2 py-1 w-full shadow-inner outline-none focus:ring-2 focus:ring-blue-400"
      :placeholder="placeholder"
    />
    <button
      v-if="showToggle"
      @click="toggleEdit"
      class="text-sm text-blue-600 font-medium px-3 py-1 rounded-md shadow border border-blue-200 bg-white hover:bg-blue-50 hover:shadow-md transition duration-200 ease-in-out whitespace-nowrap"
    >
      {{ editable ? t('todos.desc.save') : t('todos.desc.edit') }}
    </button>
  </div>
</template>

<script setup>
import { useI18n } from 'vue-i18n';

const { t } = useI18n();
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
const toggleEdit = () => {
  if (editable.value) {
    emit('update:modelValue', localValue.value.trim());
    emit('close');
  }
  editable.value = !editable.value;
};
</script>
