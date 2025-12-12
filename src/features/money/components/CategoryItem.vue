<script setup lang="ts">
  import { X } from 'lucide-vue-next';
  import type { Category } from '@/schema/money/category';
  import { lowercaseFirstLetter } from '@/utils/string';

  const props = defineProps<{
    modelValue: Category;
    readonly?: boolean;
  }>();

  defineEmits<{
    (e: 'update:modelValue', val: Category): void;
    (e: 'remove'): void;
  }>();

  const { t } = useI18n();

  // 获取国际化的分类名称
  const categoryTitle = computed(() =>
    t(`common.categories.${lowercaseFirstLetter(props.modelValue.name)}`),
  );
</script>

<template>
  <div
    class="relative p-1.5 border rounded-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700 w-14 h-14 flex items-center justify-center shadow-sm hover:shadow-md transition-all cursor-pointer hover:scale-105"
    :title="categoryTitle"
  >
    <!-- 图标显示 -->
    <div class="text-3xl">{{ modelValue.icon }}</div>

    <!-- 删除按钮 -->
    <button
      v-if="!readonly"
      class="absolute -right-1.5 -top-1.5 p-0.5 bg-white dark:bg-gray-800 rounded-full border border-gray-200 dark:border-gray-700 text-red-500 hover:text-red-600 hover:scale-110 transition-all"
      @click.stop="$emit('remove')"
    >
      <X class="w-3.5 h-3.5" />
    </button>
  </div>
</template>
