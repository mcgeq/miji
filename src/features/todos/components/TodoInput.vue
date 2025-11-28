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

    // 设置最大字符数限制
    const MAX_LENGTH = 100;

    // 计算当前字符数
    const currentLength = computed(() => newT.value.length);

    // 计算剩余字符数
    const remainingChars = computed(() => MAX_LENGTH - currentLength.value);

    // 判断是否接近限制
    const isNearLimit = computed(() => remainingChars.value <= 10 && remainingChars.value > 0);

    // 判断是否超出限制
    const isOverLimit = computed(() => remainingChars.value < 0);

    // 判断是否可以添加
    const canAdd = computed(() => {
      const trimmed = newT.value.trim();
      return trimmed.length > 0 && trimmed.length <= MAX_LENGTH;
    });

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
      if (canAdd.value) {
        props.onAdd(text);
        newT.value = '';
      }
    }

    return {
      newT,
      t,
      handleAdd,
      MAX_LENGTH,
      currentLength,
      remainingChars,
      isNearLimit,
      isOverLimit,
      canAdd,
    };
  },
});
</script>

<template>
  <div class="todo-input-container">
    <div class="flex items-center gap-2 w-full min-w-0">
      <!-- 字符数提示 -->
      <div
        class="text-xs px-2 py-1 rounded-md transition-all flex items-center gap-1 flex-shrink-0 min-w-fit"
        :class="{
          'text-gray-500 bg-gray-500/5': !isNearLimit && !isOverLimit,
          'text-amber-500 bg-amber-500/10': isNearLimit,
          'text-red-500 bg-red-500/10': isOverLimit,
        }"
      >
        <span class="font-medium">{{ currentLength }}/{{ MAX_LENGTH }}</span>
      </div>
      <input
        v-model="newT"
        :maxlength="MAX_LENGTH"
        type="text"
        :placeholder="t('todos.inputPlace')"
        class="flex-1 text-base px-3 py-1 border rounded-lg bg-transparent outline-none transition-all text-base-content border-gray-300 placeholder:text-gray-400 caret-info focus:border-blue-500 focus:ring-2 focus:ring-blue-200 dark:border-gray-600 dark:text-white dark:placeholder:text-gray-400 dark:focus:border-blue-400 dark:focus:ring-blue-900/30"
        :class="{ 'border-amber-500 focus:ring-amber-200': isNearLimit, 'border-red-500 focus:ring-red-200': isOverLimit }"
      >
      <button
        :disabled="!canAdd"
        class="flex items-center justify-center gap-1.5 text-sm font-semibold px-3 py-1.5 rounded-full bg-base-300 text-base-content shadow-sm transition-all cursor-pointer border-none hover:enabled:bg-neutral hover:enabled:shadow-md active:enabled:scale-95 disabled:opacity-60 disabled:cursor-not-allowed"
        @click="handleAdd"
      >
        <Plus class="h-5 w-5" />
      </button>
    </div>
  </div>
</template>

<style scoped>
/* 移动端响应式设计 */
@media (max-width: 768px) {
  .todo-input-container > div {
    flex-direction: column;
    align-items: stretch;
    gap: 0.375rem;
  }

  .todo-input-container > div > div:first-child {
    align-self: flex-end;
    order: 1;
  }

  .todo-input-container > div > input {
    order: 2;
    width: 100%;
    min-width: 0;
  }

  .todo-input-container > div > button {
    order: 3;
    align-self: center;
    width: fit-content;
  }
}

@media (prefers-color-scheme: dark) {
  .todo-input-container {
    background-color: #1F2937;
  }
}
</style>
