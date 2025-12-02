<script setup lang="ts">
import { Disclosure, DisclosureButton, DisclosurePanel, Popover, PopoverButton, PopoverPanel, RadioGroup, RadioGroupOption } from '@headlessui/vue';
import { COLORS_MAP, EXTENDED_COLORS_MAP } from '@/constants/moneyConst';
import type { DefaultColors } from '@/schema/common';

interface Props {
  modelValue: string;
  colorNames?: DefaultColors[];
  extended?: boolean; // 是否使用扩展颜色调色板
  showCustomColor?: boolean; // 是否显示自定义颜色选择器
  showCategories?: boolean; // 是否显示颜色分类
  professional?: boolean; // 是否使用专业颜色选择器界面
  showRandomButton?: boolean; // 是否显示随机颜色按钮
  randomColorMode?: 'full' | 'smart'; // 随机颜色模式：full=完全随机，smart=智能随机（避免极端）
  width?: string; // 组件宽度：full, 2/3, 1/2 等
}

// 定义 props
const props = withDefaults(defineProps<Props>(), {
  colorNames: () => COLORS_MAP,
  extended: false,
  showCustomColor: true,
  showCategories: false,
  professional: false,
  showRandomButton: false,
  randomColorMode: 'smart',
  width: '2/3',
});

// 定义 emits
const emit = defineEmits<{
  'update:modelValue': [value: string];
}>();

const locale = computed(() => useLocaleStore().getCurrentLocale());

// 根据配置选择颜色调色板
const availableColors = computed(() => {
  if (props.extended) {
    return EXTENDED_COLORS_MAP;
  }
  return props.colorNames || COLORS_MAP;
});

// 颜色分类 - 总是基于 EXTENDED_COLORS_MAP 进行分类
const colorCategories = computed(() => {
  // 如果启用了分类功能，始终使用 EXTENDED_COLORS_MAP
  const sourceColors = props.showCategories ? EXTENDED_COLORS_MAP : availableColors.value;
  if (!props.showCategories || !props.extended) {
    return { all: sourceColors };
  }
  const categories = {
    basic: sourceColors.slice(0, 10), // 基础色系 (前10个)
    extended: sourceColors.slice(10, 20), // 扩展色系 (10-19)
    light: sourceColors.slice(20, 30), // 柔和色系 (20-29)
    special: sourceColors.slice(30, 40), // 特殊色系 (30-39)
  };
  return categories;
});

const colors = computed(() => availableColors.value.map(v => v.code));

// 响应式数据
const activeCategory = ref('all');
const customColor = ref('');

// 专业颜色选择器相关状态
const hue = ref(0); // 色相 (0-360)
const saturation = ref(100); // 饱和度 (0-100)
const lightness = ref(50); // 亮度 (0-100)
const rgb = ref({ r: 255, g: 0, b: 0 }); // RGB 值
const hex = ref('#FF0000'); // 十六进制值
const isDragging = ref(false);
const dragType = ref<'hue' | 'saturation' | null>(null);

// 颜色转换函数
function hexToRgb(hex: string): { r: number; g: number; b: number } {
  const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
  return result
    ? {
        r: Number.parseInt(result[1], 16),
        g: Number.parseInt(result[2], 16),
        b: Number.parseInt(result[3], 16),
      }
    : { r: 0, g: 0, b: 0 };
}

function rgbToHex(r: number, g: number, b: number): string {
  return `#${((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1).toUpperCase()}`;
}

function rgbToHsl(r: number, g: number, b: number): { h: number; s: number; l: number } {
  r /= 255;
  g /= 255;
  b /= 255;

  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  let h = 0;
  let s = 0;
  const l = (max + min) / 2;

  if (max !== min) {
    const d = max - min;
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min);

    switch (max) {
      case r:
        h = (g - b) / d + (g < b ? 6 : 0);
        break;
      case g:
        h = (b - r) / d + 2;
        break;
      case b:
        h = (r - g) / d + 4;
        break;
    }
    h /= 6;
  }
  return {
    h: Math.round(h * 360),
    s: Math.round(s * 100),
    l: Math.round(l * 100),
  };
}

function hslToRgb(h: number, s: number, l: number): { r: number; g: number; b: number } {
  h /= 360;
  s /= 100;
  l /= 100;

  const hue2rgb = (p: number, q: number, t: number) => {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  };

  let r: number;
  let g: number;
  let b: number;

  if (s === 0) {
    r = g = b = l;
  } else {
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    const p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }

  return {
    r: Math.round(r * 255),
    g: Math.round(g * 255),
    b: Math.round(b * 255),
  };
}

// 初始化颜色值
function initializeColor(colorValue: string) {
  const rgbValue = hexToRgb(colorValue);
  const hslValue = rgbToHsl(rgbValue.r, rgbValue.g, rgbValue.b);
  rgb.value = rgbValue;
  hex.value = colorValue;
  hue.value = hslValue.h;
  saturation.value = hslValue.s;
  lightness.value = hslValue.l;
}

// 更新颜色值
function updateColor() {
  const rgbValue = hslToRgb(hue.value, saturation.value, lightness.value);
  rgb.value = rgbValue;
  hex.value = rgbToHex(rgbValue.r, rgbValue.g, rgbValue.b);
  emit('update:modelValue', hex.value);
}

// 获取颜色名称
function getColorName(colorValue: string): string {
  // 优先从 EXTENDED_COLORS_MAP 查找，如果没有则从 availableColors 查找
  const color: DefaultColors | undefined = EXTENDED_COLORS_MAP
    .concat(availableColors.value)
    .filter(v => v.code === colorValue)
    .pop();
  return color
    ? locale.value === 'zh-CN'
      ? color.nameZh
      : color.nameEn
    : '自定义颜色';
}

// 初始化面板（Popover 打开时调用）
function initializePanel() {
  customColor.value = '';
  // 初始化专业颜色选择器
  if (props.professional) {
    initializeColor(props.modelValue);
  }
}

// 专业颜色选择器交互函数
function handleSaturationMouseDown(event: MouseEvent) {
  isDragging.value = true;
  dragType.value = 'saturation';
  handleSaturationMouseMove(event);
  const handleMouseMove = (e: MouseEvent) => handleSaturationMouseMove(e);
  const handleMouseUp = () => {
    isDragging.value = false;
    dragType.value = null;
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  };
  document.addEventListener('mousemove', handleMouseMove);
  document.addEventListener('mouseup', handleMouseUp);
}

function handleSaturationMouseMove(event: MouseEvent) {
  if (!isDragging.value || dragType.value !== 'saturation') return;
  const rect = (event.target as HTMLElement).getBoundingClientRect();
  const x = Math.max(0, Math.min(rect.width, event.clientX - rect.left));
  const y = Math.max(0, Math.min(rect.height, event.clientY - rect.top));
  saturation.value = Math.round((x / rect.width) * 100);
  lightness.value = Math.round((1 - y / rect.height) * 100);
  updateColor();
}

function handleHueMouseDown(event: MouseEvent) {
  isDragging.value = true;
  dragType.value = 'hue';
  handleHueMouseMove(event);
  const handleMouseMove = (e: MouseEvent) => handleHueMouseMove(e);
  const handleMouseUp = () => {
    isDragging.value = false;
    dragType.value = null;
    document.removeEventListener('mousemove', handleMouseMove);
    document.removeEventListener('mouseup', handleMouseUp);
  };
  document.addEventListener('mousemove', handleMouseMove);
  document.addEventListener('mouseup', handleMouseUp);
}

function handleHueMouseMove(event: MouseEvent) {
  if (!isDragging.value || dragType.value !== 'hue') return;
  const rect = (event.target as HTMLElement).getBoundingClientRect();
  const y = Math.max(0, Math.min(rect.height, event.clientY - rect.top));
  hue.value = Math.round((y / rect.height) * 360);
  updateColor();
}

// 处理十六进制输入
function handleHexInput() {
  if (isValidHexColor(hex.value)) {
    initializeColor(hex.value);
    emit('update:modelValue', hex.value);
  }
}

// 处理 RGB 输入
function handleRgbInput() {
  const rgbValue = hslToRgb(hue.value, saturation.value, lightness.value);
  hex.value = rgbToHex(rgbValue.r, rgbValue.g, rgbValue.b);
  emit('update:modelValue', hex.value);
}

// 复制颜色值
function copyColorValue(value: string) {
  navigator.clipboard.writeText(value);
  // 可以添加 toast 提示
}

// 选择颜色
function selectColor(color: string, close?: () => void) {
  emit('update:modelValue', color);
  close?.();
}

// 颜色分类选项
const categoryOptions = computed(() => [
  { value: 'all', label: locale.value === 'zh-CN' ? '全部' : 'All' },
  { value: 'basic', label: locale.value === 'zh-CN' ? '基础色' : 'Basic' },
  { value: 'extended', label: locale.value === 'zh-CN' ? '扩展色' : 'Extended' },
  { value: 'light', label: locale.value === 'zh-CN' ? '柔和色' : 'Light' },
  { value: 'special', label: locale.value === 'zh-CN' ? '特殊色' : 'Special' },
]);

// 获取当前分类的颜色
function getCurrentCategoryColors() {
  if (!props.showCategories || !props.extended) {
    return colors.value;
  }
  const categoryColors = colorCategories.value[activeCategory.value as keyof typeof colorCategories.value];
  return categoryColors ? (categoryColors as DefaultColors[]).map((v: DefaultColors) => v.code) : colors.value;
}

// 处理自定义颜色输入
function handleCustomColorInput(close?: () => void) {
  if (customColor.value && isValidHexColor(customColor.value)) {
    selectColor(customColor.value, close);
  }
}

// 验证十六进制颜色值
function isValidHexColor(color: string): boolean {
  return /^#[a-f0-9]{6}$|^#[a-f0-9]{3}$/i.test(color);
}

// 生成随机颜色
function generateRandomColor(close?: () => void) {
  if (props.randomColorMode === 'full') {
    // 完全随机（0-F）
    const chars = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'];
    let color = '#';
    for (let i = 0; i < 6; i++) {
      color += chars[Math.floor(Math.random() * chars.length)];
    }
    emit('update:modelValue', color);
  } else {
    // 智能随机：避免太暗或太浅的颜色，确保视觉效果好
    const hue = Math.floor(Math.random() * 360); // 0-360度
    const saturation = 60 + Math.floor(Math.random() * 30); // 60-90%
    const lightness = 45 + Math.floor(Math.random() * 20); // 45-65%
    const rgb = hslToRgb(hue, saturation, lightness);
    const hex = rgbToHex(rgb.r, rgb.g, rgb.b);
    emit('update:modelValue', hex);
  }
  close?.();
}

// 计算宽度类
const widthClass = computed(() => {
  const widthMap: Record<string, string> = {
    'full': 'w-full',
    'half': 'w-half',
    '1/2': 'w-half',
    'two-thirds': 'w-two-thirds',
    '2/3': 'w-two-thirds',
    'third': 'w-third',
    '1/3': 'w-third',
  };
  return widthMap[props.width] || 'w-two-thirds';
});
</script>

<template>
  <Popover class="relative" :class="widthClass">
    <!-- 触发按钮 -->
    <PopoverButton
      class="flex items-center justify-between w-full px-3 py-2 border rounded-lg bg-[light-dark(white,#1e293b)] border-[light-dark(#e5e7eb,#334155)] transition-all duration-200 cursor-pointer hover:border-[light-dark(#d1d5db,#475569)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-2"
      @click="initializePanel"
    >
      <div class="flex items-center gap-2">
        <div
          class="w-5 h-5 rounded-full border-2 border-[light-dark(#e5e7eb,#334155)]"
          :style="{ backgroundColor: modelValue }"
        />
        <span class="text-sm text-[light-dark(#0f172a,white)]">{{ getColorName(modelValue) }}</span>
      </div>
      <LucideChevronDown class="w-4 h-4 text-[light-dark(#9ca3af,#64748b)] transition-transform duration-200 ui-open:rotate-180" />
    </PopoverButton>

    <!-- 颜色选择下拉 -->
    <transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="transform scale-95 opacity-0"
      leave-active-class="transition duration-75 ease-in"
      leave-to-class="transform scale-95 opacity-0"
    >
      <PopoverPanel
        v-slot="{ close }"
        class="absolute top-full left-0 right-0 mt-1 p-3 border rounded-lg bg-[light-dark(white,#1e293b)] border-[light-dark(#e5e7eb,#334155)] shadow-lg z-50 focus:outline-none"
        :class="{ 'w-[400px] p-4': professional }"
      >
        <!-- 专业颜色选择器 -->
        <div v-if="professional" class="flex gap-4">
          <div class="flex-1 flex flex-col gap-4">
            <!-- 颜色预览 -->
            <div class="w-full h-[60px] border border-[light-dark(#e5e7eb,#334155)] rounded-lg overflow-hidden">
              <div
                class="w-full h-full"
                :style="{ backgroundColor: hex }"
              />
            </div>
            <!-- 十六进制输入 -->
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-[light-dark(#0f172a,white)]">
                {{ locale === 'zh-CN' ? '十六进制' : 'Hexadecimal' }}
              </label>
              <div class="flex gap-2">
                <input
                  v-model="hex"
                  type="text"
                  class="flex-1 px-2 py-2 text-sm text-[light-dark(#0f172a,white)] bg-[light-dark(white,#1e293b)] border border-[light-dark(#e5e7eb,#334155)] rounded-md outline-none transition-all focus:border-[var(--color-primary)] focus:shadow-[0_0_0_1px_var(--color-primary)]"
                  @blur="handleHexInput"
                  @keyup.enter="handleHexInput"
                >
                <button
                  type="button"
                  class="px-2 py-2 text-[light-dark(#9ca3af,#64748b)] bg-transparent border border-[light-dark(#e5e7eb,#334155)] rounded-md cursor-pointer transition-all hover:text-[light-dark(#0f172a,white)] hover:bg-[light-dark(#f3f4f6,#334155)]"
                  @click="copyColorValue(hex)"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                </button>
              </div>
            </div>
            <!-- RGB 输入 -->
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-[light-dark(#0f172a,white)]">RGB</label>
              <div class="flex gap-1">
                <input
                  v-model.number="rgb.r"
                  type="number"
                  min="0"
                  max="255"
                  class="flex-1 px-2 py-2 text-sm text-[light-dark(#0f172a,white)] bg-[light-dark(white,#1e293b)] border border-[light-dark(#e5e7eb,#334155)] rounded-md outline-none transition-all focus:border-[var(--color-primary)] focus:shadow-[0_0_0_1px_var(--color-primary)]"
                  @blur="handleRgbInput"
                  @keyup.enter="handleRgbInput"
                >
                <input
                  v-model.number="rgb.g"
                  type="number"
                  min="0"
                  max="255"
                  class="flex-1 px-2 py-2 text-sm text-[light-dark(#0f172a,white)] bg-[light-dark(white,#1e293b)] border border-[light-dark(#e5e7eb,#334155)] rounded-md outline-none transition-all focus:border-[var(--color-primary)] focus:shadow-[0_0_0_1px_var(--color-primary)]"
                  @blur="handleRgbInput"
                  @keyup.enter="handleRgbInput"
                >
                <input
                  v-model.number="rgb.b"
                  type="number"
                  min="0"
                  max="255"
                  class="flex-1 px-2 py-2 text-sm text-[light-dark(#0f172a,white)] bg-[light-dark(white,#1e293b)] border border-[light-dark(#e5e7eb,#334155)] rounded-md outline-none transition-all focus:border-[var(--color-primary)] focus:shadow-[0_0_0_1px_var(--color-primary)]"
                  @blur="handleRgbInput"
                  @keyup.enter="handleRgbInput"
                >
                <button
                  type="button"
                  class="px-2 py-2 text-[light-dark(#9ca3af,#64748b)] bg-transparent border border-[light-dark(#e5e7eb,#334155)] rounded-md cursor-pointer transition-all hover:text-[light-dark(#0f172a,white)] hover:bg-[light-dark(#f3f4f6,#334155)]"
                  @click="copyColorValue(`${rgb.r}, ${rgb.g}, ${rgb.b}`)"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                  </svg>
                </button>
              </div>
            </div>
            <!-- 基本颜色 -->
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-[light-dark(#0f172a,white)]">
                {{ locale === 'zh-CN' ? '基本颜色' : 'Basic Colors' }}
              </label>
              <div class="grid grid-cols-9 gap-1 max-sm:gap-[0.15rem]">
                <button
                  v-for="color in ['#000000', '#CECECE', '#FF0000', '#FFA500', '#FFFF00', '#00FF00', '#00FFFF', '#0000FF', '#800080', '#FFFFFF', '#808080', '#8B4513', '#FFC0CB', '#F5DEB3', '#00FF00', '#87CEEB', '#FFFFFF', '#DDA0DD']"
                  :key="color"
                  type="button"
                  class="w-6 h-6 rounded border-2 border-[light-dark(#e5e7eb,#334155)] cursor-pointer transition-all hover:scale-110 hover:border-[light-dark(#0f172a,white)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-1 max-sm:w-5 max-sm:h-5 max-sm:border-[1.5px]"
                  :class="{ 'border-[var(--color-primary)]! shadow-[0_0_0_2px_light-dark(#dbeafe,#1e3a8a)]': hex === color }"
                  :style="{ backgroundColor: color }"
                  @click="selectColor(color, close)"
                />
              </div>
            </div>
          </div>
          <div class="flex-1 flex flex-col gap-2">
            <!-- 颜色渐变选择器 -->
            <div
              class="relative w-[200px] h-[200px] rounded-lg cursor-crosshair overflow-hidden"
              :style="{ backgroundColor: `hsl(${hue}, 100%, 50%)` }"
              @mousedown="handleSaturationMouseDown"
            >
              <div class="absolute inset-0 bg-gradient-to-r from-white/100 to-white/0" />
              <div class="absolute inset-0 bg-gradient-to-b from-black/0 to-black/100" />
              <div
                class="absolute w-3 h-3 border-2 border-white rounded-full -translate-x-1/2 -translate-y-1/2 shadow-[0_0_0_1px_rgba(0,0,0,0.3)] pointer-events-none"
                :style="{
                  left: `${saturation}%`,
                  top: `${100 - lightness}%`,
                }"
              />
            </div>
            <!-- 色相滑块 -->
            <div
              class="relative w-5 h-[200px] bg-gradient-to-b from-[#ff0000] via-[#ffff00_16.66%] via-[#00ff00_33.33%] via-[#00ffff_50%] via-[#0000ff_66.66%] via-[#ff00ff_83.33%] to-[#ff0000] rounded cursor-pointer"
              @mousedown="handleHueMouseDown"
            >
              <div
                class="absolute -left-[2px] -right-[2px] h-1 bg-white border border-black/30 rounded-sm -translate-y-1/2 pointer-events-none"
                :style="{ top: `${(hue / 360) * 100}%` }"
              />
            </div>
          </div>
        </div>
        <!-- 传统颜色选择器 -->
        <div v-else>
          <!-- 随机颜色按钮 -->
          <div v-if="showRandomButton" class="mb-3 pb-3 border-b border-[light-dark(#e5e7eb,#334155)]">
            <button
              type="button"
              class="flex items-center justify-center gap-2 w-full px-2 py-2 text-sm text-[var(--color-primary)] bg-transparent border border-[light-dark(#dbeafe,#1e3a8a)] rounded-md cursor-pointer transition-all hover:bg-[light-dark(#dbeafe,#1e3a8a)] hover:border-[var(--color-primary)]"
              @click="generateRandomColor(close)"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              {{ locale === 'zh-CN' ? '随机颜色' : 'Random Color' }}
            </button>
          </div>

          <!-- 颜色分类标签 -->
          <RadioGroup v-if="showCategories && extended" v-model="activeCategory" class="mb-3 pb-2 border-b border-[light-dark(#e5e7eb,#334155)]">
            <div class="flex gap-1">
              <RadioGroupOption
                v-for="option in categoryOptions"
                :key="option.value"
                v-slot="{ checked }"
                :value="option.value"
                as="template"
              >
                <button
                  type="button"
                  class="px-2 py-1 text-xs border rounded cursor-pointer transition-all focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-1"
                  :class="checked
                    ? 'text-[light-dark(#1e3a8a,#dbeafe)] bg-[light-dark(#dbeafe,#1e3a8a)] border-[var(--color-primary)]'
                    : 'text-[light-dark(#9ca3af,#64748b)] bg-transparent border-transparent hover:text-[light-dark(#0f172a,white)] hover:bg-[light-dark(#f3f4f6,#334155)]'"
                >
                  {{ option.label }}
                </button>
              </RadioGroupOption>
            </div>
          </RadioGroup>

          <!-- 颜色网格 -->
          <div class="grid gap-2 max-sm:gap-1" :class="extended ? 'grid-cols-6' : 'grid-cols-5'">
            <button
              v-for="color in getCurrentCategoryColors()"
              :key="color"
              type="button"
              class="w-8 h-8 rounded-full border-2 border-[#d1d5db] cursor-pointer transition-all hover:scale-110 hover:border-[light-dark(#0f172a,white)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-1 max-sm:w-6 max-sm:h-6 max-sm:border-[1.5px]"
              :class="{ 'border-[var(--color-primary)]! shadow-[0_4px_6px_rgba(0,0,0,0.15)] shadow-[0_0_0_2px_light-dark(#dbeafe,#1e3a8a)]!': modelValue === color }"
              :style="{ backgroundColor: color }"
              :title="getColorName(color)"
              @click="selectColor(color, close)"
            />
          </div>

          <!-- 自定义颜色选择器 -->
          <Disclosure v-if="showCustomColor" v-slot="{ open }" as="div" class="mt-3 pt-3 border-t border-[light-dark(#e5e7eb,#334155)]">
            <DisclosureButton
              class="flex items-center gap-2 w-full px-2 py-2 text-sm text-[light-dark(#9ca3af,#64748b)] bg-transparent border border-dashed border-[light-dark(#e5e7eb,#334155)] rounded-md cursor-pointer transition-all hover:text-[light-dark(#0f172a,white)] hover:border-[light-dark(#0f172a,white)] hover:bg-[light-dark(#f3f4f6,#334155)] focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-1"
              @click="customColor = open ? '' : modelValue"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
              </svg>
              {{ locale === 'zh-CN' ? '自定义颜色' : 'Custom Color' }}
            </DisclosureButton>
            <transition
              enter-active-class="transition duration-100 ease-out"
              enter-from-class="transform scale-95 opacity-0"
              leave-active-class="transition duration-75 ease-in"
              leave-to-class="transform scale-95 opacity-0"
            >
              <DisclosurePanel class="flex gap-2 mt-2">
                <input
                  v-model="customColor"
                  type="text"
                  class="flex-1 px-2 py-1.5 text-sm text-[light-dark(#0f172a,white)] bg-[light-dark(white,#1e293b)] border border-[light-dark(#e5e7eb,#334155)] rounded-md outline-none transition-all focus:border-[var(--color-primary)] focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-1 invalid:border-[var(--color-error)]"
                  placeholder="#000000"
                  @keyup.enter="handleCustomColorInput(close)"
                >
                <button
                  type="button"
                  class="px-3 py-1.5 text-sm text-[light-dark(white,white)] bg-[var(--color-primary)] border-none rounded-md cursor-pointer transition-colors hover:bg-[var(--color-primary-hover)] disabled:bg-[light-dark(#e5e7eb,#334155)] disabled:cursor-not-allowed focus:outline-none focus:ring-2 focus:ring-[var(--color-primary)] focus:ring-offset-1"
                  :disabled="!isValidHexColor(customColor)"
                  @click="handleCustomColorInput(close)"
                >
                  {{ locale === 'zh-CN' ? '应用' : 'Apply' }}
                </button>
              </DisclosurePanel>
            </transition>
          </Disclosure>
        </div>
      </PopoverPanel>
    </transition>
  </Popover>
</template>
