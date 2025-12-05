<script setup lang="ts">
import { X } from 'lucide-vue-next';
import type { SubCategory } from '@/schema/money/category';
import { lowercaseFirstLetter } from '@/utils/string';

const props = defineProps<{
  modelValue: SubCategory;
  readonly?: boolean;
}>();

defineEmits<{
  (e: 'update:modelValue', val: SubCategory): void;
  (e: 'remove'): void;
}>();

const { t } = useI18n();

// 获取国际化的子分类名称
const subCategoryTitle = computed(() =>
  t(`common.subCategories.${lowercaseFirstLetter(props.modelValue.name)}`),
);
</script>

<template>
  <div
    class="relative p-1 border rounded-lg bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700 w-12 h-12 flex items-center justify-center shadow-sm hover:shadow-md transition-all cursor-pointer hover:scale-105"
    :title="subCategoryTitle"
  >
    <!-- 图标显示 -->
    <div class="text-2xl">
      {{ modelValue.icon }}
    </div>

    <!-- 删除按钮 -->
    <button
      v-if="!readonly"
      class="absolute -right-1 -top-1 p-0.5 bg-white dark:bg-gray-800 rounded-full border border-gray-200 dark:border-gray-700 text-red-500 hover:text-red-600 hover:scale-110 transition-all"
      @click.stop="$emit('remove')"
    >
      <X class="w-3 h-3" />
    </button>
  </div>
</template>
