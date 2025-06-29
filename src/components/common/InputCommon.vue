<!-- src/components/TodoInput.vue -->
<template>
  <div
    class="flex items-center gap-3 p-3 rounded-xl bg-white shadow-md dark:bg-gray-800 transition-all duration-200 hover:shadow-lg"
  >
    <input
      v-model="newT"
      maxlength="1000"
      type="text"
      :placeholder="t('input.inputPlace')"
      class="flex-1 bg-transparent outline-none text-base placeholder-gray-400
             px-3 py-1 rounded-lg border border-gray-300 focus:border-blue-500 focus:ring-2 focus:ring-blue-200
             dark:border-gray-600 dark:focus:border-blue-400 dark:focus:ring-blue-900/30
             transition-all duration-200"
    />
    <button
      :disabled="!newT.trim()"
      @click="handleAdd"
      class="px-3 py-1.5 bg-blue-500 text-white text-sm font-semibold rounded-full
             flex items-center gap-1.5 shadow-md hover:bg-blue-600 active:scale-95
             transition-transform duration-150 disabled:opacity-60 disabled:cursor-not-allowed"
    >
      <Plus class="w-5 h-5" />
    </button>
  </div>
</template>

<script lang="ts">
import { Plus } from 'lucide-vue-next';
import { useI18n } from 'vue-i18n';

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
      (val) => {
        if (val !== newT.value) {
          newT.value = val;
        }
      },
    );

    watch(newT, (val) => {
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
