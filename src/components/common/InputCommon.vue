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
  <div class="todo-input-wrapper">
    <input
      v-model="newT"
      maxlength="1000"
      type="text"
      :placeholder="t('todos.inputPlace')"
      class="todo-input"
    >
    <button
      :disabled="!newT.trim()"
      class="todo-add-btn"
      @click="handleAdd"
    >
      <Plus class="h-5 w-5" />
    </button>
  </div>
</template>

<style scoped lang="postcss">
/* 容器样式 */
.todo-input-wrapper {
  padding: 0.75rem;
  border-radius: 1rem;
  width: 100%;
  background-color: var(--color-base-100);
  display: flex;
  align-items: center;
  gap: 0.75rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: all 0.2s ease-in-out;
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
</style>
