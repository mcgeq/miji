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
  <div ref="colorSelectorRef" class="color-selector">
    <!-- 触发按钮 -->
    <button
      type="button"
      class="color-selector__trigger"
      @click="toggleDropdown"
    >
      <div class="color-selector__preview">
        <div
          class="color-selector__circle"
          :style="{ backgroundColor: modelValue }"
        />
        <span class="color-selector__label">{{ getColorName(modelValue) }}</span>
      </div>
      <svg
        class="color-selector__arrow"
        :class="{ rotate: isOpen }"
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
      class="color-selector__dropdown"
    >
      <div class="color-selector__grid">
        <button
          v-for="color in colors"
          :key="color"
          type="button"
          class="color-selector__option"
          :class="{ active: modelValue === color }"
          :style="{ backgroundColor: color }"
          :title="getColorName(color)"
          @click="selectColor(color)"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.color-selector {
  position: relative;
  width: 66.666%; /* w-2/3 */
}

/* 触发按钮 */
.color-selector__trigger {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
  padding: 0.5rem 0.75rem; /* px-3 py-2 */
  border: 1px solid #d1d5db; /* gray-300 */
  border-radius: 0.5rem; /* rounded-lg */
  background-color: #fff;
  transition: all 0.2s ease-in-out;
  cursor: pointer;
}

.color-selector__trigger:hover {
  border-color: #9ca3af; /* gray-400 */
}

.color-selector__trigger:focus {
  outline: none;
  border-color: transparent;
  box-shadow: 0 0 0 2px #3b82f6; /* blue-500 */
}

/* 左侧预览 */
.color-selector__preview {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.color-selector__circle {
  width: 1.25rem;  /* h-5 */
  height: 1.25rem; /* w-5 */
  border-radius: 9999px;
  border: 2px solid #d1d5db; /* gray-300 */
}

.color-selector__label {
  font-size: 0.875rem; /* text-sm */
  color: #374151; /* gray-700 */
}

/* 下拉箭头 */
.color-selector__arrow {
  width: 1rem;
  height: 1rem;
  color: #9ca3af; /* gray-400 */
  transition: transform 0.2s ease-in-out;
}

.color-selector__arrow.rotate {
  transform: rotate(180deg);
}

/* 下拉容器 */
.color-selector__dropdown {
  position: absolute;
  top: 100%;
  left: 0;
  right: 0;
  margin-top: 0.25rem; /* mt-1 */
  padding: 0.75rem; /* p-3 */
  border: 1px solid #e5e7eb; /* gray-200 */
  border-radius: 0.5rem;
  background-color: #fff;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1); /* shadow-lg */
  z-index: 50;
}

/* 网格 */
.color-selector__grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.5rem;
}

/* 颜色按钮 */
.color-selector__option {
  width: 2rem;  /* h-8 */
  height: 2rem; /* w-8 */
  border-radius: 9999px;
  border: 2px solid #d1d5db; /* gray-300 */
  transition: all 0.2s ease-in-out;
  cursor: pointer;
}

.color-selector__option:hover {
  transform: scale(1.1);
  border-color: #6b7280; /* gray-500 */
}

.color-selector__option:focus {
  outline: none;
}

.color-selector__option.active {
  border-color: #111827; /* gray-800 */
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.15);
  box-shadow: 0 0 0 2px #bfdbfe; /* ring-2 ring-blue-200 */
}
</style>
