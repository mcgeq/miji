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
  <div class="todo-input-wrapper">
    <div class="input-container">
      <!-- 字符数提示 -->
      <div
        class="char-counter"
        :class="{
          'char-counter-normal': !isNearLimit && !isOverLimit,
          'char-counter-warning': isNearLimit,
          'char-counter-error': isOverLimit,
        }"
      >
        <span class="char-count">{{ currentLength }}/{{ MAX_LENGTH }}</span>
      </div>
      <input
        v-model="newT"
        :maxlength="MAX_LENGTH"
        type="text"
        :placeholder="t('todos.inputPlace')"
        class="todo-input"
        :class="{ 'input-warning': isNearLimit, 'input-error': isOverLimit }"
      >
      <button
        :disabled="!canAdd"
        class="todo-add-btn"
        @click="handleAdd"
      >
        <Plus class="h-5 w-5" />
      </button>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 容器样式 */
.todo-input-wrapper {
  padding: 0.75rem;
  border-radius: 1rem;
  background-color: var(--color-base-100);
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: all 0.2s ease-in-out;
}

/* 输入容器 */
.input-container {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  min-width: 0; /* 防止flex子元素溢出 */
}

.todo-input-wrapper:hover {
  box-shadow: 0 4px 12px rgba(0,0,0,0.15); /* hover:shadow-lg */
}

/* 输入框样式 */
.todo-input {
  flex: 1;                          /* flex-1 */
  font-size: 1rem;                  /* text-base */
  padding: 0.25rem 0.75rem;        /* px-3 py-1 */
  border: 1px solid #D1D5DB;       /* border-gray-300 */
  border-radius: 0.5rem;            /* rounded-lg */
  background-color: transparent;    /* bg-transparent */
  outline: none;
  transition: all 0.2s ease-in-out;
  color: #111827;                   /* 默认文字色 */
  caret-color: #2563EB;             /* 蓝色光标 */
}

.todo-input::placeholder {
  color: #9CA3AF;                   /* placeholder-gray-400 */
}

/* 输入框聚焦状态 */
.todo-input:focus {
  border-color: #3B82F6;            /* focus:border-blue-500 */
  box-shadow: 0 0 0 2px rgba(59,130,246,0.2); /* focus:ring-2 focus:ring-blue-200 */
}

/* 输入框警告状态 */
.todo-input.input-warning {
  border-color: #F59E0B;            /* border-amber-500 */
}

.todo-input.input-warning:focus {
  border-color: #F59E0B;
  box-shadow: 0 0 0 2px rgba(245,158,11,0.2);
}

/* 输入框错误状态 */
.todo-input.input-error {
  border-color: #EF4444;            /* border-red-500 */
}

.todo-input.input-error:focus {
  border-color: #EF4444;
  box-shadow: 0 0 0 2px rgba(239,68,68,0.2);
}

/* 暗黑模式输入框 */
@media (prefers-color-scheme: dark) {
  .todo-input-wrapper {
    background-color: #1F2937;      /* dark:bg-gray-800 */
  }

  .todo-input {
    border-color: #4B5563;          /* dark:border-gray-600 */
    color: #F9FAFB;                 /* dark:text */
  }

  .todo-input:focus {
    border-color: #3B82F6;          /* dark:focus:border-blue-400 */
    box-shadow: 0 0 0 2px rgba(59,130,246,0.15); /* dark:focus:ring-blue-900/30 */
  }

  .todo-input::placeholder {
    color: #9CA3AF;
  }
}

/* 添加按钮样式 */
.todo-add-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;                     /* gap-1.5 */
  font-size: 0.875rem;               /* text-sm */
  font-weight: 600;                   /* font-semibold */
  padding: 0.375rem 0.75rem;         /* px-3 py-1.5 */
  border-radius: 9999px;              /* rounded-full */
  background-color: var(--color-primary);          /* bg-blue-500 */
  color: var(--color-primary-soft);                     /* text-white */
  box-shadow: 0 2px 4px rgba(0,0,0,0.1); /* shadow-md */
  transition: all 0.15s ease-in-out;  /* transition-transform duration-150 */
  cursor: pointer;
  border: none;
}

/* 按钮 hover */
.todo-add-btn:hover:enabled {
  background-color: var(--color-neutral);          /* hover:bg-blue-600 */
  box-shadow: 0 4px 8px rgba(0,0,0,0.15);
}

/* 按钮 active */
.todo-add-btn:active:enabled {
  transform: scale(0.95);            /* active:scale-95 */
}

/* 按钮禁用状态 */
.todo-add-btn:disabled {
  opacity: 0.6;                       /* disabled:opacity-60 */
  cursor: not-allowed;                /* disabled:cursor-not-allowed */
}

/* 字符计数器样式 */
.char-counter {
  font-size: 0.75rem;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  gap: 0.25rem;
  flex-shrink: 0;
  min-width: fit-content;
}

/* 移动端响应式设计 */
@media (max-width: 768px) {
  .input-container {
    flex-direction: column;
    align-items: stretch;
    gap: 0.375rem;
  }

  .char-counter {
    align-self: flex-end;
    order: 1;
  }

  .todo-input {
    order: 2;
    width: 100%;
    min-width: 0;
  }

  .todo-add-btn {
    order: 3;
    align-self: center;
    width: fit-content;
  }
}

.char-counter-normal {
  color: #6B7280;                     /* text-gray-500 */
  background-color: rgba(107,114,128,0.05);
}

.char-counter-warning {
  color: #F59E0B;                    /* text-amber-500 */
  background-color: rgba(245,158,11,0.1);
}

.char-counter-error {
  color: #EF4444;                     /* text-red-500 */
  background-color: rgba(239,68,68,0.1);
}

.char-count {
  font-weight: 500;
}
</style>
