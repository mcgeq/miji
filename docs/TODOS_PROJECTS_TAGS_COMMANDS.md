# 项目和标签 Commands 实施指南

**创建时间**: 2025-11-28  
**状态**: 待实施  
**优先级**: 高

---

## 📋 概述

前端已实现从后端获取项目和标签数据的功能，但需要添加相应的 Tauri Commands。

后端服务已存在：
- ✅ `ProjectsService::project_list()` - 已实现
- ✅ `TagsService::tag_list()` - 已实现

需要添加的 Commands：
- ⚠️ `project_list` - 未暴露
- ⚠️ `project_get` - 未暴露
- ⚠️ `tag_list` - 未暴露
- ⚠️ `tag_get` - 未暴露

---

## 🎯 需要添加的 Commands

### 1. 项目 Commands

#### 1.1 project_list
**功能**: 获取所有项目列表

**文件位置**: `src-tauri/crates/todos/src/command.rs`

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn project_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<Project>>, String> {
    info!("开始获取项目列表");

    let service = ProjectsService::default();

    match service.project_list(&state.db).await {
        Ok(projects) => {
            info!(count = projects.len(), "获取项目列表成功");
            Ok(ApiResponse::from_result(Ok(
                projects.into_iter().map(Project::from).collect()
            )))
        }
        Err(e) => {
            error!(error = %e, "获取项目列表失败");
            Err(e.to_string())
        }
    }
}
```

#### 1.2 project_get
**功能**: 获取单个项目详情

```rust
#[tauri::command]
#[instrument(skip(state), fields(serial_num = %serial_num))]
pub async fn project_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Project>, String> {
    info!(serial_num = %serial_num, "开始获取项目详情");

    let service = ProjectsService::default();

    match service.project_get(&state.db, serial_num.clone()).await {
        Ok(project) => {
            info!(serial_num = %serial_num, "获取项目详情成功");
            Ok(ApiResponse::from_result(Ok(Project::from(project))))
        }
        Err(e) => {
            error!(
                error = %e,
                serial_num = %serial_num,
                "获取项目详情失败"
            );
            Err(e.to_string())
        }
    }
}
```

### 2. 标签 Commands

#### 2.1 tag_list
**功能**: 获取所有标签列表

```rust
#[tauri::command]
#[instrument(skip(state))]
pub async fn tag_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<Tag>>, String> {
    info!("开始获取标签列表");

    let service = TagsService::default();

    match service.tag_list(&state.db).await {
        Ok(tags) => {
            info!(count = tags.len(), "获取标签列表成功");
            Ok(ApiResponse::from_result(Ok(
                tags.into_iter().map(Tag::from).collect()
            )))
        }
        Err(e) => {
            error!(error = %e, "获取标签列表失败");
            Err(e.to_string())
        }
    }
}
```

#### 2.2 tag_get
**功能**: 获取单个标签详情

```rust
#[tauri::command]
#[instrument(skip(state), fields(serial_num = %serial_num))]
pub async fn tag_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Tag>, String> {
    info!(serial_num = %serial_num, "开始获取标签详情");

    let service = TagsService::default();

    match service.tag_get(&state.db, serial_num.clone()).await {
        Ok(tag) => {
            info!(serial_num = %serial_num, "获取标签详情成功");
            Ok(ApiResponse::from_result(Ok(Tag::from(tag))))
        }
        Err(e) => {
            error!(
                error = %e,
                serial_num = %serial_num,
                "获取标签详情失败"
            );
            Err(e.to_string())
        }
    }
}
```

---

## 📂 需要修改的文件

### 1. `src-tauri/crates/todos/src/command.rs`

在文件末尾添加上述 4 个 commands。

### 2. `src-tauri/crates/todos/src/lib.rs`

导出这些 commands：

```rust
pub use command::{
    // ... 现有的 exports
    project_list,
    project_get,
    tag_list,
    tag_get,
};
```

### 3. `src-tauri/src/main.rs`

在 `tauri::Builder` 的 `invoke_handler!` 中注册这些 commands：

```rust
.invoke_handler(tauri::generate_handler![
    // ... 现有的 handlers
    todos::project_list,
    todos::project_get,
    todos::tag_list,
    todos::tag_get,
])
```

---

## 🔧 前端集成状态

### ✅ 已完成
- [x] 创建 `ProjectDb` 服务 (`src/services/projects.ts`)
- [x] 创建 `TagDb` 服务 (`src/services/tags.ts`)
- [x] 更新 `ProjectSelector.vue` 使用真实数据
- [x] 更新 `TagSelector.vue` 使用真实数据
- [x] 添加加载和错误状态显示

### ⚠️ 待后端实施
- [ ] 添加后端 commands
- [ ] 注册 commands 到 Tauri
- [ ] 端到端测试

---

## 📝 DTO 类型

确保后端已有以下 DTO 定义：

### Project DTO (`dto/projects.rs`)
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Project {
    pub serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub owner_id: String,
    pub color: String,
    pub is_archived: bool,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<entity::project::Model> for Project {
    fn from(model: entity::project::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            name: model.name,
            description: model.description,
            owner_id: model.owner_id,
            color: model.color,
            is_archived: model.is_archived,
            created_at: model.created_at.to_string(),
            updated_at: model.updated_at.map(|t| t.to_string()),
        }
    }
}
```

### Tag DTO (`dto/tags.rs`)
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tag {
    pub serial_num: String,
    pub name: String,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: Option<String>,
}

impl From<entity::tag::Model> for Tag {
    fn from(model: entity::tag::Model) -> Self {
        Self {
            serial_num: model.serial_num,
            name: model.name,
            description: model.description,
            created_at: model.created_at.to_string(),
            updated_at: model.updated_at.map(|t| t.to_string()),
        }
    }
}
```

---

## ✅ 验证清单

完成后端实施后，请验证以下功能：

- [ ] `project_list` - 可以获取项目列表
- [ ] `project_get` - 可以获取单个项目
- [ ] `tag_list` - 可以获取标签列表
- [ ] `tag_get` - 可以获取单个标签
- [ ] ProjectSelector 组件正常显示项目
- [ ] TagSelector 组件正常显示标签
- [ ] 搜索功能正常工作
- [ ] 加载状态正确显示
- [ ] 错误处理正常工作
- [ ] 重新加载功能正常

---

## 🚀 后续优化

完成基础功能后，可以考虑以下优化：

1. **缓存**: 在前端添加项目和标签的缓存机制
2. **Stores**: 创建 `useProjectStore` 和 `useTagStore` 管理状态
3. **分页**: 如果数据量大，添加分页支持
4. **筛选**: 支持按归档状态、创建时间等筛选
5. **排序**: 支持按名称、创建时间排序
6. **实时更新**: 使用 WebSocket 或轮询保持数据同步

---

**最后更新**: 2025-11-28 21:00  
**文档版本**: 1.0
