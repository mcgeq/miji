# ProjectSelector & TagSelector 集成指南

**创建时间**: 2025-11-28  
**版本**: 1.0

---

## 📋 概述

本指南展示如何将 `ProjectSelector` 和 `TagSelector` 组件集成到 TodoItem 组件中，实现项目和标签的关联功能。

---

## 🎯 集成目标

1. 在 TodoItem 中添加项目和标签选择功能
2. 显示当前关联的项目和标签
3. 支持添加、移除关联
4. 数据持久化到后端

---

## 📦 方案 1: 在 TodoItem 中直接集成

### 1.1 修改 TodoItem.vue

```vue
<script setup lang="ts">
import { Folder, Tag, X } from 'lucide-vue-next';
import ProjectSelector from '@/features/todos/components/ProjectSelector.vue';
import TagSelector from '@/features/todos/components/TagSelector.vue';
import type { Todo } from '@/schema/todos';

const props = defineProps<{
  todo: Todo;
}>();

const emit = defineEmits<{
  update: [todo: Todo];
}>();

// 选择器显示状态
const showProjectSelector = ref(false);
const showTagSelector = ref(false);

// 已选中的项目和标签 ID 列表
// 注意: 这些应该从 todo 对象中获取，或通过关联表查询
const selectedProjects = ref<string[]>([]);
const selectedTags = ref<string[]>([]);

// 加载已关联的项目和标签
onMounted(async () => {
  // TODO: 从后端加载当前 todo 关联的项目和标签
  // const projects = await TodoDb.listProjects(props.todo.serialNum);
  // const tags = await TodoDb.listTags(props.todo.serialNum);
  // selectedProjects.value = projects.map(p => p.serialNum);
  // selectedTags.value = tags.map(t => t.serialNum);
});

// 添加项目关联
async function handleAddProject(projectId: string) {
  try {
    // TODO: 调用后端 API 添加关联
    // await TodoDb.addProject(props.todo.serialNum, projectId);
    selectedProjects.value.push(projectId);
    console.log('添加项目关联:', projectId);
  } catch (error) {
    console.error('添加项目失败:', error);
  }
}

// 移除项目关联
async function handleRemoveProject(projectId: string) {
  try {
    // TODO: 调用后端 API 移除关联
    // await TodoDb.removeProject(props.todo.serialNum, projectId);
    selectedProjects.value = selectedProjects.value.filter(id => id !== projectId);
    console.log('移除项目关联:', projectId);
  } catch (error) {
    console.error('移除项目失败:', error);
  }
}

// 添加标签关联
async function handleAddTag(tagId: string) {
  try {
    // TODO: 调用后端 API 添加关联
    // await TodoDb.addTag(props.todo.serialNum, tagId);
    selectedTags.value.push(tagId);
    console.log('添加标签关联:', tagId);
  } catch (error) {
    console.error('添加标签失败:', error);
  }
}

// 移除标签关联
async function handleRemoveTag(tagId: string) {
  try {
    // TODO: 调用后端 API 移除关联
    // await TodoDb.removeTag(props.todo.serialNum, tagId);
    selectedTags.value = selectedTags.value.filter(id => id !== tagId);
    console.log('移除标签关联:', tagId);
  } catch (error) {
    console.error('移除标签失败:', error);
  }
}
</script>

<template>
  <div class="todo-item">
    <!-- 原有的 TodoItem 内容 -->
    
    <!-- 项目和标签显示区域 -->
    <div class="flex items-center gap-2 mt-2">
      <!-- 项目按钮 -->
      <button
        class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        @click="showProjectSelector = true"
      >
        <Folder class="w-3 h-3" />
        <span>项目 ({{ selectedProjects.length }})</span>
      </button>

      <!-- 标签按钮 -->
      <button
        class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        @click="showTagSelector = true"
      >
        <Tag class="w-3 h-3" />
        <span>标签 ({{ selectedTags.length }})</span>
      </button>

      <!-- 已关联的项目显示 -->
      <div v-if="selectedProjects.length > 0" class="flex gap-1">
        <span
          v-for="projectId in selectedProjects.slice(0, 3)"
          :key="projectId"
          class="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 rounded"
        >
          {{ projectId }}
          <button
            class="hover:text-blue-900 dark:hover:text-blue-100"
            @click.stop="handleRemoveProject(projectId)"
          >
            <X class="w-3 h-3" />
          </button>
        </span>
        <span
          v-if="selectedProjects.length > 3"
          class="px-2 py-0.5 text-xs text-gray-500"
        >
          +{{ selectedProjects.length - 3 }}
        </span>
      </div>

      <!-- 已关联的标签显示 -->
      <div v-if="selectedTags.length > 0" class="flex gap-1">
        <span
          v-for="tagId in selectedTags.slice(0, 3)"
          :key="tagId"
          class="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 rounded"
        >
          {{ tagId }}
          <button
            class="hover:text-green-900 dark:hover:text-green-100"
            @click.stop="handleRemoveTag(tagId)"
          >
            <X class="w-3 h-3" />
          </button>
        </span>
        <span
          v-if="selectedTags.length > 3"
          class="px-2 py-0.5 text-xs text-gray-500"
        >
          +{{ selectedTags.length - 3 }}
        </span>
      </div>
    </div>

    <!-- 项目选择器 -->
    <ProjectSelector
      :open="showProjectSelector"
      :selectedProjects="selectedProjects"
      @close="showProjectSelector = false"
      @add="handleAddProject"
      @remove="handleRemoveProject"
    />

    <!-- 标签选择器 -->
    <TagSelector
      :open="showTagSelector"
      :selectedTags="selectedTags"
      @close="showTagSelector = false"
      @add="handleAddTag"
      @remove="handleRemoveTag"
    />
  </div>
</template>
```

---

## 📦 方案 2: 使用独立的关联管理组件

### 2.1 创建 TodoAssociations.vue

```vue
<script setup lang="ts">
import { Folder, Tag, X } from 'lucide-vue-next';
import ProjectSelector from '@/features/todos/components/ProjectSelector.vue';
import TagSelector from '@/features/todos/components/TagSelector.vue';
import { ProjectDb } from '@/services/projects';
import { TagDb } from '@/services/tags';
import type { Projects } from '@/schema/todos';
import type { Tags } from '@/schema/tags';

const props = defineProps<{
  todoId: string;
}>();

// 选择器显示状态
const showProjectSelector = ref(false);
const showTagSelector = ref(false);

// 已选中的项目和标签
const selectedProjects = ref<string[]>([]);
const selectedTags = ref<string[]>([]);

// 项目和标签的详细信息（用于显示名称）
const projectsMap = ref<Map<string, Projects>>(new Map());
const tagsMap = ref<Map<string, Tags>>(new Map());

// 加载关联数据
async function loadAssociations() {
  try {
    // TODO: 从后端加载关联
    // const projects = await TodoProjectDb.listByTodo(props.todoId);
    // const tags = await TodoTagDb.listByTodo(props.todoId);
    // selectedProjects.value = projects.map(p => p.projectSerialNum);
    // selectedTags.value = tags.map(t => t.tagSerialNum);
    
    // 加载项目和标签详情
    const allProjects = await ProjectDb.listProjects();
    const allTags = await TagDb.listTags();
    
    projectsMap.value = new Map(allProjects.map(p => [p.serialNum, p]));
    tagsMap.value = new Map(allTags.map(t => [t.serialNum, t]));
  } catch (error) {
    console.error('加载关联失败:', error);
  }
}

onMounted(() => {
  loadAssociations();
});

// 项目操作
async function handleAddProject(projectId: string) {
  try {
    // TODO: 调用后端 API
    // await TodoProjectDb.add(props.todoId, projectId);
    selectedProjects.value.push(projectId);
  } catch (error) {
    console.error('添加项目失败:', error);
  }
}

async function handleRemoveProject(projectId: string) {
  try {
    // TODO: 调用后端 API
    // await TodoProjectDb.remove(props.todoId, projectId);
    selectedProjects.value = selectedProjects.value.filter(id => id !== projectId);
  } catch (error) {
    console.error('移除项目失败:', error);
  }
}

// 标签操作
async function handleAddTag(tagId: string) {
  try {
    // TODO: 调用后端 API
    // await TodoTagDb.add(props.todoId, tagId);
    selectedTags.value.push(tagId);
  } catch (error) {
    console.error('添加标签失败:', error);
  }
}

async function handleRemoveTag(tagId: string) {
  try {
    // TODO: 调用后端 API
    // await TodoTagDb.remove(props.todoId, tagId);
    selectedTags.value = selectedTags.value.filter(id => id !== tagId);
  } catch (error) {
    console.error('移除标签失败:', error);
  }
}

// 获取项目名称
function getProjectName(projectId: string): string {
  return projectsMap.value.get(projectId)?.name || projectId;
}

// 获取标签名称
function getTagName(tagId: string): string {
  return tagsMap.value.get(tagId)?.name || tagId;
}

// 获取项目颜色
function getProjectColor(projectId: string): string {
  return projectsMap.value.get(projectId)?.color || '#3B82F6';
}
</script>

<template>
  <div class="space-y-2">
    <!-- 操作按钮 -->
    <div class="flex gap-2">
      <button
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        @click="showProjectSelector = true"
      >
        <Folder class="w-4 h-4" />
        <span>关联项目</span>
        <span
          v-if="selectedProjects.length > 0"
          class="px-1.5 py-0.5 text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 rounded"
        >
          {{ selectedProjects.length }}
        </span>
      </button>

      <button
        class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
        @click="showTagSelector = true"
      >
        <Tag class="w-4 h-4" />
        <span>添加标签</span>
        <span
          v-if="selectedTags.length > 0"
          class="px-1.5 py-0.5 text-xs bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300 rounded"
        >
          {{ selectedTags.length }}
        </span>
      </button>
    </div>

    <!-- 已关联的项目 -->
    <div v-if="selectedProjects.length > 0" class="space-y-1">
      <div class="text-xs text-gray-500 dark:text-gray-400">关联的项目:</div>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="projectId in selectedProjects"
          :key="projectId"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 text-sm rounded-lg transition-colors"
          :style="{ 
            backgroundColor: getProjectColor(projectId) + '20',
            color: getProjectColor(projectId)
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
    <div v-if="selectedTags.length > 0" class="space-y-1">
      <div class="text-xs text-gray-500 dark:text-gray-400">已添加的标签:</div>
      <div class="flex flex-wrap gap-1.5">
        <button
          v-for="tagId in selectedTags"
          :key="tagId"
          class="inline-flex items-center gap-1.5 px-2.5 py-1 text-sm bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-300 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
          @click="handleRemoveTag(tagId)"
        >
          <Tag class="w-3 h-3" />
          <span>{{ getTagName(tagId) }}</span>
          <X class="w-3 h-3 opacity-60 hover:opacity-100" />
        </button>
      </div>
    </div>

    <!-- 选择器 -->
    <ProjectSelector
      :open="showProjectSelector"
      :selectedProjects="selectedProjects"
      @close="showProjectSelector = false"
      @add="handleAddProject"
      @remove="handleRemoveProject"
    />

    <TagSelector
      :open="showTagSelector"
      :selectedTags="selectedTags"
      @close="showTagSelector = false"
      @add="handleAddTag"
      @remove="handleRemoveTag"
    />
  </div>
</template>
```

### 2.2 在 TodoItem 中使用

```vue
<script setup lang="ts">
import TodoAssociations from './TodoAssociations.vue';
import type { Todo } from '@/schema/todos';

const props = defineProps<{
  todo: Todo;
}>();
</script>

<template>
  <div class="todo-item">
    <!-- 原有内容 -->
    
    <!-- 关联管理组件 -->
    <TodoAssociations :todoId="todo.serialNum" />
  </div>
</template>
```

---

## 🔧 方案 3: 使用 Composable（推荐）

### 3.1 创建 useTodoAssociations.ts

```typescript
import { ref, onMounted } from 'vue';
import { ProjectDb } from '@/services/projects';
import { TagDb } from '@/services/tags';
import type { Projects } from '@/schema/todos';
import type { Tags } from '@/schema/tags';

export function useTodoAssociations(todoId: string) {
  // 状态
  const selectedProjects = ref<string[]>([]);
  const selectedTags = ref<string[]>([]);
  const projectsMap = ref<Map<string, Projects>>(new Map());
  const tagsMap = ref<Map<string, Tags>>(new Map());
  const loading = ref(false);
  const error = ref<string | null>(null);

  // 加载所有项目和标签
  async function loadMasterData() {
    try {
      const [projects, tags] = await Promise.all([
        ProjectDb.listProjects(),
        TagDb.listTags(),
      ]);

      projectsMap.value = new Map(projects.map(p => [p.serialNum, p]));
      tagsMap.value = new Map(tags.map(t => [t.serialNum, t]));
    } catch (err) {
      console.error('加载主数据失败:', err);
    }
  }

  // 加载当前 todo 的关联
  async function loadAssociations() {
    loading.value = true;
    error.value = null;

    try {
      await loadMasterData();

      // TODO: 从后端加载当前 todo 的关联
      // const todoProjects = await TodoProjectDb.listByTodo(todoId);
      // const todoTags = await TodoTagDb.listByTodo(todoId);
      // selectedProjects.value = todoProjects.map(p => p.projectSerialNum);
      // selectedTags.value = todoTags.map(t => t.tagSerialNum);

      // 临时模拟数据
      selectedProjects.value = [];
      selectedTags.value = [];
    } catch (err) {
      error.value = '加载关联失败';
      console.error('加载关联失败:', err);
    } finally {
      loading.value = false;
    }
  }

  // 项目操作
  async function addProject(projectId: string) {
    try {
      // TODO: 调用后端 API
      // await TodoProjectDb.add(todoId, projectId);
      if (!selectedProjects.value.includes(projectId)) {
        selectedProjects.value.push(projectId);
      }
    } catch (err) {
      console.error('添加项目失败:', err);
      throw err;
    }
  }

  async function removeProject(projectId: string) {
    try {
      // TODO: 调用后端 API
      // await TodoProjectDb.remove(todoId, projectId);
      selectedProjects.value = selectedProjects.value.filter(id => id !== projectId);
    } catch (err) {
      console.error('移除项目失败:', err);
      throw err;
    }
  }

  // 标签操作
  async function addTag(tagId: string) {
    try {
      // TODO: 调用后端 API
      // await TodoTagDb.add(todoId, tagId);
      if (!selectedTags.value.includes(tagId)) {
        selectedTags.value.push(tagId);
      }
    } catch (err) {
      console.error('添加标签失败:', err);
      throw err;
    }
  }

  async function removeTag(tagId: string) {
    try {
      // TODO: 调用后端 API
      // await TodoTagDb.remove(todoId, tagId);
      selectedTags.value = selectedTags.value.filter(id => id !== tagId);
    } catch (err) {
      console.error('移除标签失败:', err);
      throw err;
    }
  }

  // 获取详情
  function getProject(projectId: string): Projects | undefined {
    return projectsMap.value.get(projectId);
  }

  function getTag(tagId: string): Tags | undefined {
    return tagsMap.value.get(tagId);
  }

  // 自动加载
  onMounted(() => {
    loadAssociations();
  });

  return {
    // 状态
    selectedProjects,
    selectedTags,
    projectsMap,
    tagsMap,
    loading,
    error,

    // 方法
    loadAssociations,
    addProject,
    removeProject,
    addTag,
    removeTag,
    getProject,
    getTag,
  };
}
```

### 3.2 在组件中使用

```vue
<script setup lang="ts">
import { Folder, Tag, X } from 'lucide-vue-next';
import ProjectSelector from '@/features/todos/components/ProjectSelector.vue';
import TagSelector from '@/features/todos/components/TagSelector.vue';
import { useTodoAssociations } from '@/features/todos/composables/useTodoAssociations';

const props = defineProps<{
  todoId: string;
}>();

const showProjectSelector = ref(false);
const showTagSelector = ref(false);

const {
  selectedProjects,
  selectedTags,
  loading,
  error,
  addProject,
  removeProject,
  addTag,
  removeTag,
  getProject,
  getTag,
} = useTodoAssociations(props.todoId);
</script>

<template>
  <div class="space-y-2">
    <!-- 加载状态 -->
    <div v-if="loading" class="text-sm text-gray-500">加载中...</div>

    <!-- 错误状态 -->
    <div v-else-if="error" class="text-sm text-red-600">{{ error }}</div>

    <!-- 正常内容 -->
    <template v-else>
      <!-- 操作按钮 -->
      <div class="flex gap-2">
        <button
          class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-lg border hover:bg-gray-100"
          @click="showProjectSelector = true"
        >
          <Folder class="w-4 h-4" />
          项目 ({{ selectedProjects.length }})
        </button>

        <button
          class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-lg border hover:bg-gray-100"
          @click="showTagSelector = true"
        >
          <Tag class="w-4 h-4" />
          标签 ({{ selectedTags.length }})
        </button>
      </div>

      <!-- 显示关联 -->
      <div v-if="selectedProjects.length > 0" class="flex flex-wrap gap-1.5">
        <button
          v-for="projectId in selectedProjects"
          :key="projectId"
          class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-lg bg-blue-100"
          @click="removeProject(projectId)"
        >
          {{ getProject(projectId)?.name || projectId }}
          <X class="w-3 h-3" />
        </button>
      </div>

      <div v-if="selectedTags.length > 0" class="flex flex-wrap gap-1.5">
        <button
          v-for="tagId in selectedTags"
          :key="tagId"
          class="inline-flex items-center gap-1 px-2 py-1 text-xs rounded-lg bg-green-100"
          @click="removeTag(tagId)"
        >
          {{ getTag(tagId)?.name || tagId }}
          <X class="w-3 h-3" />
        </button>
      </div>
    </template>

    <!-- 选择器 -->
    <ProjectSelector
      :open="showProjectSelector"
      :selectedProjects="selectedProjects"
      @close="showProjectSelector = false"
      @add="addProject"
      @remove="removeProject"
    />

    <TagSelector
      :open="showTagSelector"
      :selectedTags="selectedTags"
      @close="showTagSelector = false"
      @add="addTag"
      @remove="removeTag"
    />
  </div>
</template>
```

---

## 📝 集成步骤总结

### 推荐步骤

1. **创建 Composable** ✅
   ```bash
   src/features/todos/composables/useTodoAssociations.ts
   ```

2. **创建独立组件** ✅
   ```bash
   src/features/todos/components/TodoAssociations.vue
   ```

3. **在 TodoItem 中集成** ✅
   ```vue
   <TodoAssociations :todoId="todo.serialNum" />
   ```

4. **实施后端 Commands** ⏳
   - 参考 `TODOS_BACKEND_COMMANDS_TODO.md`
   - 实现 todo_project_* 和 todo_tag_* commands

5. **更新服务层** ⏳
   - 在 TodoDb 中添加关联操作方法
   - 取消注释临时的 TODO 标记

6. **测试功能** ✅
   - 测试项目选择和移除
   - 测试标签选择和移除
   - 测试数据持久化

---

## 🎨 UI 效果示例

```
┌─────────────────────────────────────────────┐
│ ☐ 完成项目文档编写                           │
│                                             │
│ [📁 项目 (2)] [🏷️ 标签 (3)]                │
│                                             │
│ 关联的项目:                                  │
│ [🔵 工作项目 ×] [🟢 个人项目 ×]              │
│                                             │
│ 已添加的标签:                                │
│ [重要 ×] [紧急 ×] [工作 ×]                   │
└─────────────────────────────────────────────┘
```

---

## ✅ 下一步

1. 选择一个集成方案（推荐方案 3）
2. 创建必要的文件
3. 实施后端 Commands（如果还没有）
4. 测试和调试
5. 优化用户体验

---

**文档版本**: 1.0  
**最后更新**: 2025-11-28 21:10
