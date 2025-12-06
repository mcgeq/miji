# 项目标签功能 - 前端实现指南

## ✅ 已完成的工作

### 1. 后端 API ✅
- `project_tags_get` - 获取项目标签
- `project_tags_update` - 更新项目标签
- 服务层：`ProjectTagsService`
- 命令层：已注册到 Tauri

### 2. 前端服务 ✅
**文件**：`src/services/projectTags.ts`
```typescript
export class ProjectTagsDb {
  static async getProjectTags(projectSerialNum: string): Promise<Tags[]>
  static async updateProjectTags(projectSerialNum: string, tagSerialNums: string[]): Promise<void>
}
```

### 3. 标签选择器组件 ✅
**文件**：`src/components/common/TagSelector.vue`

**特性**：
- 多选标签
- 下拉列表选择
- 标签徽章显示
- 支持移除标签

### 4. 项目创建集成 ✅
**文件**：`src/features/projects/components/ProjectCreateModal.vue`

**功能**：
- 创建项目时可以选择标签
- 创建成功后自动保存标签关联

## 🔧 待完成的功能

### 功能 1：在项目卡片显示标签

**修改文件**：`src/features/projects/views/ProjectsView.vue`

```vue
<script setup lang="ts">
// ... 现有导入 ...

// 加载项目标签
async function loadProjectTags(serialNum: string) {
  try {
    const tags = await ProjectTagsDb.getProjectTags(serialNum);
    projectTagsMap.value.set(serialNum, tags);
  } catch (error) {
    console.error('加载项目标签失败:', error);
  }
}

// 修改 loadProjects 函数
async function loadProjects() {
  loading.value = true;
  try {
    const projects = await ProjectDb.listProjects();
    projectsMap.value = new Map(projects.map((p) => [p.serialNum, p]));
    
    // 加载每个项目的标签
    for (const project of projects) {
      await loadProjectTags(project.serialNum);
    }
  } catch (error) {
    console.error('加载项目列表失败:', error);
    toast.error('加载失败');
  } finally {
    loading.value = false;
  }
}
</script>

<template>
  <!-- 在项目卡片中添加标签显示 -->
  <Card ...>
    <!-- ... 现有内容 ... -->
    
    <!-- 描述后添加标签 -->
    <p>{{ project.description }}</p>
    
    <!-- 标签列表 -->
    <div 
      v-if="projectTagsMap.get(serialNum)?.length" 
      class="flex flex-wrap gap-1 mt-2"
    >
      <span
        v-for="tag in projectTagsMap.get(serialNum)"
        :key="tag.serialNum"
        class="inline-flex items-center gap-1 px-2 py-0.5 text-xs bg-blue-100 dark:bg-blue-900 text-blue-800 dark:text-blue-200 rounded"
      >
        <Hash :size="12" />
        {{ tag.name }}
      </span>
    </div>
    
    <!-- ... 状态等其他内容 ... -->
  </Card>
</template>
```

### 功能 2：项目编辑功能（含标签编辑）

**创建文件**：`src/features/projects/components/ProjectEditModal.vue`

```vue
<script setup lang="ts">
import { onMounted } from 'vue';
import Modal from '@/components/ui/Modal.vue';
import Input from '@/components/ui/Input.vue';
import Textarea from '@/components/ui/Textarea.vue';
import ColorSelector from '@/components/common/ColorSelector.vue';
import TagSelector from '@/components/common/TagSelector.vue';
import { ProjectTagsDb } from '@/services/projectTags';
import type { Projects } from '@/schema/todos';
import type { ProjectUpdate } from '@/services/projects';

interface Props {
  open: boolean;
  project: Projects | null;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  close: [];
  confirm: [data: ProjectUpdate, tags: string[]];
}>();

const formData = ref<ProjectUpdate>({
  name: null,
  description: null,
  ownerId: null,
  color: null,
  isArchived: null,
});

const selectedTags = ref<string[]>([]);

// 加载项目数据
async function loadProject() {
  if (!props.project) return;
  
  formData.value = {
    name: props.project.name,
    description: props.project.description,
    ownerId: props.project.ownerId,
    color: props.project.color,
    isArchived: props.project.isArchived,
  };
  
  // 加载项目标签
  try {
    const tags = await ProjectTagsDb.getProjectTags(props.project.serialNum);
    selectedTags.value = tags.map(t => t.serialNum);
  } catch (error) {
    console.error('加载项目标签失败:', error);
  }
}

watch(() => props.open, (newVal) => {
  if (newVal) {
    loadProject();
  }
});

const handleConfirm = () => {
  emit('confirm', formData.value, selectedTags.value);
};
</script>

<template>
  <Modal
    :open="open"
    title="编辑项目"
    @close="emit('close')"
    @cancel="emit('close')"
    @confirm="handleConfirm"
  >
    <div class="space-y-4">
      <Input v-model="formData.name" label="项目名称" />
      <Textarea v-model="formData.description" placeholder="项目描述" />
      <ColorSelector v-model="formData.color" />
      <TagSelector v-model="selectedTags" placeholder="项目标签" />
    </div>
  </Modal>
</template>
```

**更新 ProjectsView.vue**：
```typescript
const showEditModal = ref(false);
const editingProject = ref<Projects | null>(null);

function handleEdit(serialNum: string) {
  const project = projectsMap.value.get(serialNum);
  if (!project) return;
  
  editingProject.value = project;
  showEditModal.value = true;
}

async function handleEditConfirm(data: ProjectUpdate, tags: string[]) {
  if (!editingProject.value) return;
  
  try {
    const updated = await ProjectDb.updateProject(editingProject.value.serialNum, data);
    await ProjectTagsDb.updateProjectTags(editingProject.value.serialNum, tags);
    
    projectsMap.value.set(updated.serialNum, updated);
    await loadProjectTags(updated.serialNum);
    
    toast.success('项目更新成功');
    showEditModal.value = false;
  } catch (error) {
    console.error('更新项目失败:', error);
    toast.error('更新失败');
  }
}
```

### 功能 3：按标签筛选项目

**更新 ProjectsView.vue**：

```vue
<script setup lang="ts">
// 添加筛选状态
const selectedFilterTags = ref<string[]>([]);
const allTags = ref<Tags[]>([]);

// 加载所有标签
async function loadAllTags() {
  try {
    allTags.value = await TagDb.listTags();
  } catch (error) {
    console.error('加载标签失败:', error);
  }
}

// 筛选后的项目
const filteredProjects = computed(() => {
  if (selectedFilterTags.value.length === 0) {
    return Array.from(projectsMap.value.entries());
  }
  
  return Array.from(projectsMap.value.entries()).filter(([serialNum]) => {
    const projectTags = projectTagsMap.value.get(serialNum) || [];
    const projectTagIds = projectTags.map(t => t.serialNum);
    
    // 项目必须包含所有选中的筛选标签
    return selectedFilterTags.value.every(tagId => projectTagIds.includes(tagId));
  });
});

onMounted(() => {
  loadProjects();
  loadAllTags();
});
</script>

<template>
  <div class="p-6">
    <div class="flex items-center justify-between mb-6">
      <h1 class="text-2xl font-bold">项目管理</h1>
      
      <div class="flex items-center gap-4">
        <!-- 标签筛选 -->
        <div class="relative">
          <TagSelector
            v-model="selectedFilterTags"
            placeholder="按标签筛选..."
          />
        </div>
        
        <!-- 创建按钮 -->
        <button @click="openCreateModal">
          <Plus :size="20" />
        </button>
      </div>
    </div>

    <!-- 项目卡片列表 -->
    <div v-if="filteredProjects.length === 0" class="text-center py-8 text-gray-500">
      暂无符合条件的项目
    </div>
    
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
      <Card
        v-for="[serialNum, project] in filteredProjects"
        :key="serialNum"
        ...
      >
        <!-- 项目卡片内容 -->
      </Card>
    </div>
  </div>
</template>
```

## 🎨 样式建议

### 标签徽章样式
```css
/* 项目标签徽章 - 浅色小巧 */
.project-tag {
  @apply inline-flex items-center gap-1 px-2 py-0.5 text-xs;
  @apply bg-blue-100 dark:bg-blue-900;
  @apply text-blue-800 dark:text-blue-200;
  @apply rounded;
}

/* 标签计数提示 */
.tag-count {
  @apply flex items-center gap-1 px-2 py-1 text-xs;
  @apply text-gray-600 dark:text-gray-400;
  @apply bg-gray-100 dark:bg-gray-800 rounded;
}
```

## 🎯 使用流程

### 1. 创建项目并添加标签
```
1. 点击 "+" 按钮
2. 填写项目信息
3. 在 "项目标签" 区域选择标签
4. 点击确认创建
```

### 2. 编辑项目标签
```
1. 点击项目卡片的编辑按钮
2. 修改标签（添加/删除）
3. 点击确认保存
```

### 3. 按标签筛选
```
1. 在顶部标签筛选器选择标签
2. 项目列表自动筛选
3. 支持多标签组合筛选（AND 逻辑）
```

### 4. 查看项目标签
```
- 项目卡片底部显示标签列表
- 标签以徽章形式展示
- Hash 图标 + 标签名称
```

## 📊 数据流程

```
创建/编辑项目
  ↓
ProjectCreate/UpdateModal
  ├─ 选择标签（TagSelector）
  ├─ selectedTags = ['tag1', 'tag2']
  │
  ↓ emit('confirm', data, tags)
  │
ProjectsView.handleCreateConfirm
  ├─ 1. 创建项目 → ProjectDb.createProject
  ├─ 2. 保存标签 → ProjectTagsDb.updateProjectTags
  ├─ 3. 加载标签 → loadProjectTags
  │
  ↓
显示项目卡片
  └─ projectTagsMap.get(serialNum) → 标签列表
```

## ✅ 最终效果

### 项目卡片
```
┌─────────────────────────┐
│ 📁 前端开发    [引用:5]  │
│ ────────────────────── │
│ 一个很长的描述...       │
│                         │
│ #技术 #紧急 #客户项目  │
│                         │
│ 活跃                    │
│              [编辑][删除]│
└─────────────────────────┘
```

### 筛选界面
```
项目管理              [#技术 #紧急 ×] [+ 添加]  [+ 创建]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[📁 前端开发]  [📁 后端优化]  [📁 UI设计]
#技术 #紧急     #技术 #内部     #设计 #客户
```

## 🚀 开始实现

按以下顺序完成剩余功能：
1. ✅ 后端 API（已完成）
2. ✅ 服务层（已完成）
3. ✅ 标签选择器（已完成）
4. ✅ 创建集成（已完成）
5. ⏳ 显示标签（待完成）
6. ⏳ 编辑功能（待完成）
7. ⏳ 标签筛选（待完成）

完成这些功能后，项目标签系统就完整可用了！🎉
