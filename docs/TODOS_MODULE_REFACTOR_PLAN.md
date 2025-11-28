# Todos 模块全面重构计划

**创建时间**: 2025-11-28  
**状态**: 规划中  
**目标**: 结合后端数据库表结构，全面重构前端 Todos 模块

---

## 📊 现状分析（重新评估）

### 后端实现（✅ 已完成且完善）

#### Rust Crates 结构
**位置**: `src-tauri/crates/todos/src/`

**Commands** (`command.rs` - 241行)
- ✅ `todo_get` - 获取单个待办
- ✅ `todo_create` - 创建待办
- ✅ `todo_update` - 更新待办
- ✅ `todo_delete` - 删除待办
- ✅ `todo_toggle` - 切换状态
- ✅ `todo_list` - 列表查询（带过滤）
- ✅ `todo_list_paged` - 分页查询

**Services** (`service/` 目录)
- ✅ `todo.rs` (40,804 bytes) - 核心待办服务
- ✅ `todo_project.rs` (6,629 bytes) - 项目关联
- ✅ `todo_tag.rs` (6,800 bytes) - 标签关联
- ✅ `todo_reminder.rs` (6,365 bytes) - 提醒服务
- ✅ `todo_task_dependency.rs` (5,524 bytes) - 任务依赖
- ✅ `projects.rs` (6,052 bytes) - 项目管理
- ✅ `tags.rs` (5,926 bytes) - 标签管理
- ✅ 各自的 hooks 文件（事件钩子）

**结论**: 后端架构完整，功能齐全！

### 前端实现（⚠️ 部分完成）

#### Schema层 ✅ 已完成
- `src/schema/todos/todos.ts` (60行) - 与后端对齐

#### 服务层 ✅ 已完成但需增强
**文件**: 
- `src/services/todos.ts` (40行) - TodoDb 类
- `src/services/todo.ts` (97行) - TodoMapper 类

**已实现功能**:
- ✅ CRUD 操作（create, get, list, update, delete, toggle）
- ✅ 分页查询（listPaged）
- ✅ 基于 BaseMapper 的标准化实现

**缺失功能** ⚠️:
- ❌ 项目关联操作（addProject, removeProject）
- ❌ 标签关联操作（addTag, removeTag）
- ❌ 子任务操作（listSubtasks, createSubtask）
- ❌ 批量操作（batchUpdate, batchDelete）

#### 状态管理 ✅ 已完成
**文件**: `src/stores/todoStore.ts` (171行)

**已实现功能**:
- ✅ useTodoStore
- ✅ 分页状态管理（todosPaged）
- ✅ 加载状态和错误处理
- ✅ CRUD 操作封装
- ✅ 自定义排序（compareTodos - 置顶、完成、优先级、截止时间）

**优点**:
- ✅ 错误处理完善（handleError, withLoading, withLoadingSafe）
- ✅ 性能优化（缓存、8小时过期）
- ✅ 使用 Map 存储（高效查找）

**缺失功能** ⚠️:
- ❌ 筛选器状态管理（filter）
- ❌ 排序选项状态管理（sortBy, sortDir）
- ❌ 计算属性（overdueTodos, todayTodos）

#### 组件层 ⚠️ 需要重构
- **已重构组件**（使用Modal + Tailwind CSS 4）:
  - TodoList.vue ✅
  - TodoView.vue ✅
  - TodoInput.vue ✅
  - TodoItem.vue ✅
  - TodoCheckbox.vue ✅
  - TodoActions.vue ✅
  - TodoTitle.vue ✅
  - TodoProgress.vue ✅
  - TodoSmartFeatures.vue ✅
  - TodoAddMenus.vue ✅

- **待重构组件** (9个):
  - TodoEstimate.vue ⚠️
  - TodoLocation.vue ⚠️
  - TodoReminderSettings.vue ⚠️
  - TodoSubtasks.vue ⚠️
  - TodoEditDueDateModal.vue ⚠️
  - TodoEditOptionsModal.vue ⚠️
  - TodoEditRepeatModal.vue ⚠️
  - TodoEditTitleModal.vue ⚠️

- **缺失组件** (2个):
  - ProjectSelector.vue ❌ (需要新建)
  - TagSelector.vue ❌ (需要新建)

---

## 🎯 重构目标（基于已有代码）

### 1. 增强服务层（TodoDb）⚠️ 优先级：高
**目标**: 补充缺失的关联操作和批量操作

- [x] CRUD 操作（已完成）✅
- [x] 分页查询（已完成）✅
- [ ] **项目关联操作** ⚠️
  - 添加 `addProject(todoId, projectId)`
  - 添加 `removeProject(todoId, projectId)`
  - 添加 `listProjects(todoId)`
- [ ] **标签关联操作** ⚠️
  - 添加 `addTag(todoId, tagId)`
  - 添加 `removeTag(todoId, tagId)`
  - 添加 `listTags(todoId)`
- [ ] **子任务操作** ⚠️
  - 添加 `listSubtasks(parentId)`
  - 添加 `createSubtask(parentId, todo)`
- [ ] **批量操作** ⚠️
  - 添加 `batchUpdate(serialNums, update)`
  - 添加 `batchDelete(serialNums)`
  - 添加 `batchToggle(serialNums, status)`

### 2. 增强状态管理（todoStore）⚠️ 优先级：高
**目标**: 添加筛选和排序状态管理

- [x] 基础 CRUD（已完成）✅
- [x] 分页管理（已完成）✅
- [x] 错误处理（已完成）✅
- [x] 自定义排序（已完成）✅
- [ ] **筛选器状态** ⚠️
  - 添加 `filter` 状态
  - 添加 `setFilter` 方法
  - 添加 `clearFilter` 方法
- [ ] **排序状态** ⚠️
  - 添加 `sortBy` 和 `sortDir` 状态
  - 添加 `setSortOptions` 方法
- [ ] **计算属性** ⚠️
  - 添加 `overdueTodos`
  - 添加 `todayTodos`
  - 添加 `upcomingTodos`
- [ ] **关联数据管理** ⚠️
  - 集成项目关联
  - 集成标签关联

### 3. 组件CSS重构 ⚠️ 优先级：中
**目标**: 统一使用 Modal + Tailwind CSS 4

- [x] 10/19 组件已重构 ✅
- [ ] **待重构组件** (9个):
  - [ ] TodoEstimate.vue
  - [ ] TodoLocation.vue
  - [ ] TodoReminderSettings.vue
  - [ ] TodoSubtasks.vue
  - [ ] TodoEditDueDateModal.vue
  - [ ] TodoEditOptionsModal.vue
  - [ ] TodoEditRepeatModal.vue
  - [ ] TodoEditTitleModal.vue

### 4. 新增组件 ❌ 优先级：中
**目标**: 实现项目/标签选择功能

- [ ] **ProjectSelector.vue** ❌
  - 项目列表显示
  - 多选支持
  - 搜索功能
- [ ] **TagSelector.vue** ❌
  - 标签列表显示
  - 多选支持
  - 搜索功能

### 5. 后端Commands补充 ❌ 优先级：低
**目标**: 确认是否需要新的 Tauri Commands

需要检查是否已有以下 commands:
- [ ] todo_project_add
- [ ] todo_project_remove
- [ ] todo_project_list
- [ ] todo_tag_add
- [ ] todo_tag_remove
- [ ] todo_tag_list
- [ ] todo_subtasks_list
- [ ] todo_subtask_create

---

## 📋 详细执行计划（修订版）

## Phase 1: 增强服务层 (优先级: 🔴 最高)

### 1.1 检查后端 Commands
**目标**: 确认关联操作的 commands 是否存在

**需要检查的文件**:
- `src-tauri/crates/todos/src/command.rs`
- 查找是否有:
  - `todo_project_*` commands
  - `todo_tag_*` commands
  - 子任务相关 commands

### 1.2 增强 TodoDb 服务
**文件**: `src/services/todos.ts`

**需要添加的方法**:
```typescript
export class TodoDb {
  // ===== 已存在 ✅ =====
  // static async createTodo(todo: TodoCreate): Promise<Todo>
  // static async getTodo(serialNum: string): Promise<Todo | null>
  // static async listTodo(): Promise<Todo[]>
  // static async updateTodo(serialNum: string, todo: TodoUpdate): Promise<Todo>
  // static async toggleTodo(serialNum: string, status: Status): Promise<Todo>
  // static async deleteTodo(serialNum: string): Promise<void>
  // static async listTodosPaged(query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>>
  
  // ===== 需要添加 ⚠️ =====
  // 项目关联
  static async addProject(todoId: string, projectId: string): Promise<void> {
    return this.todoMapper.addProject(todoId, projectId);
  }
  
  static async removeProject(todoId: string, projectId: string): Promise<void> {
    return this.todoMapper.removeProject(todoId, projectId);
  }
  
  static async listProjects(todoId: string): Promise<Project[]> {
    return this.todoMapper.listProjects(todoId);
  }
  
  // 标签关联
  static async addTag(todoId: string, tagId: string): Promise<void> {
    return this.todoMapper.addTag(todoId, tagId);
  }
  
  static async removeTag(todoId: string, tagId: string): Promise<void> {
    return this.todoMapper.removeTag(todoId, tagId);
  }
  
  static async listTags(todoId: string): Promise<Tag[]> {
    return this.todoMapper.listTags(todoId);
  }
  
  // 子任务操作
  static async listSubtasks(parentId: string): Promise<Todo[]> {
    return this.todoMapper.listSubtasks(parentId);
  }
  
  static async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
    return this.todoMapper.createSubtask(parentId, todo);
  }
}
```

### 1.3 增强 TodoMapper
**文件**: `src/services/todo.ts`

**需要添加的方法**:
```typescript
export class TodoMapper extends BaseMapper<TodoCreate, TodoUpdate, Todo> {
  // ===== 项目关联 =====
  async addProject(todoId: string, projectId: string): Promise<void> {
    try {
      await invokeCommand('todo_project_add', { todoId, projectId });
    } catch (error) {
      this.handleError('addProject', error);
    }
  }
  
  async removeProject(todoId: string, projectId: string): Promise<void> {
    try {
      await invokeCommand('todo_project_remove', { todoId, projectId });
    } catch (error) {
      this.handleError('removeProject', error);
    }
  }
  
  async listProjects(todoId: string): Promise<Project[]> {
    try {
      return await invokeCommand<Project[]>('todo_project_list', { todoId });
    } catch (error) {
      this.handleError('listProjects', error);
    }
  }
  
  // ===== 标签关联 =====
  async addTag(todoId: string, tagId: string): Promise<void> {
    try {
      await invokeCommand('todo_tag_add', { todoId, tagId });
    } catch (error) {
      this.handleError('addTag', error);
    }
  }
  
  async removeTag(todoId: string, tagId: string): Promise<void> {
    try {
      await invokeCommand('todo_tag_remove', { todoId, tagId });
    } catch (error) {
      this.handleError('removeTag', error);
    }
  }
  
  async listTags(todoId: string): Promise<Tag[]> {
    try {
      return await invokeCommand<Tag[]>('todo_tag_list', { todoId });
    } catch (error) {
      this.handleError('listTags', error);
    }
  }
  
  // ===== 子任务 =====
  async listSubtasks(parentId: string): Promise<Todo[]> {
    try {
      return await invokeCommand<Todo[]>('todo_list', { 
        filter: { parentId } 
      });
    } catch (error) {
      this.handleError('listSubtasks', error);
    }
  }
  
  async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
    try {
      return await invokeCommand<Todo>('todo_create', { 
        data: { ...todo, parentId } 
      });
    } catch (error) {
      this.handleError('createSubtask', error);
    }
  }
}
```

---

## Phase 2: 状态管理 (优先级: 🟡 高)

### 2.1 创建 useTodosStore
**文件**: `src/stores/todosStore.ts`

```typescript
import { defineStore } from 'pinia';
import { TodosDb } from '@/db/todos';
import type { Todo, TodoUpdate } from '@/schema/todos';

export const useTodosStore = defineStore('todos', () => {
  // 状态
  const todos = ref<Map<string, Todo>>(new Map());
  const filter = ref<TodoFilter>({
    status: null,
    priority: null,
    search: '',
  });
  const sortBy = ref('dueAt');
  const sortDir = ref('asc');
  
  // 计算属性
  const filteredTodos = computed(() => {
    // 应用筛选和排序逻辑
  });
  
  const overdueTodos = computed(() => {
    // 逾期任务
  });
  
  const todayTodos = computed(() => {
    // 今日任务
  });
  
  // 操作
  async function fetchTodos() {
    const list = await TodosDb.list();
    todos.value = new Map(list.map(t => [t.serialNum, t]));
  }
  
  async function createTodo(todo: TodoCreate) {
    const created = await TodosDb.create(todo);
    todos.value.set(created.serialNum, created);
  }
  
  async function updateTodo(serialNum: string, update: TodoUpdate) {
    const updated = await TodosDb.update(serialNum, update);
    todos.value.set(serialNum, updated);
  }
  
  async function deleteTodo(serialNum: string) {
    await TodosDb.delete(serialNum);
    todos.value.delete(serialNum);
  }
  
  async function toggleTodo(serialNum: string) {
    const updated = await TodosDb.toggleStatus(serialNum);
    todos.value.set(serialNum, updated);
  }
  
  return {
    todos,
    filter,
    sortBy,
    sortDir,
    filteredTodos,
    overdueTodos,
    todayTodos,
    fetchTodos,
    createTodo,
    updateTodo,
    deleteTodo,
    toggleTodo,
  };
});
```

---

## Phase 3: 组件重构 (优先级: 🟡 高)

### 3.1 TodoEstimate 重构
- [ ] 使用 Tailwind CSS 4
- [ ] 使用 Modal 组件（如果需要弹窗）
- [ ] 集成 TodosDb 服务

### 3.2 TodoLocation 重构
- [ ] 使用 Tailwind CSS 4
- [ ] 集成地图选择器
- [ ] 集成 TodosDb 服务

### 3.3 TodoReminderSettings 重构
- [ ] 使用 Tailwind CSS 4
- [ ] 使用 Modal 组件
- [ ] 完善提醒配置 UI
- [ ] 集成 TodosDb 服务

### 3.4 TodoSubtasks 重构
- [ ] 使用 Tailwind CSS 4
- [ ] 使用 Modal 组件
- [ ] 实现子任务列表
- [ ] 实现子任务创建/编辑/删除
- [ ] 集成 TodosDb 服务

### 3.5 编辑 Modal 组件重构
- [ ] TodoEditDueDateModal - 统一使用 Modal
- [ ] TodoEditOptionsModal - 统一使用 Modal
- [ ] TodoEditRepeatModal - 统一使用 Modal
- [ ] TodoEditTitleModal - 统一使用 Modal

---

## Phase 4: 项目/标签功能 (优先级: 🟢 中)

### 4.1 项目选择组件
**文件**: `src/features/todos/components/ProjectSelector.vue`

```vue
<script setup>
import { Modal } from '@/components/ui';
import { useProjectsStore } from '@/stores/projectsStore';

const projectsStore = useProjectsStore();
const selectedProjects = ref<string[]>([]);

async function addProject(projectId: string) {
  await TodosDb.addProject(props.todoId, projectId);
  emit('update');
}

async function removeProject(projectId: string) {
  await TodosDb.removeProject(props.todoId, projectId);
  emit('update');
}
</script>
```

### 4.2 标签选择组件
**文件**: `src/features/todos/components/TagSelector.vue`

类似 ProjectSelector 的实现

---

## Phase 5: 高级功能 (优先级: 🔵 低)

### 5.1 批量操作
- [ ] 批量选择
- [ ] 批量修改状态
- [ ] 批量删除
- [ ] 批量归档

### 5.2 拖拽排序
- [ ] 集成 vue-draggable
- [ ] 实现列表拖拽
- [ ] 更新 order 字段

### 5.3 提醒系统
- [ ] 后端提醒调度服务
- [ ] 前端提醒显示
- [ ] 提醒设置界面

### 5.4 智能功能
- [ ] 智能提醒算法
- [ ] 位置提醒集成
- [ ] 天气关联
- [ ] 优先级自动提升

---

## 📁 文件结构规划

```
src/
├── db/
│   └── todos.ts              ✅ TodosDb 服务
├── stores/
│   └── todosStore.ts         ✅ 状态管理
├── schema/
│   └── todos/
│       ├── todos.ts          ✅ 已存在
│       ├── filter.ts         ⚠️ 新增（筛选条件）
│       └── sort.ts           ⚠️ 新增（排序选项）
├── features/todos/
│   ├── views/
│   │   └── TodoView.vue      ✅ 已重构
│   ├── components/
│   │   ├── TodoList.vue      ✅ 已重构
│   │   ├── TodoInput.vue     ✅ 已重构
│   │   ├── TodoItem/
│   │   │   ├── TodoItem.vue           ✅ 已重构
│   │   │   ├── TodoCheckbox.vue       ✅ 已重构
│   │   │   ├── TodoActions.vue        ✅ 已重构
│   │   │   ├── TodoTitle.vue          ✅ 已重构
│   │   │   ├── TodoProgress.vue       ✅ 已重构
│   │   │   ├── TodoSmartFeatures.vue  ✅ 已重构
│   │   │   ├── TodoAddMenus.vue       ✅ 已重构
│   │   │   ├── TodoEstimate.vue       ⚠️ 待重构
│   │   │   ├── TodoLocation.vue       ⚠️ 待重构
│   │   │   ├── TodoReminderSettings.vue ⚠️ 待重构
│   │   │   ├── TodoSubtasks.vue       ⚠️ 待重构
│   │   │   ├── TodoEditDueDateModal.vue ⚠️ 待重构
│   │   │   ├── TodoEditOptionsModal.vue ⚠️ 待重构
│   │   │   ├── TodoEditRepeatModal.vue  ⚠️ 待重构
│   │   │   └── TodoEditTitleModal.vue   ⚠️ 待重构
│   │   ├── ProjectSelector.vue        ❌ 新建
│   │   └── TagSelector.vue            ❌ 新建
│   └── composables/
│       ├── useTodoActions.ts          ❌ 新建
│       ├── useTodoFilter.ts           ❌ 新建
│       └── useTodoSort.ts             ❌ 新建
└── src-tauri/
    └── crates/todos/
        └── src/
            ├── command.rs             ⚠️ 完善
            ├── service.rs             ⚠️ 完善
            └── dto.rs                 ⚠️ 完善
```

---

## 🎯 执行优先级

### P0 - 立即执行（本次）
1. ✅ 创建重构计划文档（当前）
2. ⬜ Phase 1.1 - 创建 TodosDb 服务
3. ⬜ Phase 1.2 - 创建 Tauri Commands

### P1 - 下一步
4. ⬜ Phase 2.1 - 创建 useTodosStore
5. ⬜ Phase 3.1-3.4 - 重构剩余组件

### P2 - 后续
6. ⬜ Phase 4 - 项目/标签功能
7. ⬜ Phase 5 - 高级功能

---

## 🧪 测试策略

### 单元测试
- [ ] TodosDb 服务测试
- [ ] Store 测试
- [ ] 组件测试

### 集成测试
- [ ] CRUD 流程测试
- [ ] 关联关系测试
- [ ] 子任务测试

### E2E 测试
- [ ] 完整工作流测试
- [ ] 批量操作测试

---

## 📝 注意事项

1. **向后兼容**: 保持现有功能不中断
2. **渐进式迁移**: 一次一个组件/功能
3. **性能优化**: 使用虚拟滚动、分页加载
4. **错误处理**: 完善的错误提示和重试机制
5. **数据同步**: 确保前后端数据一致性

---

## 📊 进度追踪

| Phase | 任务 | 状态 | 完成时间 |
|-------|-----|------|---------|
| P0 | 创建计划文档 | ✅ | 2025-11-28 |
| P1.1 | TodosDb 服务 | ⬜ | - |
| P1.2 | Tauri Commands | ⬜ | - |
| P2.1 | useTodosStore | ⬜ | - |
| P3.1 | TodoEstimate | ⬜ | - |
| P3.2 | TodoLocation | ⬜ | - |
| P3.3 | TodoReminderSettings | ⬜ | - |
| P3.4 | TodoSubtasks | ⬜ | - |
| P3.5 | 编辑Modal组件 | ⬜ | - |
| P4.1 | ProjectSelector | ⬜ | - |
| P4.2 | TagSelector | ⬜ | - |
| P5 | 高级功能 | ⬜ | - |

---

**最后更新**: 2025-11-28 20:23  
**总体进度**: 10/28 组件完成 (36%)
