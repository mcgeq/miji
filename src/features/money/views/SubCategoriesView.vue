<script setup lang="ts">
import { ChevronDown, ChevronRight, ChevronsDown, ChevronsUp, Plus, RefreshCw } from 'lucide-vue-next';
import { useCategoryStore } from '@/stores/money';
import SubCategoryItem from '../components/SubCategoryItem.vue';
import SubCategoryAddModal from '../components/SubCategoryAddModal.vue';
import type { SubCategory } from '@/schema/money/category';
import { toast } from '@/utils/toast';

const categoryStore = useCategoryStore();

// 加载数据
onMounted(async () => {
  await Promise.all([
    categoryStore.fetchCategories(),
    categoryStore.fetchSubCategories(),
  ]);
});

// 刷新数据
const isRefreshing = ref(false);
async function refresh() {
  isRefreshing.value = true;
  try {
    await Promise.all([
      categoryStore.fetchCategories(true),
      categoryStore.fetchSubCategories(true),
    ]);
  } finally {
    isRefreshing.value = false;
  }
}

// 按父分类分组
const groupedSubCategories = computed(() => {
  const groups: Record<string, SubCategory[]> = {};
  categoryStore.categories.forEach(cat => {
    groups[cat.name] = categoryStore.getSubCategoriesByCategory(cat.name);
  });
  return groups;
});

// 折叠状态
const expandedCategories = ref<Set<string>>(new Set());

function toggleCategory(categoryName: string) {
  if (expandedCategories.value.has(categoryName)) {
    expandedCategories.value.delete(categoryName);
  } else {
    expandedCategories.value.add(categoryName);
  }
}

function isCategoryExpanded(categoryName: string) {
  return expandedCategories.value.has(categoryName);
}

// 判断是否全部展开
const isAllExpanded = computed(() => {
  return categoryStore.categories.length > 0
    && expandedCategories.value.size === categoryStore.categories.length;
});

// 全部展开/折叠
function expandAll() {
  categoryStore.categories.forEach(cat => {
    expandedCategories.value.add(cat.name);
  });
}

function collapseAll() {
  expandedCategories.value.clear();
}

// 添加子分类模态框
const showAddModal = ref(false);
const selectedCategoryForAdd = ref('');
const showCategorySelector = ref(false);

// 从特定分类打开添加模态框
function openAddModal(categoryName: string) {
  selectedCategoryForAdd.value = categoryName;
  showCategorySelector.value = false;
  showAddModal.value = true;
}

// 全局添加按钮打开模态框（需要选择父分类）
function openGlobalAddModal() {
  selectedCategoryForAdd.value = '';
  showCategorySelector.value = true;
  showAddModal.value = true;
}

async function handleAddSubCategory(name: string, icon: string, categoryName: string) {
  try {
    // TODO: 调用后端 API 添加子分类
    console.log('添加子分类:', { name, icon, categoryName });
    toast.success(`子分类 "${name}" 添加成功`);
    showAddModal.value = false;
    // 刷新列表
    await refresh();
  } catch (error: any) {
    console.error('添加子分类失败:', error);
    toast.error(error.message || '添加子分类失败');
  }
}

// 更新子分类
function updateSubCategory(subCategory: SubCategory) {
  // TODO: 实现更新子分类的逻辑（需要后端 API 支持）
  console.log('更新子分类', subCategory);
}

// 删除子分类
function removeSubCategory(subCategory: SubCategory) {
  // TODO: 实现删除子分类的逻辑（需要后端 API 支持）
  console.log('删除子分类', subCategory);
}
</script>

<template>
  <div class="space-y-4">
    <!-- 操作栏 -->
    <div class="flex justify-between items-center">
      <div class="text-lg font-semibold text-gray-800 dark:text-gray-200">
        子分类管理
        <span class="ml-2 text-sm font-normal text-gray-500">
          ({{ categoryStore.subCategories.length }} 个)
        </span>
      </div>
      <div class="flex gap-2">
        <!-- 根据展开状态动态显示按钮 -->
        <button
          v-if="isAllExpanded"
          class="p-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          title="全部折叠"
          @click="collapseAll"
        >
          <ChevronsUp class="w-4 h-4" />
        </button>
        <button
          v-else
          class="p-2 text-gray-600 dark:text-gray-400 hover:text-gray-800 dark:hover:text-gray-200 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          title="全部展开"
          @click="expandAll"
        >
          <ChevronsDown class="w-4 h-4" />
        </button>
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
          title="添加子分类"
          @click="openGlobalAddModal"
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

    <!-- 分组显示子分类 -->
    <div v-else class="space-y-3">
      <div
        v-for="category in categoryStore.categories"
        :key="category.name"
        class="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden"
      >
        <!-- 分类头部 -->
        <div
          class="flex items-center justify-between p-3 bg-gray-50 dark:bg-gray-800 cursor-pointer hover:bg-gray-100 dark:hover:bg-gray-750 transition-colors"
          @click="toggleCategory(category.name)"
        >
          <div class="flex items-center gap-2">
            <component
              :is="isCategoryExpanded(category.name) ? ChevronDown : ChevronRight"
              class="w-4 h-4 text-gray-500"
            />
            <span class="text-xl">{{ category.icon }}</span>
            <span class="font-medium text-gray-800 dark:text-gray-200">
              {{ category.name }}
            </span>
            <span class="text-sm text-gray-500">
              ({{ groupedSubCategories[category.name]?.length || 0 }} 个)
            </span>
          </div>
          <button
            class="p-1.5 bg-green-500 text-white rounded hover:bg-green-600 transition-colors"
            title="添加子分类"
            @click.stop="openAddModal(category.name)"
          >
            <Plus class="w-3.5 h-3.5" />
          </button>
        </div>

        <!-- 子分类列表 -->
        <div
          v-if="isCategoryExpanded(category.name)"
          class="p-4 bg-white dark:bg-gray-900"
        >
          <div
            v-if="groupedSubCategories[category.name]?.length > 0"
            class="grid grid-cols-6 sm:grid-cols-9 md:grid-cols-12 lg:grid-cols-16 xl:grid-cols-20 gap-3"
          >
            <SubCategoryItem
              v-for="subCategory in groupedSubCategories[category.name]"
              :key="`${subCategory.categoryName}-${subCategory.name}`"
              :model-value="subCategory"
              :readonly="true"
              @update:model-value="updateSubCategory"
              @remove="removeSubCategory(subCategory)"
            />
          </div>
          <div v-else class="text-center py-4 text-gray-400 text-sm">
            暂无子分类
          </div>
        </div>
      </div>
    </div>

    <!-- 添加子分类模态框 -->
    <SubCategoryAddModal
      :open="showAddModal"
      :category-name="selectedCategoryForAdd ? selectedCategoryForAdd : undefined"
      :categories="categoryStore.categories"
      :show-category-selector="showCategorySelector"
      @close="showAddModal = false"
      @confirm="handleAddSubCategory"
    />
  </div>
</template>
