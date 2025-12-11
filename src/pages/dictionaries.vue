<script setup lang="ts">
  import { BookOpen, Folder, FolderTree, Hash } from 'lucide-vue-next';
  import CategoriesView from '@/features/money/views/CategoriesView.vue';
  import SubCategoriesView from '@/features/money/views/SubCategoriesView.vue';
  import ProjectsView from '@/features/projects/views/ProjectsView.vue';
  import TagsView from '@/features/tags/views/TagsView.vue';

  definePage({
    name: 'dictionaries',
    meta: {
      requiresAuth: true,
      layout: 'default',
    },
  });

  const activeTab = ref('categories');

  const tabs = [
    { id: 'categories', label: '分类', icon: Folder, component: CategoriesView },
    { id: 'subCategories', label: '子分类', icon: FolderTree, component: SubCategoriesView },
    { id: 'projects', label: '项目', icon: BookOpen, component: ProjectsView },
    { id: 'tags', label: '标签', icon: Hash, component: TagsView },
  ];

  const currentTabComponent = computed(() => {
    const tab = tabs.find(t => t.id === activeTab.value);
    return tab?.component || CategoriesView;
  });
</script>

<template>
  <div class="min-h-screen bg-gray-50 dark:bg-gray-900 p-6">
    <div class="max-w-7xl mx-auto space-y-6">
      <!-- Tab 导航 -->
      <div
        class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-2"
      >
        <div class="flex justify-center gap-2 overflow-x-auto">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            class="flex items-center gap-2 px-4 py-2 rounded-lg transition-all duration-200 whitespace-nowrap"
            :class="activeTab === tab.id
              ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 shadow-sm'
              : 'text-gray-600 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700/50'"
            @click="activeTab = tab.id"
          >
            <component :is="tab.icon" class="w-5 h-5" />
            <span class="font-medium">{{ tab.label }}</span>
          </button>
        </div>
      </div>

      <!-- 内容区域 -->
      <div
        class="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6"
      >
        <component :is="currentTabComponent" />
      </div>
    </div>
  </div>
</template>
