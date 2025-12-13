<script setup lang="ts">
  import { Folder, Search, X } from 'lucide-vue-next';
  import { Modal } from '@/components/ui';
  import type { Projects, ProjectWithUsageStats } from '@/schema/todos';
  import { projectService } from '@/services/projectsService';

  const props = defineProps<{
    open: boolean;
    selectedProjects?: string[]; // 已选中的项目ID列表
  }>();

  const emit = defineEmits<{
    close: [];
    add: [projectId: string];
    remove: [projectId: string];
  }>();

  // 搜索关键词
  const searchQuery = ref('');

  // 从后端获取项目数据（尝试获取带引用数的数据）
  const availableProjects = ref<(Projects | ProjectWithUsageStats)[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // 加载项目列表
  async function loadProjects() {
    loading.value = true;
    error.value = null;
    try {
      const projects = await projectService.list();
      // 只显示未归档的项目
      availableProjects.value = projects.filter(p => !p.isArchived);
    } catch (err) {
      error.value = '加载项目失败';
      console.error('加载项目失败:', err);
    } finally {
      loading.value = false;
    }
  }

  // 监听 open 属性，当打开时加载数据
  watch(
    () => props.open,
    isOpen => {
      if (isOpen && availableProjects.value.length === 0) {
        loadProjects();
      }
    },
  );

  // 筛选项目
  const filteredProjects = computed(() => {
    if (!searchQuery.value) return availableProjects.value;
    const query = searchQuery.value.toLowerCase();
    return availableProjects.value.filter(
      project =>
        project.name.toLowerCase().includes(query) ||
        project.description?.toLowerCase().includes(query),
    );
  });

  // 已选中的项目
  const selectedProjectsSet = computed(() => new Set(props.selectedProjects || []));

  // 检查项目是否已选中
  function isSelected(projectId: string): boolean {
    return selectedProjectsSet.value.has(projectId);
  }

  // 切换项目选择状态
  function toggleProject(projectId: string) {
    if (isSelected(projectId)) {
      emit('remove', projectId);
    } else {
      emit('add', projectId);
    }
  }

  // 关闭弹窗
  function handleClose() {
    searchQuery.value = '';
    emit('close');
  }

  // 获取项目的引用数
  function getProjectUsageCount(project: Projects | ProjectWithUsageStats): number {
    if ('usage' in project) {
      return project.usage.todos.count || 0;
    }
    return 0;
  }
</script>

<template>
  <Modal :open="open" title="选择项目" size="md" :show-footer="false" @close="handleClose">
    <div class="space-y-4">
      <!-- 搜索框 -->
      <div class="relative">
        <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
        <input
          v-model="searchQuery"
          type="text"
          placeholder="搜索项目..."
          class="w-full pl-10 pr-10 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
        <button
          v-if="searchQuery"
          class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
          @click="searchQuery = ''"
        >
          <X class="w-4 h-4" />
        </button>
      </div>

      <!-- 已选中的项目 -->
      <div v-if="selectedProjects && selectedProjects.length > 0" class="space-y-2">
        <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300">
          已选择 ({{ selectedProjects.length }})
        </h4>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="projectId in selectedProjects"
            :key="projectId"
            class="inline-flex items-center gap-2 px-3 py-1.5 bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 rounded-lg hover:bg-blue-200 dark:hover:bg-blue-900/50 transition-colors text-sm"
            @click="emit('remove', projectId)"
          >
            <Folder class="w-4 h-4" />
            <span>{{ availableProjects.find(p => p.serialNum === projectId)?.name }}</span>
            <X class="w-3 h-3" />
          </button>
        </div>
      </div>

      <!-- 加载状态 -->
      <div v-if="loading" class="text-center py-12 text-gray-400 dark:text-gray-500">
        <div
          class="animate-spin w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full mx-auto mb-3"
        />
        <p class="text-sm">加载项目中...</p>
      </div>

      <!-- 错误状态 -->
      <div v-else-if="error" class="text-center py-12">
        <p class="text-sm text-red-600 dark:text-red-400 mb-4">{{ error }}</p>
        <button
          class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          @click="loadProjects"
        >
          重新加载
        </button>
      </div>

      <!-- 项目列表 -->
      <div v-else class="space-y-2">
        <h4 class="text-sm font-medium text-gray-700 dark:text-gray-300">
          可选项目 ({{ filteredProjects.length }})
        </h4>
        <div class="max-h-96 overflow-y-auto space-y-2">
          <button
            v-for="project in filteredProjects"
            :key="project.serialNum"
            class="w-full flex items-center gap-3 p-3 rounded-lg transition-colors text-left"
            :class="
              isSelected(project.serialNum)
                ? 'bg-blue-50 dark:bg-blue-900/20 border-2 border-blue-500 dark:border-blue-400'
                : 'bg-gray-50 dark:bg-gray-800 border-2 border-transparent hover:border-gray-300 dark:hover:border-gray-600'
            "
            @click="toggleProject(project.serialNum)"
          >
            <!-- 项目颜色标识 -->
            <div
              class="w-3 h-3 rounded-full shrink-0"
              :style="{ backgroundColor: project.color }"
            />

            <!-- 项目信息 -->
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="font-medium text-gray-900 dark:text-white truncate">
                  {{ project.name }}
                </span>
                <!-- 引用数 -->
                <span
                  v-if="getProjectUsageCount(project) > 0"
                  class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300"
                  :title="`被 ${getProjectUsageCount(project)} 个待办事项使用`"
                >
                  {{ getProjectUsageCount(project) }}
                </span>
                <span
                  v-if="isSelected(project.serialNum)"
                  class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-blue-100 dark:bg-blue-900/50 text-blue-800 dark:text-blue-200"
                >
                  已选
                </span>
              </div>
            </div>

            <!-- 选择图标 -->
            <div
              class="w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0"
              :class="
                isSelected(project.serialNum)
                  ? 'bg-blue-500 border-blue-500'
                  : 'border-gray-300 dark:border-gray-600'
              "
            >
              <div v-if="isSelected(project.serialNum)" class="w-2 h-2 bg-white rounded-full" />
            </div>
          </button>

          <!-- 空状态 -->
          <div
            v-if="filteredProjects.length === 0"
            class="text-center py-12 text-gray-400 dark:text-gray-500"
          >
            <Folder class="mx-auto mb-3 w-12 h-12 opacity-50" />
            <p class="text-sm">{{ searchQuery ? '没有找到匹配的项目' : '还没有项目' }}</p>
          </div>
        </div>
      </div>
    </div>
  </Modal>
</template>

<style scoped>
  /* 所有样式已使用 Tailwind CSS 4 */
</style>
