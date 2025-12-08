<script setup lang="ts">
  import type { CategoryDefinition } from '@/constants/commonConstant';
  import { useCategoryStore } from '@/stores/money';
  import { lowercaseFirstLetter } from '@/utils/string';

  // Props 接口
  export interface CategorySelectorProps {
    modelValue?: string[];
    label?: string;
    placeholder?: string;
    helpText?: string;
    required?: boolean;
    disabled?: boolean;
    locale?: 'zh-CN' | 'en';
    categories?: CategoryDefinition[];
    errorMessage?: string;
    size?: 'sm' | 'base' | 'lg';
    width?: 'full' | 'auto' | '2/3' | '1/2' | '1/3';
    showIcons?: boolean;
    multiple?: boolean;
    showQuickSelect?: boolean;
    quickSelectLabel?: string;
    customQuickCategories?: CategoryDefinition[];
  }

  // Props 默认值
  const props = withDefaults(defineProps<CategorySelectorProps>(), {
    modelValue: () => [],
    label: '分类',
    placeholder: '请选择分类',
    helpText: '',
    required: false,
    disabled: false,
    locale: 'zh-CN',
    categories: undefined,
    errorMessage: '',
    size: 'base',
    width: 'full',
    showIcons: true,
    multiple: true,
    showQuickSelect: true,
    quickSelectLabel: '常用分类',
    customQuickCategories: undefined,
  });

  // 事件定义
  const emit = defineEmits<{
    (e: 'update:modelValue', value: string[]): void;
    (e: 'change', value: string[]): void;
    (e: 'validate', isValid: boolean): void;
  }>();

  const categoryStore = useCategoryStore();
  const mergedCategories = computed(() => {
    return props.categories ?? categoryStore.uiCategories;
  });
  const mergedQuickCategories = computed(() => {
    return props.customQuickCategories?.length
      ? props.customQuickCategories
      : mergedCategories.value.slice(0, 6);
  });

  // 响应式状态
  const selectedCategories = ref<string[]>(props.modelValue);
  const inputId = useId();
  const showAllCategories = ref(false);

  const { t } = useI18n();
  // 计算属性：快捷选择分类
  const quickSelectCategories = computed<CategoryDefinition[]>(() => {
    return mergedQuickCategories.value;
  });

  // 计算属性：验证状态
  const isValid = computed(() => {
    if (!props.required) return true;
    return props.multiple
      ? selectedCategories.value.length > 0
      : selectedCategories.value.length > 0;
  });

  // 事件处理：选择/取消选择分类
  function toggleCategory(categoryCode: string) {
    if (props.disabled) return;

    const index = selectedCategories.value.indexOf(categoryCode);

    if (index === -1) {
      // 添加分类
      if (props.multiple) {
        selectedCategories.value.push(categoryCode);
      } else {
        selectedCategories.value = [categoryCode];
      }
    } else {
      // 移除分类
      if (props.multiple) {
        selectedCategories.value.splice(index, 1);
      } else {
        selectedCategories.value = [];
      }
    }

    // 触发事件
    emit('update:modelValue', selectedCategories.value);
    emit('change', selectedCategories.value);
    emit('validate', isValid.value);
  }

  // 事件处理：选择快捷分类
  function selectQuickCategory(categoryCode: string) {
    if (props.disabled) return;

    if (props.multiple) {
      // 多选模式：切换选择状态
      toggleCategory(categoryCode);
    } else {
      // 单选模式：直接选择
      selectedCategories.value = [categoryCode];
      emit('update:modelValue', selectedCategories.value);
      emit('change', selectedCategories.value);
      emit('validate', isValid.value);
    }
  }

  // 检查分类是否已选择
  function isCategorySelected(categoryCode: string): boolean {
    return selectedCategories.value.includes(categoryCode);
  }

  // 监听器
  watch(
    () => props.modelValue,
    newValue => {
      selectedCategories.value = newValue;
    },
    { immediate: true, deep: true },
  );

  // 验证状态变化
  watch(
    isValid,
    valid => {
      emit('validate', valid);
    },
    { immediate: true },
  );

  // 暴露组件方法
  defineExpose({
    validate: () => isValid.value,
    reset: () => {
      selectedCategories.value = [];
      emit('update:modelValue', []);
      emit('change', []);
      emit('validate', isValid.value);
    },
  });
</script>

<template>
  <div class="mb-0">
    <!-- 快捷选择区域 -->
    <div
      v-if="showQuickSelect && quickSelectCategories.length > 0"
      class="mb-3"
      role="group"
      :aria-label="quickSelectLabel"
    >
      <div class="text-[0.8125rem] font-medium text-[light-dark(#0f172a,white)] opacity-80 mb-2">
        {{ quickSelectLabel }}
      </div>
      <div class="flex flex-wrap gap-2">
        <button
          v-for="category in quickSelectCategories"
          :key="category.code"
          type="button"
          class="text-xs px-3 py-2 rounded-md border transition-all duration-200"
          :class="[
            isCategorySelected(category.code)
              ? 'bg-[light-dark(#dbeafe,#1e3a8a)] border-blue-500 text-[light-dark(#1e3a8a,#dbeafe)]'
              : 'bg-[light-dark(white,#1e293b)] border-[light-dark(#e5e7eb,#334155)] text-[light-dark(#0f172a,white)] hover:bg-[light-dark(#f3f4f6,#334155)]',
            disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer',
            multiple && isCategorySelected(category.code) ? 'relative' : '',
          ]"
          :disabled="disabled"
          :title="t(`common.categories.${lowercaseFirstLetter(category.code)}`)"
          @click="selectQuickCategory(category.code)"
        >
          {{ category.icon }}
          <!-- 多选勾选标记 -->
          <span
            v-if="multiple && isCategorySelected(category.code)"
            class="absolute -top-1 -right-1 bg-blue-500 text-[light-dark(white,white)] rounded-full w-4 h-4 flex items-center justify-center text-xs"
            >✓</span
          >
        </button>
      </div>
    </div>

    <!-- 全部分类列表 -->
    <div v-if="mergedCategories.length > 0" class="mb-3">
      <div class="flex justify-between items-center mb-2">
        <div class="text-[0.8125rem] font-medium text-[light-dark(#0f172a,white)] opacity-80">
          全部分类
        </div>
        <button
          type="button"
          class="flex items-center gap-1 px-2 py-1 text-xs text-blue-500 bg-transparent border-none cursor-pointer transition-opacity duration-200 hover:opacity-70"
          :title="showAllCategories ? '收起' : '展开'"
          @click="showAllCategories = !showAllCategories"
        >
          <span class="text-[0.625rem]">{{ showAllCategories ? '▲' : '▼' }}</span>
        </button>
      </div>
      <div
        v-show="showAllCategories"
        class="grid grid-cols-[repeat(auto-fill,minmax(75px,1fr))] gap-1 p-1.5 bg-[light-dark(#f3f4f6,#1e293b)] rounded-md max-sm:grid-cols-[repeat(auto-fill,minmax(70px,1fr))]"
      >
        <button
          v-for="category in mergedCategories"
          :key="category.code"
          type="button"
          class="flex items-center gap-1 px-2 py-1.5 rounded border transition-all duration-200 text-xs max-sm:px-1.5 max-sm:py-1 max-sm:text-[0.6875rem]"
          :class="[
            isCategorySelected(category.code)
              ? 'bg-blue-500 border-blue-500 text-[light-dark(white,white)]'
              : 'bg-[light-dark(white,#1e293b)] border-[light-dark(#e5e7eb,#334155)] text-[light-dark(#0f172a,white)] hover:border-blue-500 hover:bg-[light-dark(#dbeafe,#1e3a8a)] hover:-translate-y-0.5',
            disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer',
          ]"
          :disabled="disabled"
          :title="t(`common.categories.${lowercaseFirstLetter(category.code)}`)"
          @click="toggleCategory(category.code)"
        >
          <span v-if="showIcons" class="text-sm shrink-0 max-sm:text-xs">{{ category.icon }}</span>
          <span class="flex-1 text-left whitespace-nowrap overflow-hidden text-ellipsis">
            {{ t(`common.categories.${lowercaseFirstLetter(category.code)}`) }}
          </span>
        </button>
      </div>
    </div>

    <!-- 错误提示 -->
    <div
      v-if="errorMessage"
      :id="`${inputId}-error`"
      class="text-sm mt-1 text-red-500"
      role="alert"
      aria-live="polite"
    >
      {{ errorMessage }}
    </div>

    <!-- 帮助文本 -->
    <div v-if="helpText" class="text-xs mt-2 text-[light-dark(#6b7280,#94a3b8)]">
      {{ helpText }}
    </div>
  </div>
</template>
