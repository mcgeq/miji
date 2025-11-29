<!-- src/components/TodoInput.vue -->
<script lang="ts">
import { Plus } from 'lucide-vue-next';
import { Button as UiButton } from '@/components/ui';

export default defineComponent({
  name: 'TodoInput',
  components: {
    UiButton,
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
      Plus,
    };
  },
});
</script>

<template>
  <div class="p-3 rounded-2xl bg-white dark:bg-gray-800 shadow-sm hover:shadow-md transition-shadow">
    <!-- 桌面端布局：横向排列 -->
    <div class="hidden md:flex items-center gap-2">
      <!-- 字符计数器 -->
      <div
        class="text-xs px-2.5 py-1.5 rounded-lg font-medium transition-all shrink-0" :class="[
          !isNearLimit && !isOverLimit && 'text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-700/50',
          isNearLimit && 'text-amber-600 dark:text-amber-400 bg-amber-100 dark:bg-amber-900/30',
          isOverLimit && 'text-red-600 dark:text-red-400 bg-red-100 dark:bg-red-900/30',
        ]"
      >
        {{ currentLength }}/{{ MAX_LENGTH }}
      </div>

      <!-- 输入框 -->
      <input
        v-model="newT"
        :maxlength="MAX_LENGTH"
        type="text"
        :placeholder="t('todos.inputPlace')"
        class="flex-1 min-w-0 px-4 py-2.5 text-base bg-transparent border rounded-xl outline-none transition-all text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500"
        :class="[
          !isNearLimit && !isOverLimit && 'border-gray-300 dark:border-gray-600 focus:border-blue-500 dark:focus:border-blue-400 focus:ring-2 focus:ring-blue-200 dark:focus:ring-blue-900/30',
          isNearLimit && 'border-amber-500 dark:border-amber-400 focus:border-amber-500 focus:ring-2 focus:ring-amber-200 dark:focus:ring-amber-900/30',
          isOverLimit && 'border-red-500 dark:border-red-400 focus:border-red-500 focus:ring-2 focus:ring-red-200 dark:focus:ring-red-900/30',
        ]"
        @keydown.enter="handleAdd"
      >

      <!-- 添加按钮 -->
      <UiButton
        variant="primary"
        size="md"
        circle
        :disabled="!canAdd"
        :icon="Plus"
        @click="handleAdd"
      />
    </div>

    <!-- 移动端布局：纵向排列 -->
    <div class="flex md:hidden flex-col gap-2">
      <!-- 字符计数器 - 右对齐 -->
      <div class="flex justify-end">
        <div
          class="text-xs px-2.5 py-1.5 rounded-lg font-medium transition-all" :class="[
            !isNearLimit && !isOverLimit && 'text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-700/50',
            isNearLimit && 'text-amber-600 dark:text-amber-400 bg-amber-100 dark:bg-amber-900/30',
            isOverLimit && 'text-red-600 dark:text-red-400 bg-red-100 dark:bg-red-900/30',
          ]"
        >
          {{ currentLength }}/{{ MAX_LENGTH }}
        </div>
      </div>

      <!-- 输入框 -->
      <input
        v-model="newT"
        :maxlength="MAX_LENGTH"
        type="text"
        :placeholder="t('todos.inputPlace')"
        class="w-full px-4 py-2.5 text-base bg-transparent border rounded-xl outline-none transition-all text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500"
        :class="[
          !isNearLimit && !isOverLimit && 'border-gray-300 dark:border-gray-600 focus:border-blue-500 dark:focus:border-blue-400 focus:ring-2 focus:ring-blue-200 dark:focus:ring-blue-900/30',
          isNearLimit && 'border-amber-500 dark:border-amber-400 focus:border-amber-500 focus:ring-2 focus:ring-amber-200 dark:focus:ring-amber-900/30',
          isOverLimit && 'border-red-500 dark:border-red-400 focus:border-red-500 focus:ring-2 focus:ring-red-200 dark:focus:ring-red-900/30',
        ]"
        @keydown.enter="handleAdd"
      >

      <!-- 添加按钮 - 居中 -->
      <div class="flex justify-center">
        <UiButton
          variant="primary"
          size="md"
          circle
          :disabled="!canAdd"
          :icon="Plus"
          @click="handleAdd"
        />
      </div>
    </div>
  </div>
</template>
