<script setup lang="ts">
  import { Hash, X } from 'lucide-vue-next';
  import { computed, onMounted, ref } from 'vue';
  import type { Tags } from '@/schema/tags';
  import { TagDb } from '@/services/tags';

  interface Props {
    modelValue: string[]; // 已选择的标签 serialNum 数组
    placeholder?: string;
    disabled?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    placeholder: '选择标签...',
    disabled: false,
  });

  const emit = defineEmits<{
    'update:modelValue': [value: string[]];
  }>();

  const allTags = ref<Tags[]>([]);
  const loading = ref(false);
  const showDropdown = ref(false);

  // 加载所有标签
  async function loadTags() {
    loading.value = true;
    try {
      allTags.value = await TagDb.listTags();
    } catch (error) {
      console.error('加载标签失败:', error);
    } finally {
      loading.value = false;
    }
  }

  // 已选择的标签对象
  const selectedTags = computed(() => {
    return allTags.value.filter(tag => props.modelValue.includes(tag.serialNum));
  });

  // 可选择的标签（未选择的）
  const availableTags = computed(() => {
    return allTags.value.filter(tag => !props.modelValue.includes(tag.serialNum));
  });

  // 选择标签
  function selectTag(tag: Tags) {
    const newValue = [...props.modelValue, tag.serialNum];
    emit('update:modelValue', newValue);
    showDropdown.value = false;
  }

  // 移除标签
  function removeTag(serialNum: string) {
    const newValue = props.modelValue.filter(id => id !== serialNum);
    emit('update:modelValue', newValue);
  }

  onMounted(() => {
    loadTags();
  });
</script>

<template>
  <div class="relative">
    <!-- 已选择的标签 -->
    <div
      class="min-h-[42px] flex flex-wrap gap-2 p-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800"
    >
      <span
        v-for="tag in selectedTags"
        :key="tag.serialNum"
        class="inline-flex items-center gap-1 px-2 py-1 text-sm bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded"
      >
        <Hash :size="14" />
        {{ tag.name }}
        <button
          v-if="!disabled"
          type="button"
          class="ml-1 hover:bg-blue-200 dark:hover:bg-blue-800 rounded-full p-0.5"
          @click="removeTag(tag.serialNum)"
        >
          <X :size="12" />
        </button>
      </span>

      <!-- 添加按钮 -->
      <button
        v-if="!disabled"
        type="button"
        class="px-3 py-1 text-sm text-gray-600 dark:text-gray-400 hover:text-blue-600 dark:hover:text-blue-400 border border-dashed border-gray-300 dark:border-gray-600 rounded"
        @click="showDropdown = !showDropdown"
      >
        {{ selectedTags.length === 0 ? placeholder : '+ 添加标签' }}
      </button>
    </div>

    <!-- 下拉选择列表 -->
    <div
      v-if="showDropdown && !disabled"
      class="absolute z-10 mt-1 w-full max-h-60 overflow-auto bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-lg shadow-lg"
    >
      <div v-if="loading" class="p-4 text-center text-gray-500">加载中...</div>
      <div v-else-if="availableTags.length === 0" class="p-4 text-center text-gray-500">
        没有更多标签
      </div>
      <button
        v-for="tag in availableTags"
        :key="tag.serialNum"
        type="button"
        class="w-full flex items-center gap-2 px-4 py-2 text-left hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        @click="selectTag(tag)"
      >
        <Hash :size="16" class="text-blue-600 dark:text-blue-400" />
        <span class="font-medium">{{ tag.name }}</span>
        <span v-if="tag.description" class="text-sm text-gray-500 truncate">
          {{ tag.description }}
        </span>
      </button>
    </div>

    <!-- 遮罩层 -->
    <div v-if="showDropdown" class="fixed inset-0 z-0" @click="showDropdown = false" />
  </div>
</template>
