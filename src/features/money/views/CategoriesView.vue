<script setup lang="ts">
import { Plus, RefreshCw } from 'lucide-vue-next';
import { useCategoryStore } from '@/stores/money';
import CategoryItem from '../components/CategoryItem.vue';
import type { Category } from '@/schema/money/category';

const categoryStore = useCategoryStore();

// 加载数据
onMounted(async () => {
  await categoryStore.fetchCategories();
});

// 刷新数据
const isRefreshing = ref(false);
async function refresh() {
  isRefreshing.value = true;
  try {
    await categoryStore.fetchCategories(true);
  } finally {
    isRefreshing.value = false;
  }
}

// 添加新分类
function addCategory() {
  // TODO: 实现添加分类的逻辑（需要后端 API 支持）
  console.log('添加分类');
}

// 更新分类
function updateCategory(category: Category) {
  // TODO: 实现更新分类的逻辑（需要后端 API 支持）
  console.log('更新分类', category);
}

// 删除分类
function removeCategory(category: Category) {
  // TODO: 实现删除分类的逻辑（需要后端 API 支持）
  console.log('删除分类', category);
}
</script>

<template>
  <div class="space-y-4">
    <!-- 操作栏 -->
    <div class="flex justify-between items-center">
      <div class="text-lg font-semibold text-gray-800 dark:text-gray-200">
        分类管理
        <span class="ml-2 text-sm font-normal text-gray-500">
          ({{ categoryStore.categories.length }} 个)
        </span>
      </div>
      <div class="flex gap-2">
        <button
          class="p-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
          :disabled="isRefreshing"
          :title="isRefreshing ? '刷新中...' : '刷新'"
          @click="refresh"
        >
          <RefreshCw class="w-4 h-4" :class="{ 'animate-spin': isRefreshing }" />
        </button>
        <button
          class="p-2 bg-green-500 text-white rounded-lg hover:bg-green-600 transition-colors"
          title="添加分类"
          @click="addCategory"
        >
          <Plus class="w-4 h-4" />
        </button>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="categoryStore.loading" class="text-center py-8 text-gray-500">
      加载中...
    </div>

    <!-- 错误提示 -->
    <div v-else-if="categoryStore.error" class="text-center py-8 text-red-500">
      {{ categoryStore.error }}
    </div>

    <!-- 分类列表 -->
    <div v-else class="grid grid-cols-5 sm:grid-cols-7 md:grid-cols-10 lg:grid-cols-13 xl:grid-cols-16 gap-3">
      <CategoryItem
        v-for="category in categoryStore.categories"
        :key="category.name"
        :model-value="category"
        :readonly="true"
        @update:model-value="updateCategory"
        @remove="removeCategory(category)"
      />
    </div>
  </div>
</template>
