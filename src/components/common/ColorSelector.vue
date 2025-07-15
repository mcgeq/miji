<template>
  <div class="w-2/3 relative" ref="colorSelectorRef">
    <!-- 触发按钮 -->
    <button
      type="button"
      @click="toggleDropdown"
      class="w-full flex items-center justify-between px-3 py-2 border border-gray-300 rounded-lg bg-white hover:border-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200"
    >
      <div class="flex items-center gap-2">
        <div 
          class="w-5 h-5 rounded-full border-2 border-gray-300"
          :style="{ backgroundColor: modelValue }"
        ></div>
        <span class="text-sm text-gray-700">{{ getColorName(modelValue) }}</span>
      </div>
      <svg 
        class="w-4 h-4 text-gray-400 transition-transform duration-200"
        :class="{ 'rotate-180': isOpen }"
        fill="none" 
        stroke="currentColor" 
        viewBox="0 0 24 24"
      >
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
      </svg>
    </button>
    
    <!-- 颜色网格下拉 -->
    <div 
      v-if="isOpen"
      class="absolute top-full left-0 right-0 mt-1 bg-white border border-gray-200 rounded-lg shadow-lg z-50 p-3"
    >
      <div class="grid grid-cols-5 gap-2">
        <button
          v-for="color in colors"
          :key="color"
          type="button"
          @click="selectColor(color)"
          :class="[
            'w-8 h-8 rounded-full border-2 hover:scale-110 transition-all duration-200 focus:outline-none',
            modelValue === color 
              ? 'border-gray-800 shadow-lg ring-2 ring-blue-200' 
              : 'border-gray-300 hover:border-gray-500'
          ]"
          :style="{ backgroundColor: color }"
          :title="getColorName(color)"
        ></button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { COLORS_MAP } from '@/constants/moneyConst';
import { DefaultColors } from '@/schema/common';
import { ref, onMounted, onUnmounted } from 'vue';

interface Props {
  modelValue: string;
  colorNames: DefaultColors[];
}

const locale = computed(() => getCurrentLocale());
const colors = computed(() => COLORS_MAP.map((v) => v.code));
// 定义 props
const props = withDefaults(defineProps<Props>(), {
  colorNames: () => COLORS_MAP,
});

// 定义 emits
const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

// 响应式数据
const isOpen = ref(false);
const colorSelectorRef = ref<HTMLElement | null>(null);

// 获取颜色名称
const getColorName = (colorValue: string): string => {
  const color: DefaultColors | undefined = props.colorNames
    .filter((v) => v.code === colorValue)
    .pop();
  return color
    ? locale.value === 'zh-CN'
      ? color.nameZh
      : color.nameEn
    : '自定义颜色';
};

// 切换下拉状态
const toggleDropdown = () => {
  isOpen.value = !isOpen.value;
};

// 选择颜色
const selectColor = (color: string) => {
  emit('update:modelValue', color);
  isOpen.value = false;
};

// 点击外部关闭下拉
const handleClickOutside = (event: Event) => {
  if (
    colorSelectorRef.value &&
    !colorSelectorRef.value.contains(event.target as Node)
  ) {
    isOpen.value = false;
  }
};

// 生命周期钩子
onMounted(() => {
  document.addEventListener('mousedown', handleClickOutside);
});

onUnmounted(() => {
  document.removeEventListener('mousedown', handleClickOutside);
});
</script>
