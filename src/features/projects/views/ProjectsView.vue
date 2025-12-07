<script setup lang="ts">
  import { FileCheck, FolderOpen, Pencil, Plus, Trash2 } from 'lucide-vue-next';
  import Card from '@/components/ui/Card.vue';
  import type { Projects, ProjectWithUsageStats } from '@/schema/todos';
  import type { ProjectCreate, ProjectUpdate } from '@/services/projects';
  import { ProjectDb } from '@/services/projects';
  import { ProjectTagsDb } from '@/services/projectTags';
  import { toast } from '@/utils/toast';
  import ProjectCreateModal from '../components/ProjectCreateModal.vue';
  import ProjectEditModal from '../components/ProjectEditModal.vue';

  // 使用联合类型，支持有或没有 usage 字段的项目
  type ProjectWithOptionalUsage = Projects | ProjectWithUsageStats;
  const projectsMap = ref(new Map<string, ProjectWithOptionalUsage>());
  const loading = ref(false);
  const showCreateModal = ref(false);
  const showEditModal = ref(false);
  const editingProject = ref<ProjectWithOptionalUsage | null>(null);

  // 加载项目列表
  async function loadProjects() {
    loading.value = true;
    try {
      const projects = await ProjectDb.listProjects();
      projectsMap.value = new Map(projects.map(p => [p.serialNum, p]));
    } catch (error) {
      console.error('加载项目列表失败:', error);
      toast.error('无法加载项目列表，请稍后重试');
    } finally {
      loading.value = false;
    }
  }

  // 打开创建模态框
  function openCreateModal() {
    showCreateModal.value = true;
  }

  // 创建项目
  async function handleCreateConfirm(data: ProjectCreate, tags: string[]) {
    try {
      const newProject = await ProjectDb.createProject(data);

      // 如果有选中的标签，保存标签关联
      if (tags.length > 0) {
        await ProjectTagsDb.updateProjectTags(newProject.serialNum, tags);
      }

      projectsMap.value.set(newProject.serialNum, newProject);
      toast.success(`项目"${newProject.name}"创建成功`);
      showCreateModal.value = false;
    } catch (error) {
      console.error('创建项目失败:', error);
      toast.error(`创建失败: ${String(error)}`);
    }
  }

  // 打开编辑模态框
  function handleEdit(serialNum: string) {
    const project = projectsMap.value.get(serialNum);
    if (!project) return;

    editingProject.value = project;
    showEditModal.value = true;
  }

  // 编辑项目
  async function handleEditConfirm(serialNum: string, data: ProjectUpdate, tags: string[]) {
    try {
      const updatedProject = await ProjectDb.updateProject(serialNum, data);

      // 更新标签关联
      await ProjectTagsDb.updateProjectTags(serialNum, tags);

      projectsMap.value.set(serialNum, updatedProject);
      toast.success(`项目"${updatedProject.name}"更新成功`);
      showEditModal.value = false;
      editingProject.value = null;
    } catch (error) {
      console.error('更新项目失败:', error);
      toast.error(`更新失败: ${String(error)}`);
    }
  }

  // 删除项目
  async function handleDelete(serialNum: string) {
    const project = projectsMap.value.get(serialNum);
    if (!project) return;

    try {
      await ProjectDb.deleteProject(serialNum);
      projectsMap.value.delete(serialNum);
      toast.success(`项目"${project.name}"删除成功`);
    } catch (error) {
      console.error('删除项目失败:', error);
      const errorMsg = String(error);
      // 检查是否是引用错误，使用不同的提示
      if (errorMsg.includes('个待办事项正在使用')) {
        toast.warning(errorMsg);
      } else {
        toast.error('删除失败');
      }
    }
  }

  // 初始化加载
  onMounted(() => {
    loadProjects();
  });
</script>

<template>
  <div class="space-y-4 p-4">
    <!-- 加载中 -->
    <div v-if="loading" class="flex justify-center items-center py-8">
      <div
        class="animate-spin rounded-full h-8 w-8 border-b-2 border-gray-900 dark:border-gray-100"
      />
    </div>

    <!-- 项目列表 -->
    <div v-else>
      <div class="flex justify-between items-center mb-4">
        <h2 class="text-2xl font-bold">项目管理</h2>
        <button
          class="p-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center justify-center"
          title="创建项目"
          @click="openCreateModal"
        >
          <Plus :size="20" />
        </button>
      </div>

      <!-- 空状态 -->
      <div v-if="projectsMap.size === 0" class="text-center py-8 text-gray-500">
        暂无项目，点击 + 按钮开始添加
      </div>

      <!-- 项目卡片 -->
      <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
        <Card
          v-for="[serialNum, project] in projectsMap"
          :key="serialNum"
          shadow="md"
          padding="md"
          class="border-l-4 h-32 flex flex-col hover:shadow-lg transition-shadow"
          :class="[
            project.isArchived ? 'opacity-60' : '',
            `border-l-[${project.color || '#3b82f6'}]`
          ]"
          :style="{ borderLeftColor: project.color || '#3b82f6' }"
        >
          <!-- 标题栏 -->
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2 flex-1 min-w-0">
              <FolderOpen
                class="w-5 h-5 flex-shrink-0"
                :style="{ color: project.color || '#3b82f6' }"
              />
              <h3
                class="font-semibold text-base truncate"
                :style="{ color: project.color || '#3b82f6' }"
              >
                {{ project.name }}
              </h3>
            </div>

            <!-- 操作按钮 -->
            <div class="flex items-center gap-1 flex-shrink-0">
              <!-- 引用计数 -->
              <span
                v-if="'usage' in project && project.usage.todos.count > 0"
                class="flex items-center gap-1 px-2 py-1 text-xs text-gray-600 dark:text-gray-400 bg-gray-100 dark:bg-gray-800 rounded"
                :title="`被 ${project.usage.todos.count} 个待办事项引用`"
              >
                <FileCheck :size="14" />
                {{ project.usage.todos.count }}
              </span>

              <button
                class="p-1.5 text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-800 rounded transition-colors"
                :class="project.isArchived ? '' : 'hover:text-blue-600 dark:hover:text-blue-400'"
                :style="{ '--hover-color': project.color || '#3b82f6' }"
                title="编辑项目"
                @click="handleEdit(serialNum)"
              >
                <Pencil :size="16" />
              </button>
              <button
                class="p-1.5 text-gray-500 hover:text-red-600 dark:hover:text-red-400 hover:bg-gray-100 dark:hover:bg-gray-800 rounded transition-colors"
                title="删除项目"
                @click="handleDelete(serialNum)"
              >
                <Trash2 :size="16" />
              </button>
            </div>
          </div>

          <!-- 描述 - 只显示一行，超出部分隐藏 -->
          <p
            v-if="project.description"
            class="text-sm text-gray-600 dark:text-gray-400 line-clamp-1 flex-1"
            :title="project.description"
          >
            {{ project.description }}
          </p>
          <p v-else class="text-sm text-gray-400 dark:text-gray-500 italic flex-1">暂无描述</p>

          <!-- 底部状态 -->
          <div class="flex items-center gap-2 mt-auto pt-2">
            <span
              v-if="project.isArchived"
              class="text-xs px-2 py-0.5 bg-gray-200 dark:bg-gray-700 rounded"
            >
              已归档
            </span>
            <span v-else class="text-xs text-gray-500">活跃</span>
          </div>
        </Card>
      </div>
    </div>

    <!-- 创建项目模态框 -->
    <ProjectCreateModal
      :open="showCreateModal"
      @close="showCreateModal = false"
      @confirm="handleCreateConfirm"
    />

    <!-- 编辑项目模态框 -->
    <ProjectEditModal
      :open="showEditModal"
      :project="editingProject"
      @close="showEditModal = false"
      @confirm="handleEditConfirm"
    />
  </div>
</template>
