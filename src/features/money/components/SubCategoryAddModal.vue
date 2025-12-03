<script setup lang="ts">
import Modal from '@/components/ui/Modal.vue';
import Select from '@/components/ui/Select.vue';
import type { Category } from '@/schema/money/category';
import type { SelectOption } from '@/components/ui/Select.vue';
import { lowercaseFirstLetter } from '@/utils/string';

const props = defineProps<{
  open: boolean;
  categoryName?: string;
  categories?: Category[];
  showCategorySelector?: boolean;
}>();

const { t } = useI18n();

const emit = defineEmits<{
  close: [];
  confirm: [name: string, icon: string, categoryName: string];
}>();

const formData = reactive({
  name: '',
  icon: '',
  selectedCategory: '',
});

// 监听 categoryName 变化，自动设置选中的分类
watch(() => props.categoryName, (newVal) => {
  if (newVal) {
    formData.selectedCategory = newVal;
  }
}, { immediate: true });

// 重置表单
function resetForm() {
  formData.name = '';
  formData.icon = '';
  if (!props.categoryName) {
    formData.selectedCategory = '';
  }
}

// 关闭模态框
function handleClose() {
  resetForm();
  emit('close');
}

// 确认添加
function handleConfirm() {
  if (!formData.name.trim()) {
    return;
  }
  const targetCategory = props.categoryName || formData.selectedCategory;
  if (!targetCategory) {
    return;
  }
  emit('confirm', formData.name.trim(), formData.icon.trim(), targetCategory);
  resetForm();
}

// 表单验证
const isValid = computed(() => {
  const hasName = formData.name.trim().length >= 2 && formData.name.trim().length <= 20;
  const hasCategory = !!(props.categoryName || formData.selectedCategory);
  return hasName && hasCategory;
});

// 转换分类为 Select 选项（支持国际化，带回退）
const categoryOptions = computed<SelectOption[]>(() => {
  if (!props.categories) return [];
  return props.categories.map(cat => {
    try {
      const key = `common.categories.${lowercaseFirstLetter(cat.name)}`;
      const translated = t(key);
      const displayName = translated && translated !== key ? translated : cat.name;
      return {
        value: cat.name,
        label: `${cat.icon} ${displayName}`,
      };
    } catch (error) {
      // 翻译失败时使用原始名称
      return {
        value: cat.name,
        label: `${cat.icon} ${cat.name}`,
      };
    }
  });
});

// 国际化的分类名称（用于标题和显示）
const translatedCategoryName = computed(() => {
  if (!props.categoryName) {
    return '';
  }
  
  try {
    const key = `common.categories.${lowercaseFirstLetter(props.categoryName)}`;
    const translated = t(key);
    // 如果翻译键不存在，t() 可能返回键本身或空字符串，使用原始名称作为回退
    return translated && translated !== key ? translated : props.categoryName;
  } catch (error) {
    // 如果翻译失败，返回原始名称
    return props.categoryName;
  }
});
</script>

<template>
  <Modal
    :open="props.open"
    :title="categoryName && translatedCategoryName ? `添加子分类到 ${translatedCategoryName}` : '添加子分类'"
    size="sm"
    :confirm-disabled="!isValid"
    @close="handleClose"
    @cancel="handleClose"
    @confirm="handleConfirm"
  >
    <div class="space-y-4">
      <!-- 父分类选择器（仅在没有指定 categoryName 时显示） -->
      <div v-if="!categoryName && showCategorySelector">
        <Select
          v-model="formData.selectedCategory"
          :options="categoryOptions"
          label="父分类"
          placeholder="请选择父分类"
          required
          full-width
          searchable
        />
      </div>

      <!-- 父分类显示（指定了 categoryName 时显示） -->
      <div v-else-if="categoryName" class="p-3 bg-gray-50 dark:bg-gray-700 rounded-lg">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          父分类: <span class="font-medium text-gray-900 dark:text-gray-100">{{ translatedCategoryName || categoryName || '未知' }}</span>
        </p>
      </div>

      <!-- 名称输入 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          子分类名称 <span class="text-red-500">*</span>
        </label>
        <input
          v-model="formData.name"
          type="text"
          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
          placeholder="请输入子分类名称 (2-20字符)"
          maxlength="20"
          @keyup.enter="isValid && handleConfirm()"
        >
        <p class="mt-1 text-xs text-gray-500">
          {{ formData.name.length }}/20 字符
        </p>
      </div>

      <!-- 图标输入 -->
      <div>
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          图标 (Emoji)
        </label>
        <input
          v-model="formData.icon"
          type="text"
          class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 text-2xl text-center"
          placeholder="🎁"
          maxlength="2"
        >
        <p class="mt-1 text-xs text-gray-500">
          可选，留空将使用默认图标
        </p>
      </div>
    </div>
  </Modal>
</template>
