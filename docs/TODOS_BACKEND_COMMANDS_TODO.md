# Todos 后端 Commands 实施指南

**创建时间**: 2025-11-28  
**状态**: 待实施  
**优先级**: 中

---

## 📋 概述

目前后端已有完整的服务层实现（`todo_project.rs`, `todo_tag.rs`），但缺少对应的 Tauri Commands。需要添加以下 commands 以支持前端的项目/标签关联功能。

---

## 🎯 需要添加的 Commands

### 1. 项目关联 Commands

#### 1.1 todo_project_add
**功能**: 将待办任务关联到项目

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_project_add(
    state: State<'_, AppState>,
    todo_id: String,
    project_id: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_id = %todo_id,
        project_id = %project_id,
        "开始添加待办项目关联"
    );

    let service = TodoProjectsService::default();
    let data = TodoProjectCreate {
        todo_serial_num: todo_id.clone(),
        project_serial_num: project_id.clone(),
        order_index: None,
    };

    match service.todo_project_create(&state.db, data).await {
        Ok(_) => {
            info!(
                todo_id = %todo_id,
                project_id = %project_id,
                "待办项目关联成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_id = %todo_id,
                project_id = %project_id,
                "待办项目关联失败"
            );
            Err(e.to_string())
        }
    }
}
```

#### 1.2 todo_project_remove
**功能**: 移除待办任务与项目的关联

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_project_remove(
    state: State<'_, AppState>,
    todo_id: String,
    project_id: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_id = %todo_id,
        project_id = %project_id,
        "开始移除待办项目关联"
    );

    let service = TodoProjectsService::default();
    let id = format!("{}:{}", todo_id, project_id);

    match service.todo_project_delete(&state.db, id).await {
        Ok(_) => {
            info!(
                todo_id = %todo_id,
                project_id = %project_id,
                "待办项目关联移除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_id = %todo_id,
                project_id = %project_id,
                "待办项目关联移除失败"
            );
            Err(e.to_string())
        }
    }
}
```

#### 1.3 todo_project_list
**功能**: 获取待办任务关联的所有项目

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_project_list(
    state: State<'_, AppState>,
    todo_id: String,
) -> Result<ApiResponse<Vec<TodoProject>>, String> {
    info!(
        todo_id = %todo_id,
        "开始获取待办关联的项目列表"
    );

    let service = TodoProjectsService::default();
    let filter = TodoProjectFilter {
        todo_serial_num: Some(todo_id.clone()),
        ..Default::default()
    };

    match service.todo_project_list_with_filter(&state.db, filter).await {
        Ok(relations) => {
            info!(
                todo_id = %todo_id,
                count = relations.len(),
                "获取待办项目列表成功"
            );
            Ok(ApiResponse::from_result(Ok(
                relations.into_iter().map(TodoProject::from).collect()
            )))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_id = %todo_id,
                "获取待办项目列表失败"
            );
            Err(e.to_string())
        }
    }
}
```

### 2. 标签关联 Commands

#### 2.1 todo_tag_add
**功能**: 将待办任务关联到标签

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_tag_add(
    state: State<'_, AppState>,
    todo_id: String,
    tag_id: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_id = %todo_id,
        tag_id = %tag_id,
        "开始添加待办标签关联"
    );

    let service = TodoTagsService::default();
    let data = TodoTagCreate {
        todo_serial_num: todo_id.clone(),
        tag_serial_num: tag_id.clone(),
        orders: None,
    };

    match service.todo_tag_create(&state.db, data).await {
        Ok(_) => {
            info!(
                todo_id = %todo_id,
                tag_id = %tag_id,
                "待办标签关联成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_id = %todo_id,
                tag_id = %tag_id,
                "待办标签关联失败"
            );
            Err(e.to_string())
        }
    }
}
```

#### 2.2 todo_tag_remove
**功能**: 移除待办任务与标签的关联

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_tag_remove(
    state: State<'_, AppState>,
    todo_id: String,
    tag_id: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_id = %todo_id,
        tag_id = %tag_id,
        "开始移除待办标签关联"
    );

    let service = TodoTagsService::default();
    let id = format!("{}:{}", todo_id, tag_id);

    match service.todo_tag_delete(&state.db, id).await {
        Ok(_) => {
            info!(
                todo_id = %todo_id,
                tag_id = %tag_id,
                "待办标签关联移除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_id = %todo_id,
                tag_id = %tag_id,
                "待办标签关联移除失败"
            );
            Err(e.to_string())
        }
    }
}
```

#### 2.3 todo_tag_list
**功能**: 获取待办任务关联的所有标签

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_tag_list(
    state: State<'_, AppState>,
    todo_id: String,
) -> Result<ApiResponse<Vec<TodoTag>>, String> {
    info!(
        todo_id = %todo_id,
        "开始获取待办关联的标签列表"
    );

    let service = TodoTagsService::default();
    let filter = TodoTagFilter {
        todo_serial_num: Some(todo_id.clone()),
        ..Default::default()
    };

    match service.todo_tag_list_with_filter(&state.db, filter).await {
        Ok(relations) => {
            info!(
                todo_id = %todo_id,
                count = relations.len(),
                "获取待办标签列表成功"
            );
            Ok(ApiResponse::from_result(Ok(
                relations.into_iter().map(TodoTag::from).collect()
            )))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_id = %todo_id,
                "获取待办标签列表失败"
            );
            Err(e.to_string())
        }
    }
}
```

---

## 📂 需要修改的文件

### 1. `src-tauri/crates/todos/src/command.rs`

在文件末尾添加上述 6 个 commands。

### 2. `src-tauri/crates/todos/src/lib.rs`

确保导出这些 commands：

```rust
pub use command::{
    // ... 现有的 exports
    todo_project_add,
    todo_project_remove,
    todo_project_list,
    todo_tag_add,
    todo_tag_remove,
    todo_tag_list,
};
```

### 3. `src-tauri/src/main.rs`

在 `tauri::Builder` 的 `invoke_handler!` 中注册这些 commands：

```rust
.invoke_handler(tauri::generate_handler![
    // ... 现有的 handlers
    todos::todo_project_add,
    todos::todo_project_remove,
    todos::todo_project_list,
    todos::todo_tag_add,
    todos::todo_tag_remove,
    todos::todo_tag_list,
])
```

---

## 🔧 前端集成

添加完后端 commands 后，需要更新前端服务层。

### 更新 `src/services/todo.ts` - TodoMapper 类

在 `TodoMapper` 类中添加这些方法的实现（移除注释）：

```typescript
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

async listProjects(todoId: string): Promise<Projects[]> {
  try {
    return await invokeCommand<Projects[]>('todo_project_list', { todoId });
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

async listTags(todoId: string): Promise<Tags[]> {
  try {
    return await invokeCommand<Tags[]>('todo_tag_list', { todoId });
  } catch (error) {
    this.handleError('listTags', error);
  }
}
```

### 更新 `src/services/todos.ts` - TodoDb 类

取消注释相关方法的实现。

---

## ✅ 验证清单

完成后端实施后，请验证以下功能：

- [ ] `todo_project_add` - 可以成功添加项目关联
- [ ] `todo_project_remove` - 可以成功移除项目关联
- [ ] `todo_project_list` - 可以正确获取项目列表
- [ ] `todo_tag_add` - 可以成功添加标签关联
- [ ] `todo_tag_remove` - 可以成功移除标签关联
- [ ] `todo_tag_list` - 可以正确获取标签列表
- [ ] 前端 ProjectSelector 组件可以正常工作
- [ ] 前端 TagSelector 组件可以正常工作
- [ ] 关联数据可以持久化到数据库
- [ ] 错误处理正常工作

---

## 📝 注意事项

1. **DTO 类型**: 确保 `TodoProjectCreate`, `TodoTagCreate` 等 DTO 类型已经在 `dto/todo_project.rs` 和 `dto/todo_tag.rs` 中定义。

2. **过滤器**: `TodoProjectFilter` 和 `TodoTagFilter` 需要支持按 `todo_serial_num` 筛选。

3. **复合主键**: `todo_project` 和 `todo_tag` 表使用复合主键 `(todo_serial_num, project_serial_num/tag_serial_num)`，ID 格式为 `"todo_id:project_id"`.

4. **错误处理**: 添加适当的错误处理，特别是重复关联和找不到记录的情况。

5. **事务**: 考虑在批量操作时使用数据库事务。

---

## 🚀 后续优化

完成基础功能后，可以考虑以下优化：

1. **批量操作**: 添加 `todo_project_add_batch`, `todo_tag_add_batch` 等批量操作 commands。
2. **排序**: 支持项目和标签的排序（使用 `order_index` 和 `orders` 字段）。
3. **统计**: 添加获取项目/标签使用统计的 commands。
4. **验证**: 添加更严格的输入验证和权限检查。

---

**最后更新**: 2025-11-28 20:50  
**文档版本**: 1.0
