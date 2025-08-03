<!-- src/components/TodoInput.vue -->
<script lang="ts">
import { Plus } from 'lucide-vue-next';

export default defineComponent({
  name: 'TodoInput',
  components: {
    Plus,
  },
  props: {
    modelValue: {
      type: String,
      required: true,
    },
    onAdd: {
      type: Function as PropType<(text: string) => void>,
      required: true,
    },
  },
  emits: ['update:modelValue'],
  setup(props, { emit }) {
    const newT = ref(props.modelValue);
    const { t } = useI18n();

    watch(
      () => props.modelValue,
      val => {
        if (val !== newT.value) {
          newT.value = val;
        }
      },
    );

    watch(newT, val => {
      emit('update:modelValue', val);
    });

    function handleAdd() {
      const text = newT.value.trim();
      if (text) {
        props.onAdd(text);
        newT.value = '';
      }
    }

    return {
      newT,
      t,
      handleAdd,
    };
  },
});
</script>

<template>
  <div
    class="flex items-center gap-3 rounded-xl bg-white p-3 shadow-md transition-all duration-200 dark:bg-gray-800 hover:shadow-lg"
  >
    <input
      v-model="newT" maxlength="1000" type="text" :placeholder="t('todos.inputPlace')" class="flex-1 border border-gray-300 rounded-lg bg-transparent px-3 py-1 text-base outline-none transition-all duration-200 dark:border-gray-600 focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:focus:border-blue-400 dark:focus:ring-blue-900/30 placeholder-gray-400"
    >
    <button
      :disabled="!newT.trim()" class="flex items-center gap-1.5 rounded-full bg-blue-500 px-3 py-1.5 text-sm text-white font-semibold shadow-md transition-transform duration-150 active:scale-95 disabled:cursor-not-allowed hover:bg-blue-600 disabled:opacity-60" @click="handleAdd"
    >
      <Plus class="h-5 w-5" />
    </button>
  </div>
</template>
