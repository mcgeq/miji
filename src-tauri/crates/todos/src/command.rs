use common::{
    ApiResponse, AppState,
    crud::service::CrudService,
    paginations::{PagedQuery, PagedResult},
};
use entity::todo::Status;
use tauri::State;
use tracing::{error, info, instrument};

use crate::{
    dto::{
        projects::{ProjectCreate as ProjectCreateDto, ProjectUpdate as ProjectUpdateDto},
        tags::{TagCreate as TagCreateDto, TagUpdate as TagUpdateDto},
        todo::{Todo, TodoCreate, TodoUpdate},
        todo_project::{TodoProject, TodoProjectCreate},
        todo_tag::{TodoTag, TodoTagCreate},
    },
    service::{
        project_tags::ProjectTagsService,
        projects::ProjectsService,
        tags::TagsService,
        todo::{TodosFilter, TodosService},
        todo_project::TodoProjectsService,
        todo_tag::TodoTagsService,
    },
};

// ========================== Start ==========================
// Period Records
#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num))]
pub async fn todo_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<Todo>, String> {
    let service = TodosService::default();

    match service.todo_get(&state.db, serial_num.clone()).await {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                "获取待办事项成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "获取待办事项失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_create(
    state: State<'_, AppState>,
    data: TodoCreate,
) -> Result<ApiResponse<Todo>, String> {
    info!(
        title = %data.core.title.clone(),
        "开始创建待办事项"
    );

    let service = TodosService::default();

    match service.todo_create(&state.db, data).await {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                title = %result.title,
                "待办事项创建成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                "待办事项创建失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num))]
pub async fn todo_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: TodoUpdate,
) -> Result<ApiResponse<Todo>, String> {
    info!(
        todo_serial_num = %serial_num,
        "开始更新待办事项"
    );

    let service = TodosService::default();

    match service
        .todo_update(&state.db, serial_num.clone(), data)
        .await
    {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                title = %result.title,
                "待办事项更新成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "待办事项更新失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num))]
pub async fn todo_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_serial_num = %serial_num,
        "开始删除待办事项"
    );

    let service = TodosService::default();

    match service.todo_delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                todo_serial_num = %serial_num,
                "待办事项删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "待办事项删除失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(todo_serial_num = %serial_num, status = ?status))]
pub async fn todo_toggle(
    state: State<'_, AppState>,
    serial_num: String,
    status: Status,
) -> Result<ApiResponse<Todo>, String> {
    info!(
        todo_serial_num = %serial_num,
        status = ?status,
        "开始切换待办事项状态"
    );

    let service = TodosService::default();

    match service
        .todo_toggle(&state.db, serial_num.clone(), status)
        .await
    {
        Ok(result) => {
            info!(
                todo_serial_num = %result.serial_num,
                title = %result.title,
                "待办事项状态切换成功"
            );
            Ok(ApiResponse::from_result(Ok(Todo::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %serial_num,
                "待办事项状态切换失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_list(
    state: State<'_, AppState>,
    filter: TodosFilter,
) -> Result<ApiResponse<Vec<Todo>>, String> {
    let service = TodosService::default();

    match service.todo_list_with_filter(&state.db, filter).await {
        Ok(todos) => {
            info!(count = todos.len(), "列出待办事项成功");
            Ok(ApiResponse::from_result(Ok(todos
                .into_iter()
                .map(Todo::from)
                .collect())))
        }
        Err(e) => {
            error!(
                error = %e,
                "列出待办事项失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_list_paged(
    state: State<'_, AppState>,
    query: PagedQuery<TodosFilter>,
) -> Result<ApiResponse<PagedResult<Todo>>, String> {
    let service = TodosService::default();

    match service.todo_list_paged(&state.db, query).await {
        Ok(paged) => {
            info!(
                total_count = paged.total_count,
                current_page = paged.current_page,
                page_size = paged.page_size,
                "分页列出待办事项成功"
            );
            Ok(ApiResponse::from_result(Ok(PagedResult {
                rows: paged.rows.into_iter().map(Todo::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            })))
        }
        Err(e) => {
            error!(
                error = %e,
                "分页列出待办事项失败"
            );
            Err(e.to_string())
        }
    }
}

// ========================== Projects Commands ==========================
#[tauri::command]
#[instrument(skip(state))]
pub async fn project_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<crate::dto::projects::ProjectWithUsage>>, String> {
    info!("开始获取项目列表（带引用统计）");

    let service = ProjectsService::default();

    match service.project_list_with_usage(&state.db).await {
        Ok(projects) => {
            info!(count = projects.len(), "获取项目列表成功");
            Ok(ApiResponse::from_result(Ok(projects)))
        }
        Err(e) => {
            error!(error = %e, "获取项目列表失败");
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(serial_num = %serial_num))]
pub async fn project_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<crate::dto::projects::Project>, String> {
    info!(serial_num = %serial_num, "开始获取项目详情");

    let service = ProjectsService::default();

    match service.project_get(&state.db, serial_num.clone()).await {
        Ok(project) => {
            info!(serial_num = %serial_num, "获取项目详情成功");
            Ok(ApiResponse::from_result(Ok(project.into())))
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

#[tauri::command]
#[instrument(skip(state, data))]
pub async fn project_create(
    state: State<'_, AppState>,
    data: ProjectCreateDto,
) -> Result<ApiResponse<crate::dto::projects::Project>, String> {
    info!("开始创建项目");

    let service = ProjectsService::default();

    match service.project_create(&state.db, data).await {
        Ok(project) => {
            info!(serial_num = %project.serial_num, "创建项目成功");
            Ok(ApiResponse::from_result(Ok(project.into())))
        }
        Err(e) => {
            error!(error = %e, "创建项目失败");
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state, data), fields(serial_num = %serial_num))]
pub async fn project_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: ProjectUpdateDto,
) -> Result<ApiResponse<crate::dto::projects::Project>, String> {
    info!(serial_num = %serial_num, "开始更新项目");

    let service = ProjectsService::default();

    match service
        .project_update(&state.db, serial_num.clone(), data)
        .await
    {
        Ok(project) => {
            info!(serial_num = %serial_num, "更新项目成功");
            Ok(ApiResponse::from_result(Ok(project.into())))
        }
        Err(e) => {
            error!(error = %e, serial_num = %serial_num, "更新项目失败");
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(serial_num = %serial_num))]
pub async fn project_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(serial_num = %serial_num, "开始删除项目");

    let service = ProjectsService::default();

    match service.delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(serial_num = %serial_num, "删除项目成功");
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(error = %e, serial_num = %serial_num, "删除项目失败");
            Err(e.to_string())
        }
    }
}

// ========================== Tags Commands ==========================
#[tauri::command]
#[instrument(skip(state))]
pub async fn tag_list(
    state: State<'_, AppState>,
) -> Result<ApiResponse<Vec<crate::dto::tags::TagWithUsage>>, String> {
    info!("开始获取标签列表（带引用统计）");

    let service = TagsService::default();

    match service.tag_list_with_usage(&state.db).await {
        Ok(tags) => {
            info!(count = tags.len(), "获取标签列表成功");
            Ok(ApiResponse::from_result(Ok(tags)))
        }
        Err(e) => {
            error!(error = %e, "获取标签列表失败");
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(serial_num = %serial_num))]
pub async fn tag_get(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<crate::dto::tags::Tag>, String> {
    info!(serial_num = %serial_num, "开始获取标签详情");

    let service = TagsService::default();

    match service.tag_get(&state.db, serial_num.clone()).await {
        Ok(tag) => {
            info!(serial_num = %serial_num, "获取标签详情成功");
            Ok(ApiResponse::from_result(Ok(tag.into())))
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

#[tauri::command]
#[instrument(skip(state, data))]
pub async fn tag_create(
    state: State<'_, AppState>,
    data: TagCreateDto,
) -> Result<ApiResponse<crate::dto::tags::Tag>, String> {
    info!("开始创建标签");

    let service = TagsService::default();

    match service.tag_create(&state.db, data).await {
        Ok(tag) => {
            info!(serial_num = %tag.serial_num, "创建标签成功");
            Ok(ApiResponse::from_result(Ok(tag.into())))
        }
        Err(e) => {
            error!(error = %e, "创建标签失败");
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state, data), fields(serial_num = %serial_num))]
pub async fn tag_update(
    state: State<'_, AppState>,
    serial_num: String,
    data: TagUpdateDto,
) -> Result<ApiResponse<crate::dto::tags::Tag>, String> {
    info!(serial_num = %serial_num, "开始更新标签");

    let service = TagsService::default();

    match service
        .tag_update(&state.db, serial_num.clone(), data)
        .await
    {
        Ok(tag) => {
            info!(serial_num = %serial_num, "更新标签成功");
            Ok(ApiResponse::from_result(Ok(tag.into())))
        }
        Err(e) => {
            error!(error = %e, serial_num = %serial_num, "更新标签失败");
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(serial_num = %serial_num))]
pub async fn tag_delete(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(serial_num = %serial_num, "开始删除标签");

    let service = TagsService::default();

    match service.tag_delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(serial_num = %serial_num, "删除标签成功");
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(error = %e, serial_num = %serial_num, "删除标签失败");
            Err(e.to_string())
        }
    }
}

// ========================== Project Tags Commands ==========================
#[tauri::command]
#[instrument(skip(state))]
pub async fn project_tags_get(
    state: State<'_, AppState>,
    project_serial_num: String,
) -> Result<ApiResponse<Vec<crate::dto::tags::Tag>>, String> {
    info!(project_serial_num = %project_serial_num, "开始获取项目标签");

    let service = ProjectTagsService::default();

    match service
        .get_project_tags(&state.db, project_serial_num.clone())
        .await
    {
        Ok(tags) => {
            info!(project_serial_num = %project_serial_num, count = tags.len(), "获取项目标签成功");
            let tag_dtos: Vec<crate::dto::tags::Tag> = tags.into_iter().map(|t| t.into()).collect();
            Ok(ApiResponse::from_result(Ok(tag_dtos)))
        }
        Err(e) => {
            error!(error = %e, project_serial_num = %project_serial_num, "获取项目标签失败");
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn project_tags_update(
    state: State<'_, AppState>,
    project_serial_num: String,
    tag_serial_nums: Vec<String>,
) -> Result<ApiResponse<()>, String> {
    info!(
        project_serial_num = %project_serial_num,
        tag_count = tag_serial_nums.len(),
        "开始更新项目标签"
    );

    let service = ProjectTagsService::default();

    match service
        .update_project_tags(&state.db, project_serial_num.clone(), tag_serial_nums)
        .await
    {
        Ok(_) => {
            info!(project_serial_num = %project_serial_num, "更新项目标签成功");
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(error = %e, project_serial_num = %project_serial_num, "更新项目标签失败");
            Err(e.to_string())
        }
    }
}

// ========================== Todo Project Commands Start ==========================
/// 添加项目到待办事项
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_project_add(
    state: State<'_, AppState>,
    todo_serial_num: String,
    project_serial_num: String,
) -> Result<ApiResponse<TodoProject>, String> {
    info!(
        todo_serial_num = %todo_serial_num,
        project_serial_num = %project_serial_num,
        "开始添加项目到待办事项"
    );

    let service = TodoProjectsService::default();
    let data = TodoProjectCreate {
        todo_serial_num: todo_serial_num.clone(),
        project_serial_num: project_serial_num.clone(),
        core: crate::dto::todo_project::TodoProjectBase { order_index: None },
    };

    match service.todo_project_create(&state.db, data).await {
        Ok(result) => {
            info!(
                todo_serial_num = %todo_serial_num,
                project_serial_num = %project_serial_num,
                "添加项目成功"
            );
            Ok(ApiResponse::from_result(Ok(TodoProject::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %todo_serial_num,
                project_serial_num = %project_serial_num,
                "添加项目失败"
            );
            Err(e.to_string())
        }
    }
}

/// 移除待办事项的项目关联
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_project_remove(
    state: State<'_, AppState>,
    todo_serial_num: String,
    project_serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_serial_num = %todo_serial_num,
        project_serial_num = %project_serial_num,
        "开始移除项目关联"
    );

    let service = TodoProjectsService::default();
    let id = format!("{}:{}", todo_serial_num, project_serial_num);

    match service.todo_project_delete(&state.db, id).await {
        Ok(_) => {
            info!(
                todo_serial_num = %todo_serial_num,
                project_serial_num = %project_serial_num,
                "移除项目成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %todo_serial_num,
                project_serial_num = %project_serial_num,
                "移除项目失败"
            );
            Err(e.to_string())
        }
    }
}

/// 获取待办事项的所有项目
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_project_list(
    state: State<'_, AppState>,
    todo_serial_num: String,
) -> Result<ApiResponse<Vec<crate::dto::projects::Project>>, String> {
    info!(
        todo_serial_num = %todo_serial_num,
        "开始获取待办事项的项目列表"
    );

    let service = TodoProjectsService::default();

    // 获取所有 todo_project 关联
    match service.todo_project_list(&state.db).await {
        Ok(todo_projects) => {
            // 筛选出属于指定 todo 的项目
            let project_serial_nums: Vec<String> = todo_projects
                .iter()
                .filter(|tp| tp.todo_serial_num == todo_serial_num)
                .map(|tp| tp.project_serial_num.clone())
                .collect();

            // 获取项目详情
            let projects_service = ProjectsService::default();
            let mut projects = Vec::new();

            for project_serial_num in project_serial_nums {
                if let Ok(project) = projects_service
                    .project_get(&state.db, project_serial_num)
                    .await
                {
                    projects.push(project.into());
                }
            }

            info!(
                todo_serial_num = %todo_serial_num,
                count = projects.len(),
                "获取项目列表成功"
            );
            Ok(ApiResponse::from_result(Ok(projects)))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %todo_serial_num,
                "获取项目列表失败"
            );
            Err(e.to_string())
        }
    }
}
// ========================== Todo Project Commands End ==========================

// ========================== Todo Tag Commands Start ==========================
/// 添加标签到待办事项
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_tag_add(
    state: State<'_, AppState>,
    todo_serial_num: String,
    tag_serial_num: String,
) -> Result<ApiResponse<TodoTag>, String> {
    info!(
        todo_serial_num = %todo_serial_num,
        tag_serial_num = %tag_serial_num,
        "开始添加标签到待办事项"
    );

    let service = TodoTagsService::default();
    let data = TodoTagCreate {
        todo_serial_num: todo_serial_num.clone(),
        tag_serial_num: tag_serial_num.clone(),
        core: crate::dto::todo_tag::TodoTagBase { orders: None },
    };

    match service.todo_tag_create(&state.db, data).await {
        Ok(result) => {
            info!(
                todo_serial_num = %todo_serial_num,
                tag_serial_num = %tag_serial_num,
                "添加标签成功"
            );
            Ok(ApiResponse::from_result(Ok(TodoTag::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %todo_serial_num,
                tag_serial_num = %tag_serial_num,
                "添加标签失败"
            );
            Err(e.to_string())
        }
    }
}

/// 移除待办事项的标签关联
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_tag_remove(
    state: State<'_, AppState>,
    todo_serial_num: String,
    tag_serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        todo_serial_num = %todo_serial_num,
        tag_serial_num = %tag_serial_num,
        "开始移除标签关联"
    );

    let service = TodoTagsService::default();
    let id = format!("{}:{}", todo_serial_num, tag_serial_num);

    match service.todo_tag_delete(&state.db, id).await {
        Ok(_) => {
            info!(
                todo_serial_num = %todo_serial_num,
                tag_serial_num = %tag_serial_num,
                "移除标签成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %todo_serial_num,
                tag_serial_num = %tag_serial_num,
                "移除标签失败"
            );
            Err(e.to_string())
        }
    }
}

/// 获取待办事项的所有标签
#[tauri::command]
#[instrument(skip(state))]
pub async fn todo_tag_list(
    state: State<'_, AppState>,
    todo_serial_num: String,
) -> Result<ApiResponse<Vec<crate::dto::tags::Tag>>, String> {
    info!(
        todo_serial_num = %todo_serial_num,
        "开始获取待办事项的标签列表"
    );

    let service = TodoTagsService::default();

    // 获取所有 todo_tag 关联
    match service.todo_tag_list(&state.db).await {
        Ok(todo_tags) => {
            // 筛选出属于指定 todo 的标签
            let tag_serial_nums: Vec<String> = todo_tags
                .iter()
                .filter(|tt| tt.todo_serial_num == todo_serial_num)
                .map(|tt| tt.tag_serial_num.clone())
                .collect();

            // 获取标签详情
            let tags_service = TagsService::default();
            let mut tags = Vec::new();

            for tag_serial_num in tag_serial_nums {
                if let Ok(tag) = tags_service.tag_get(&state.db, tag_serial_num).await {
                    tags.push(tag.into());
                }
            }

            info!(
                todo_serial_num = %todo_serial_num,
                count = tags.len(),
                "获取标签列表成功"
            );
            Ok(ApiResponse::from_result(Ok(tags)))
        }
        Err(e) => {
            error!(
                error = %e,
                todo_serial_num = %todo_serial_num,
                "获取标签列表失败"
            );
            Err(e.to_string())
        }
    }
}
// ========================== Todo Tag Commands End ==========================
