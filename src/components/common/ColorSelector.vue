<script setup lang="ts">
import { COLORS_MAP, EXTENDED_COLORS_MAP } from '@/constants/moneyConst';
import type { DefaultColors } from '@/schema/common';

interface Props {
  modelValue: string;
  colorNames?: DefaultColors[];
  extended?: boolean; // 是否使用扩展颜色调色板
  showCustomColor?: boolean; // 是否显示自定义颜色选择器
  showCategories?: boolean; // 是否显示颜色分类
  professional?: boolean; // 是否使用专业颜色选择器界面
}

// 定义 props
const props = withDefaults(defineProps<Props>(), {
  colorNames: () => COLORS_MAP,
  extended: false,
  showCustomColor: true,
  showCategories: false,
  professional: false,
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
const isOpen = ref(false);
const colorSelectorRef = ref<HTMLElement | null>(null);
const activeCategory = ref('all');
const customColor = ref('');
const showCustomInput = ref(false);

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

// 切换下拉状态
function toggleDropdown() {
  isOpen.value = !isOpen.value;
  if (isOpen.value) {
    // 重置自定义颜色输入状态
    showCustomInput.value = false;
    customColor.value = '';
    // 初始化专业颜色选择器
    if (props.professional) {
      initializeColor(props.modelValue);
    }
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
function selectColor(color: string) {
  emit('update:modelValue', color);
  isOpen.value = false;
}

// 切换颜色分类
function switchCategory(category: string) {
  activeCategory.value = category;
}

// 获取当前分类的颜色
function getCurrentCategoryColors() {
  if (!props.showCategories || !props.extended) {
    return colors.value;
  }
  const categoryColors = colorCategories.value[activeCategory.value as keyof typeof colorCategories.value];
  return categoryColors ? (categoryColors as DefaultColors[]).map((v: DefaultColors) => v.code) : colors.value;
}

// 处理自定义颜色输入
function handleCustomColorInput() {
  if (customColor.value && isValidHexColor(customColor.value)) {
    selectColor(customColor.value);
  }
}

// 验证十六进制颜色值
function isValidHexColor(color: string): boolean {
  return /^#[a-f0-9]{6}$|^#[a-f0-9]{3}$/i.test(color);
}

// 切换自定义颜色输入显示
function toggleCustomColorInput() {
  showCustomInput.value = !showCustomInput.value;
  if (showCustomInput.value) {
    customColor.value = props.modelValue;
  }
}

// 点击外部关闭下拉
function handleClickOutside(event: Event) {
  if (
    colorSelectorRef.value
    && !colorSelectorRef.value.contains(event.target as Node)
  ) {
    isOpen.value = false;
    showCustomInput.value = false;
  }
}

// 获取分类名称
function getCategoryName(category: string): string {
  const categoryNames = {
    all: locale.value === 'zh-CN' ? '全部' : 'All',
    basic: locale.value === 'zh-CN' ? '基础色' : 'Basic',
    extended: locale.value === 'zh-CN' ? '扩展色' : 'Extended',
    light: locale.value === 'zh-CN' ? '柔和色' : 'Light',
    special: locale.value === 'zh-CN' ? '特殊色' : 'Special',
  };
  return categoryNames[category as keyof typeof categoryNames] || category;
}

// 监听 modelValue 变化，更新自定义颜色输入框
watch(() => props.modelValue, newValue => {
  if (showCustomInput.value) {
    customColor.value = newValue;
  }
});

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

    <!-- 颜色选择下拉 -->
    <div
      v-if="isOpen"
      class="color-selector__dropdown"
      :class="{ professional }"
    >
      <!-- 专业颜色选择器 -->
      <div v-if="professional" class="color-selector__professional">
        <div class="color-selector__professional-left">
          <!-- 颜色预览 -->
          <div class="color-selector__preview-large">
            <div
              class="color-selector__preview-swatch"
              :style="{ backgroundColor: hex }"
            />
          </div>
          <!-- 十六进制输入 -->
          <div class="color-selector__input-group">
            <label class="color-selector__input-label">
              {{ locale === 'zh-CN' ? '十六进制' : 'Hexadecimal' }}
            </label>
            <div class="color-selector__input-wrapper">
              <input
                v-model="hex"
                type="text"
                class="color-selector__hex-input-pro"
                @blur="handleHexInput"
                @keyup.enter="handleHexInput"
              >
              <button
                type="button"
                class="color-selector__copy-btn"
                @click="copyColorValue(hex)"
              >
                <svg class="color-selector__copy-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </button>
            </div>
          </div>
          <!-- RGB 输入 -->
          <div class="color-selector__input-group">
            <label class="color-selector__input-label">RGB</label>
            <div class="color-selector__rgb-inputs">
              <input
                v-model.number="rgb.r"
                type="number"
                min="0"
                max="255"
                class="color-selector__rgb-input"
                @blur="handleRgbInput"
                @keyup.enter="handleRgbInput"
              >
              <input
                v-model.number="rgb.g"
                type="number"
                min="0"
                max="255"
                class="color-selector__rgb-input"
                @blur="handleRgbInput"
                @keyup.enter="handleRgbInput"
              >
              <input
                v-model.number="rgb.b"
                type="number"
                min="0"
                max="255"
                class="color-selector__rgb-input"
                @blur="handleRgbInput"
                @keyup.enter="handleRgbInput"
              >
              <button
                type="button"
                class="color-selector__copy-btn"
                @click="copyColorValue(`${rgb.r}, ${rgb.g}, ${rgb.b}`)"
              >
                <svg class="color-selector__copy-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
              </button>
            </div>
          </div>
          <!-- 基本颜色 -->
          <div class="color-selector__basic-colors">
            <label class="color-selector__input-label">
              {{ locale === 'zh-CN' ? '基本颜色' : 'Basic Colors' }}
            </label>
            <div class="color-selector__basic-grid">
              <button
                v-for="color in ['#000000', '#CECECE', '#FF0000', '#FFA500', '#FFFF00', '#00FF00', '#00FFFF', '#0000FF', '#800080', '#FFFFFF', '#808080', '#8B4513', '#FFC0CB', '#F5DEB3', '#00FF00', '#87CEEB', '#FFFFFF', '#DDA0DD']"
                :key="color"
                type="button"
                class="color-selector__basic-color"
                :class="{ active: hex === color }"
                :style="{ backgroundColor: color }"
                @click="selectColor(color)"
              />
            </div>
          </div>
        </div>
        <div class="color-selector__professional-right">
          <!-- 颜色渐变选择器 -->
          <div
            class="color-selector__gradient-area"
            :style="{ backgroundColor: `hsl(${hue}, 100%, 50%)` }"
            @mousedown="handleSaturationMouseDown"
          >
            <div class="color-selector__gradient-white" />
            <div class="color-selector__gradient-black" />
            <div
              class="color-selector__gradient-handle"
              :style="{
                left: `${saturation}%`,
                top: `${100 - lightness}%`,
              }"
            />
          </div>
          <!-- 色相滑块 -->
          <div
            class="color-selector__hue-slider"
            @mousedown="handleHueMouseDown"
          >
            <div
              class="color-selector__hue-handle"
              :style="{ top: `${(hue / 360) * 100}%` }"
            />
          </div>
        </div>
      </div>
      <!-- 传统颜色选择器 -->
      <div v-else>
        <!-- 颜色分类标签 -->
        <div v-if="showCategories && extended" class="color-selector__categories">
          <button
            v-for="(_, category) in colorCategories"
            :key="category"
            type="button"
            class="color-selector__category-tab"
            :class="{ active: activeCategory === category }"
            @click="switchCategory(category)"
          >
            {{ getCategoryName(category) }}
          </button>
        </div>

        <!-- 颜色网格 -->
        <div class="color-selector__grid" :class="{ 'extended-grid': extended }">
          <button
            v-for="color in getCurrentCategoryColors()"
            :key="color"
            type="button"
            class="color-selector__option"
            :class="{ active: modelValue === color }"
            :style="{ backgroundColor: color }"
            :title="getColorName(color)"
            @click="selectColor(color)"
          />
        </div>

        <!-- 自定义颜色选择器 -->
        <div v-if="showCustomColor" class="color-selector__custom">
          <button
            type="button"
            class="color-selector__custom-toggle"
            @click="toggleCustomColorInput"
          >
            <svg class="color-selector__custom-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
            </svg>
            {{ locale === 'zh-CN' ? '自定义颜色' : 'Custom Color' }}
          </button>
          <div v-if="showCustomInput" class="color-selector__custom-input">
            <input
              v-model="customColor"
              type="text"
              class="color-selector__hex-input"
              placeholder="#000000"
              @keyup.enter="handleCustomColorInput"
            >
            <button
              type="button"
              class="color-selector__apply-btn"
              :disabled="!isValidHexColor(customColor)"
              @click="handleCustomColorInput"
            >
              {{ locale === 'zh-CN' ? '应用' : 'Apply' }}
            </button>
          </div>
        </div>
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
  border: 1px solid var(--color-base-300); /* gray-300 */
  border-radius: 0.5rem; /* rounded-lg */
  background-color: var(--color-base-100);
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

.color-selector__dropdown.professional {
  width: 400px;
  padding: 1rem;
}

/* 颜色分类标签 */
.color-selector__categories {
  display: flex;
  gap: 0.25rem;
  margin-bottom: 0.75rem;
  padding-bottom: 0.5rem;
  border-bottom: 1px solid #e5e7eb;
}

.color-selector__category-tab {
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  color: #6b7280;
  background-color: transparent;
  border: 1px solid transparent;
  border-radius: 0.25rem;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.color-selector__category-tab:hover {
  color: #374151;
  background-color: #f3f4f6;
}

.color-selector__category-tab.active {
  color: #1f2937;
  background-color: #dbeafe;
  border-color: #3b82f6;
}

/* 网格 */
.color-selector__grid {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.5rem;
}

.color-selector__grid.extended-grid {
  grid-template-columns: repeat(6, minmax(0, 1fr));
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

/* 自定义颜色选择器 */
.color-selector__custom {
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid #e5e7eb;
}

.color-selector__custom-toggle {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.5rem;
  font-size: 0.875rem;
  color: #6b7280;
  background-color: transparent;
  border: 1px dashed #d1d5db;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.color-selector__custom-toggle:hover {
  color: #374151;
  border-color: #9ca3af;
  background-color: #f9fafb;
}

.color-selector__custom-icon {
  width: 1rem;
  height: 1rem;
}

.color-selector__custom-input {
  display: flex;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

.color-selector__hex-input {
  flex: 1;
  padding: 0.375rem 0.5rem;
  font-size: 0.875rem;
  color: #374151;
  background-color: #fff;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  outline: none;
  transition: border-color 0.2s ease-in-out;
}

.color-selector__hex-input:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 1px #3b82f6;
}

.color-selector__hex-input:invalid {
  border-color: #ef4444;
}

.color-selector__apply-btn {
  padding: 0.375rem 0.75rem;
  font-size: 0.875rem;
  color: #fff;
  background-color: #3b82f6;
  border: none;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: background-color 0.2s ease-in-out;
}

.color-selector__apply-btn:hover:not(:disabled) {
  background-color: #2563eb;
}

.color-selector__apply-btn:disabled {
  background-color: #9ca3af;
  cursor: not-allowed;
}

/* 专业颜色选择器样式 */
.color-selector__professional {
  display: flex;
  gap: 1rem;
}

.color-selector__professional-left {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.color-selector__professional-right {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

/* 颜色预览 */
.color-selector__preview-large {
  width: 100%;
  height: 60px;
  border: 1px solid #d1d5db;
  border-radius: 0.5rem;
  overflow: hidden;
}

.color-selector__preview-swatch {
  width: 100%;
  height: 100%;
}

/* 输入组 */
.color-selector__input-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.color-selector__input-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #374151;
}

.color-selector__input-wrapper {
  display: flex;
  gap: 0.5rem;
}

.color-selector__hex-input-pro {
  flex: 1;
  padding: 0.5rem;
  font-size: 0.875rem;
  color: #374151;
  background-color: #fff;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  outline: none;
  transition: border-color 0.2s ease-in-out;
}

.color-selector__hex-input-pro:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 1px #3b82f6;
}

.color-selector__copy-btn {
  padding: 0.5rem;
  color: #6b7280;
  background-color: transparent;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.color-selector__copy-btn:hover {
  color: #374151;
  background-color: #f3f4f6;
}

.color-selector__copy-icon {
  width: 1rem;
  height: 1rem;
}

/* RGB 输入 */
.color-selector__rgb-inputs {
  display: flex;
  gap: 0.25rem;
}

.color-selector__rgb-input {
  flex: 1;
  padding: 0.5rem;
  font-size: 0.875rem;
  color: #374151;
  background-color: #fff;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  outline: none;
  transition: border-color 0.2s ease-in-out;
}

.color-selector__rgb-input:focus {
  border-color: #3b82f6;
  box-shadow: 0 0 0 1px #3b82f6;
}

/* 基本颜色 */
.color-selector__basic-colors {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.color-selector__basic-grid {
  display: grid;
  grid-template-columns: repeat(9, 1fr);
  gap: 0.25rem;
}

.color-selector__basic-color {
  width: 1.5rem;
  height: 1.5rem;
  border-radius: 0.25rem;
  border: 2px solid #d1d5db;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.color-selector__basic-color:hover {
  transform: scale(1.1);
  border-color: #6b7280;
}

.color-selector__basic-color.active {
  border-color: #111827;
  box-shadow: 0 0 0 2px #bfdbfe;
}

/* 颜色渐变选择器 */
.color-selector__gradient-area {
  position: relative;
  width: 200px;
  height: 200px;
  border-radius: 0.5rem;
  cursor: crosshair;
  overflow: hidden;
}

.color-selector__gradient-white {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(to right, rgba(255,255,255,1), rgba(255,255,255,0));
}

.color-selector__gradient-black {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: linear-gradient(to bottom, rgba(0, 0, 0, 0), rgba(0, 0, 0, 1));
}

.color-selector__gradient-handle {
  position: absolute;
  width: 12px;
  height: 12px;
  border: 2px solid #fff;
  border-radius: 50%;
  transform: translate(-50%, -50%);
  box-shadow: 0 0 0 1px rgba(0, 0, 0, 0.3);
  pointer-events: none;
}

/* 色相滑块 */
.color-selector__hue-slider {
  position: relative;
  width: 20px;
  height: 200px;
  background: linear-gradient(to bottom,
    #ff0000 0%,
    #ffff00 16.66%,
    #00ff00 33.33%,
    #00ffff 50%,
    #0000ff 66.66%,
    #ff00ff 83.33%,
    #ff0000 100%
  );
  border-radius: 0.25rem;
  cursor: pointer;
}

.color-selector__hue-handle {
  position: absolute;
  left: -2px;
  right: -2px;
  height: 4px;
  background-color: #fff;
  border: 1px solid rgba(0, 0, 0, 0.3);
  border-radius: 2px;
  transform: translateY(-50%);
  pointer-events: none;
}
</style>
