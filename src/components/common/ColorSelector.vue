<script setup lang="ts">
import { onMounted, onUnmounted, ref } from 'vue';
import { COLORS_MAP } from '@/constants/moneyConst';
import type { DefaultColors } from '@/schema/common';

interface Props {
  modelValue: string;
  colorNames?: DefaultColors[];
}

// 定义 props
const props = withDefaults(defineProps<Props>(), {
  colorNames: () => COLORS_MAP,
});
// 定义 emits
const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();
const locale = computed(() => getCurrentLocale());
const colors = computed(() => COLORS_MAP.map(v => v.code));
// 响应式数据
const isOpen = ref(false);
const colorSelectorRef = ref<HTMLElement | null>(null);

// 获取颜色名称
function getColorName(colorValue: string): string {
  const color: DefaultColors | undefined = props.colorNames
    .filter(v => v.code === colorValue)
    .pop();
  return color
    ? locale.value === 'zh-CN'
      ? color.nameZh
      : color.nameEn
    : '自定义颜色';
}

// 切换下拉状态
function toggleDropdown() {
  isOpen.value = !isOpen.value;
}

// 选择颜色
function selectColor(color: string) {
  emit('update:modelValue', color);
  isOpen.value = false;
}

// 点击外部关闭下拉
function handleClickOutside(event: Event) {
  if (
    colorSelectorRef.value
    && !colorSelectorRef.value.contains(event.target as Node)
  ) {
    isOpen.value = false;
  }
}

// 生命周期钩子
onMounted(() => {
  document.addEventListener('mousedown', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('mousedown', handleClickOutside);
});
</script>

<template>
  <div ref="colorSelectorRef" class="relative w-2/3">
    <!-- 触发按钮 -->
    <button
      type="button"
      class="w-full flex items-center justify-between border border-gray-300 rounded-lg bg-white px-3 py-2 transition-all duration-200 focus:border-transparent hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500"
      @click="toggleDropdown"
    >
      <div class="flex items-center gap-2">
        <div
          class="h-5 w-5 border-2 border-gray-300 rounded-full"
          :style="{ backgroundColor: modelValue }"
        />
        <span class="text-sm text-gray-700">{{ getColorName(modelValue) }}</span>
      </div>
      <svg
        class="h-4 w-4 text-gray-400 transition-transform duration-200"
        :class="{ 'rotate-180': isOpen }"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
      </svg>
    </button>

    <!-- 颜色网格下拉 -->
    <div
      v-if="isOpen"
      class="absolute left-0 right-0 top-full z-50 mt-1 border border-gray-200 rounded-lg bg-white p-3 shadow-lg"
    >
      <div class="grid grid-cols-5 gap-2">
        <button
          v-for="color in colors"
          :key="color"
          type="button"
          class="h-8 w-8 border-2 rounded-full transition-all duration-200 hover:scale-110 focus:outline-none" :class="[
            modelValue === color
              ? 'border-gray-800 shadow-lg ring-2 ring-blue-200'
              : 'border-gray-300 hover:border-gray-500',
          ]"
          :style="{ backgroundColor: color }"
          :title="getColorName(color)"
          @click="selectColor(color)"
        />
      </div>
    </div>
  </div>
</template>
