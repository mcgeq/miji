<script setup lang="ts">
import { Folder, Tag, X } from 'lucide-vue-next';
import ProjectSelector from '@/features/todos/components/ProjectSelector.vue';
import TagSelector from '@/features/todos/components/TagSelector.vue';
import { useTodoAssociations } from '@/features/todos/composables/useTodoAssociations';

const props = defineProps<{
  todoId: string;
}>();

// 选择器显示状态
const showProjectSelector = ref(false);
const showTagSelector = ref(false);

// 使用关联管理 composable
const {
  selectedProjects,
  selectedTags,
  loading,
  error,
  addProject,
  removeProject,
  addTag,
  removeTag,
  getProjectName,
  getTagName,
  getProjectColor,
} = useTodoAssociations(props.todoId);

// 处理项目操作（带错误提示）
async function handleAddProject(projectId: string) {
  try {
    await addProject(projectId);
  } catch (err) {
    // 可以集成 toast 通知
    console.error('添加项目失败:', err);
  }
}

async function handleRemoveProject(projectId: string) {
  try {
    await removeProject(projectId);
  } catch (err) {
    console.error('移除项目失败:', err);
  }
}

// 处理标签操作（带错误提示）
async function handleAddTag(tagId: string) {
  try {
    await addTag(tagId);
  } catch (err) {
    console.error('添加标签失败:', err);
  }
}

async function handleRemoveTag(tagId: string) {
  try {
    await removeTag(tagId);
  } catch (err) {
    console.error('移除标签失败:', err);
  }
}
</script>

<template>
  <div class="space-y-2">
    <!-- 加载状态 -->
    <div v-if="loading" class="text-sm text-gray-500 dark:text-gray-400 animate-pulse">
      加载关联数据...
    </div>

    <!-- 错误状态 -->
    <div v-else-if="error" class="text-sm text-red-600 dark:text-red-400">
      {{ error }}
    </div>

    <!-- 正常内容 -->
    <template v-else>
      <!-- 操作按钮 -->
      <div class="flex flex-wrap gap-2">
        <button
          class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
          @click="showProjectSelector = true"
        >
          <Folder class="w-4 h-4" />
          <span>项目</span>
          <span
            v-if="selectedProjects.length > 0"
            class="px-1.5 py-0.5 text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 rounded"
          >
            {{ selectedProjects.length }}
          </span>
        </button>

        <button
          class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
          @click="showTagSelector = true"
        >
          <Tag class="w-4 h-4" />
          <span>标签</span>
          <span
            v-if="selectedTags.length > 0"
            class="px-1.5 py-0.5 text-xs bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 rounded"
          >
            {{ selectedTags.length }}
          </span>
        </button>
      </div>

      <!-- 已关联的项目 -->
      <div v-if="selectedProjects.length > 0" class="space-y-1.5">
        <div class="text-xs font-medium text-gray-500 dark:text-gray-400">
          关联的项目
        </div>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="projectId in selectedProjects"
            :key="projectId"
            class="inline-flex items-center gap-1.5 px-2.5 py-1 text-sm rounded-lg transition-all hover:opacity-80"
            :style="{
              backgroundColor: `${getProjectColor(projectId)}20`,
              color: getProjectColor(projectId),
              borderWidth: '1px',
              borderColor: `${getProjectColor(projectId)}40`,
            }"
            @click="handleRemoveProject(projectId)"
          >
            <div
              class="w-2 h-2 rounded-full"
              :style="{ backgroundColor: getProjectColor(projectId) }"
            />
            <span>{{ getProjectName(projectId) }}</span>
            <X class="w-3 h-3 opacity-60 hover:opacity-100" />
          </button>
        </div>
      </div>

      <!-- 已关联的标签 -->
      <div v-if="selectedTags.length > 0" class="space-y-1.5">
        <div class="text-xs font-medium text-gray-500 dark:text-gray-400">
          已添加的标签
        </div>
        <div class="flex flex-wrap gap-1.5">
          <button
            v-for="tagId in selectedTags"
            :key="tagId"
            class="inline-flex items-center gap-1.5 px-2.5 py-1 text-sm bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
            @click="handleRemoveTag(tagId)"
          >
            <Tag class="w-3 h-3" />
            <span>{{ getTagName(tagId) }}</span>
            <X class="w-3 h-3 opacity-60 hover:opacity-100" />
          </button>
        </div>
      </div>
    </template>

    <!-- 项目选择器 -->
    <ProjectSelector
      :open="showProjectSelector"
      :selected-projects="selectedProjects"
      @close="showProjectSelector = false"
      @add="handleAddProject"
      @remove="handleRemoveProject"
    />

    <!-- 标签选择器 -->
    <TagSelector
      :open="showTagSelector"
      :selected-tags="selectedTags"
      @close="showTagSelector = false"
      @add="handleAddTag"
      @remove="handleRemoveTag"
    />
  </div>
</template>

<style scoped>
/* 所有样式已使用 Tailwind CSS 4 */
</style>
