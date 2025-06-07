// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           services.rs
// Description:    About Services
// Create   Date:  2025-06-05 12:09:23
// Last Modified:  2025-06-07 11:06:45
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::collections::{HashMap, HashSet};

use chrono::{Days, Local};
use common::{
    AppState,
    business_code::BusinessCode,
    entity::{
        attachment, project, reminder,
        sea_orm_active_enums::{Priority, Status},
        tag, todo, todo_project, todo_tag,
    },
    error::{MijiError, MijiResult},
    sql_error::SQLError,
    utils::{date::DateUtils, uuid::McgUuid},
};
use futures::future::join_all;
use sea_orm::{
    ActiveModelTrait, ColumnTrait, Condition, ConnectionTrait, DeleteResult, EntityTrait,
    PaginatorTrait, QueryFilter, QueryOrder, Set, TransactionTrait,
};
use tauri::State;

use crate::{
    dto::{
        CreateOrUpdateForm, PaginationParams, ProjectResponse, TagResponse, TodoFilter, TodoInput,
        TodoListResult, TodoResponse, TodoResponseBundle,
    },
    error::TodosError,
    helper::{load_response, not_found_error},
    p_set_fields, set_fields,
};

pub struct TodoService;
pub struct TagService;
pub struct ProjectService;

impl TodoService {
    pub async fn create(state: State<'_, AppState>, param: TodoInput) -> MijiResult<TodoResponse> {
        if param.title.is_none() {
            return Err(TodosError::ReqParamsFailure {
                code: BusinessCode::InvalidParameter,
                message: "Please enter a title".to_string(),
            }
            .into());
        }
        let db = &*state.db;
        let tx = db.begin().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        let todo_serial_num = McgUuid::uuid(32);
        let mut todo_active = todo::ActiveModel {
            serial_num: Set(todo_serial_num.clone()),
            title: Set(param.title.unwrap()),
            due_at: Set(DateUtils::datetime_local_fixed(param.due_at)),
            created_at: Set(DateUtils::current_datetime_local_fixed()),
            ..Default::default()
        };

        let mut _should_update = false;

        set_fields!(
            todo_active,
            param,
            _should_update,
            description: String => |v: String| Some(v),
            priority: Priority => |v: Priority| v.into(),
            status: Status => |v: Status| v.into(),
            repeat: String => |v: String| Some(v),
            progress: i8 => |v: i8| v,
            assignee_id: String => |v: String| Some(v),
            location: String => |v: String| Some(v),
            owner_id: String => |v: String| Some(v),
        );
        // 插入 Todo
        let todo: todo::Model = todo_active.insert(&tx).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        Self::handle_projects(&tx, &todo_serial_num, param.projects).await?;
        Self::handle_tags(&tx, &todo_serial_num, param.tags).await?;

        // 6. 加载 TodoResponse
        let mut responses = Self::load_todo_responses(&tx, vec![todo]).await?;

        // 7. 提交事务
        tx.commit().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        // 8. 返回 TodoResponse
        Ok(responses.pop().unwrap())
    }

    pub async fn list(
        state: State<'_, AppState>,
        param: &PaginationParams,
    ) -> MijiResult<TodoListResult> {
        let db = &*state.db;
        // 1. Fetch the base Todo models first
        let today = Local::now().date_naive();
        let yesterday = today.checked_sub_days(Days::new(1)).unwrap();
        let day_before_yesterday = today.checked_sub_days(Days::new(2)).unwrap();
        let tomorrow = today.checked_add_days(Days::new(1)).unwrap();
        let old_date = today.checked_sub_days(Days::new(3)).unwrap();
        let mut query = todo::Entity::find().order_by_asc(todo::Column::CreatedAt);

        match param.filter.as_ref().unwrap() {
            TodoFilter::ALL => {}
            TodoFilter::TODAY => {
                // 创建日期、截止日期或完成日期是 2025-05-15、2025-05-16 或 2025-05-17
                let date_range = vec![day_before_yesterday, yesterday, today];
                query = query.filter(
                    Condition::any()
                        .add(
                            todo::Column::CreatedAt.is_in(
                                date_range
                                    .clone()
                                    .into_iter()
                                    .map(|d| d.and_hms_opt(23, 59, 59)),
                            ),
                        )
                        .add(
                            todo::Column::DueAt.is_in(
                                date_range
                                    .clone()
                                    .into_iter()
                                    .map(|d| d.and_hms_opt(23, 59, 59)),
                            ),
                        )
                        .add(
                            todo::Column::CompletedAt
                                .is_in(date_range.into_iter().map(|d| d.and_hms_opt(23, 59, 59))),
                        )
                        .add(todo::Column::CompletedAt.is_null()),
                );
                query = query.filter(
                    Condition::any()
                        .add(todo::Column::DueAt.lt(tomorrow.and_hms_opt(0, 0, 0)))
                        .add(todo::Column::DueAt.is_null()),
                )
            }
            TodoFilter::YESTERDAY => {
                // 完成日期是 2025-05-14 或更早
                query = query.filter(todo::Column::CompletedAt.lte(old_date.and_hms_opt(0, 0, 0)));
            }
            TodoFilter::TOMORROW => {
                // 截止日期是 2025-05-18 或更晚
                query = query.filter(todo::Column::DueAt.gte(tomorrow.and_hms_opt(0, 0, 0)));
            }
        }
        // 🧮 总数量
        let total_items = query.clone().count(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        // 🔢 总页数
        let page_size = param.page_size.unwrap_or(10);
        let total_pages = total_items.div_ceil(page_size);

        // 📄 当前页数据（分页）
        let todos: Vec<todo::Model> = query
            .paginate(db, param.page_size.unwrap())
            .fetch_page(param.page.unwrap().saturating_sub(1))
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        let items = Self::load_todo_responses(db, todos).await?;
        Ok(TodoListResult {
            total_items,
            total_pages,
            items,
        })
    }

    pub async fn get(state: State<'_, AppState>, serial_num: String) -> MijiResult<TodoResponse> {
        let db = &*state.db;
        let todo = todo::Entity::find()
            .filter(todo::Column::SerialNum.eq(&serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(&serial_num))?;

        let mut responses = Self::load_todo_responses(db, vec![todo]).await?;
        Ok(responses.pop().unwrap())
    }

    pub async fn update(
        state: State<'_, AppState>,
        serial_num: String,
        param: TodoInput,
    ) -> MijiResult<TodoResponse> {
        let db = &*state.db;
        let tx = db.begin().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        let todo: todo::Model = todo::Entity::find()
            .filter(todo::Column::SerialNum.eq(&serial_num))
            .one(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(&serial_num))?;

        let mut t_active: todo::ActiveModel = todo.clone().into();

        let mut should_update = false;
        let mut completed_bool = false;
        set_fields!(
            t_active,
            param,
            should_update,
            title: String => |v: String| v,
            description: String => |v: String| Some(v),
            due_at: DateTime<FixedOffset> => |v| DateUtils::datetime_local_fixed(Some(v)),
            priority: Priority => |v: Priority| v.into(),
            status: Status => |v: Status| {
                if v == Status::Completed {
                    completed_bool = true;
                }
                v.into()
            },
            repeat: String => |v: String| Some(v),
            progress: i8 => |v: i8| v,
            assignee_id: String => |v: String| Some(v),
            location: String => |v: String| Some(v),
            owner_id: String => |v: String| Some(v),
        );
        if completed_bool {
            t_active.completed_at = Set(Some(DateUtils::current_datetime_local_fixed()));
            t_active.progress = Set(100);
            should_update = true;
        }

        Self::handle_projects(&tx, &serial_num, param.projects).await?;
        Self::handle_tags(&tx, &serial_num, param.tags).await?;

        // Only update if at least one field was set
        let todo = if should_update {
            t_active.updated_at = Set(Some(DateUtils::current_datetime_local_fixed()));
            t_active.update(&tx).await.map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
        } else {
            todo
        };

        let mut response = Self::load_todo_responses(&tx, vec![todo]).await?;
        tx.commit().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(response.pop().unwrap())
    }

    pub async fn delete(
        state: State<'_, AppState>,
        serial_num: String,
    ) -> MijiResult<TodoResponse> {
        let db = &*state.db;
        // 1. 开启事务
        let tx = db.begin().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        // 2. 查询 Todo
        let todo: todo::Model = todo::Entity::find()
            .filter(todo::Column::SerialNum.eq(&serial_num))
            .one(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(&serial_num))?;

        // 3. 先加载 TodoResponse，捕获所有关联数据
        let mut responses = Self::load_todo_responses(&tx, vec![todo.clone()]).await?;

        // 4. 删除 Todo
        let delete_result: DeleteResult = todo::Entity::delete_by_id(&serial_num)
            .exec(&tx)
            .await
            .map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        if delete_result.rows_affected == 0 {
            return Err(not_found_error(&serial_num).into());
        }

        // 5. 提交事务
        tx.commit().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        // 6. 返回 TodoResponse
        Ok(responses.pop().unwrap())
    }

    // 共享函数：处理 Projects
    async fn handle_projects<C: ConnectionTrait>(
        tx: &C,
        todo_serial_num: &str,
        projects: Option<Vec<CreateOrUpdateForm>>,
    ) -> MijiResult<Vec<String>> {
        let mut project_serial_nums = Vec::new();
        if let Some(pro) = projects {
            for create_project in pro {
                let project_serial_num = if let Some(serial_num) = create_project.serial_num {
                    let project_model = project::Entity::find()
                        .filter(project::Column::SerialNum.eq(&serial_num))
                        .one(tx)
                        .await
                        .map_err(|e| {
                            let sql_error: SQLError = e.into();
                            MijiError::from(sql_error)
                        })?
                        .ok_or_else(|| not_found_error(&serial_num))?;

                    if create_project.name.is_none() && create_project.description.is_none() {
                        serial_num
                    } else {
                        let mut project: project::ActiveModel = project_model.into();
                        if let Some(name) = create_project.name {
                            project.name = Set(name);
                        }
                        if let Some(description) = create_project.description {
                            project.description = Set(Some(description));
                        }
                        project.update(tx).await.map_err(|e| {
                            let sql_error: SQLError = e.into();
                            MijiError::from(sql_error)
                        })?;
                        serial_num
                    }
                } else {
                    let name = create_project
                        .name
                        .ok_or_else(|| TodosError::ReqParamsFailure {
                            code: BusinessCode::InvalidParameter,
                            message: "Project name is required".to_string(),
                        })?;
                    let project_serial_num = McgUuid::uuid(32);
                    let mut project_active = project::ActiveModel {
                        serial_num: Set(project_serial_num.clone()),
                        name: Set(name),
                        created_at: Set(DateUtils::current_datetime_local_fixed()),
                        ..Default::default()
                    };
                    if let Some(description) = create_project.description {
                        project_active.description = Set(Some(description));
                    }
                    project_active.insert(tx).await.map_err(|e| {
                        let sql_error: SQLError = e.into();
                        MijiError::from(sql_error)
                    })?;
                    project_serial_num
                };

                let todo_project_active = todo_project::ActiveModel {
                    todo_serial_num: Set(todo_serial_num.to_string()),
                    project_serial_num: Set(project_serial_num.clone()),
                    created_at: Set(DateUtils::current_datetime_local_fixed()),
                    ..Default::default()
                };
                todo_project_active.insert(tx).await.map_err(|e| {
                    let sql_error: SQLError = e.into();
                    MijiError::from(sql_error)
                })?;
                project_serial_nums.push(project_serial_num);
            }
        }
        Ok(project_serial_nums)
    }

    // 共享函数：处理 Tags
    async fn handle_tags<C: ConnectionTrait>(
        tx: &C,
        todo_serial_num: &str,
        tags: Option<Vec<CreateOrUpdateForm>>,
    ) -> MijiResult<Vec<String>> {
        let mut tag_serial_nums = Vec::new();
        if let Some(tags) = tags {
            for create_tag in tags {
                // Validate name (required)
                let name = create_tag
                    .name
                    .ok_or_else(|| TodosError::ReqParamsFailure {
                        code: BusinessCode::InvalidParameter,
                        message: "Tag name is required".to_string(),
                    })?;

                if name.is_empty() || name.len() > 100 {
                    return Err(TodosError::ReqParamsFailure {
                        code: BusinessCode::InvalidParameter,
                        message: "Tag name must be between 1 and 100 characters".to_string(),
                    }
                    .into());
                }

                // Validate description (if provided)
                if let Some(description) = &create_tag.description
                    && description.len() > 1000
                {
                    return Err(TodosError::ReqParamsFailure {
                        code: BusinessCode::InvalidParameter,
                        message: "Tag description must not exceed 1000 characters".to_string(),
                    }
                    .into());
                }

                let tag_serial_num = if let Some(serial_num) = create_tag.serial_num {
                    // Lookup by serial_num
                    let tag_model = tag::Entity::find()
                        .filter(tag::Column::SerialNum.eq(&serial_num))
                        .one(tx)
                        .await
                        .map_err(|e| {
                            let sql_error: SQLError = e.into();
                            MijiError::from(sql_error)
                        })?
                        .ok_or_else(|| not_found_error(&serial_num))?;

                    // Verify the name matches (to prevent updating a tag to a different name)
                    if tag_model.name != name {
                        return Err(TodosError::ReqParamsFailure {
                            code: BusinessCode::InvalidParameter,
                            message: "Tag name does not match the provided serial_num".to_string(),
                        }
                        .into());
                    }

                    // Update description if provided
                    if create_tag.description.is_some() {
                        let mut tag: tag::ActiveModel = tag_model.clone().into();
                        tag.description = Set(create_tag.description);
                        tag.update(tx).await.map_err(|e| {
                            let sql_error: SQLError = e.into();
                            MijiError::from(sql_error)
                        })?;
                    }

                    tag_model.serial_num
                } else {
                    // Lookup by name (since name is unique)
                    let existing_tag = tag::Entity::find()
                        .filter(tag::Column::Name.eq(&name))
                        .one(tx)
                        .await
                        .map_err(|e| {
                            let sql_error: SQLError = e.into();
                            MijiError::from(sql_error)
                        })?;

                    if let Some(tag_model) = existing_tag {
                        // Tag exists, update description if provided
                        if create_tag.description.is_some() {
                            let mut tag: tag::ActiveModel = tag_model.clone().into();
                            tag.description = Set(create_tag.description);
                            tag.update(tx).await.map_err(|e| {
                                let sql_error: SQLError = e.into();
                                MijiError::from(sql_error)
                            })?;
                        }
                        tag_model.serial_num
                    } else {
                        // Create new tag
                        let tag_serial_num = McgUuid::uuid(32);
                        let tag_active = tag::ActiveModel {
                            serial_num: Set(tag_serial_num.clone()),
                            name: Set(name),
                            description: Set(create_tag.description),
                            created_at: Set(DateUtils::current_datetime_local_fixed()),
                            ..Default::default()
                        };
                        tag_active.insert(tx).await.map_err(|e| {
                            let sql_error: SQLError = e.into();
                            MijiError::from(sql_error)
                        })?;
                        tag_serial_num
                    }
                };

                // Check if todo_tag association exists
                let existing_association = todo_tag::Entity::find()
                    .filter(todo_tag::Column::TodoSerialNum.eq(todo_serial_num))
                    .filter(todo_tag::Column::TagSerialNum.eq(&tag_serial_num))
                    .one(tx)
                    .await
                    .map_err(|e| {
                        let sql_error: SQLError = e.into();
                        MijiError::from(sql_error)
                    })?;

                if existing_association.is_none() {
                    // Create new todo_tag association
                    let todo_tag_active = todo_tag::ActiveModel {
                        todo_serial_num: Set(todo_serial_num.to_string()),
                        tag_serial_num: Set(tag_serial_num.clone()),
                        created_at: Set(DateUtils::current_datetime_local_fixed()),
                        ..Default::default()
                    };
                    todo_tag_active.insert(tx).await.map_err(|e| {
                        let sql_error: SQLError = e.into();
                        MijiError::from(sql_error)
                    })?;
                }

                tag_serial_nums.push(tag_serial_num);
            }
        }
        Ok(tag_serial_nums)
    }

    async fn load_todo_responses<C: ConnectionTrait + Send>(
        db: &C,
        todos: Vec<todo::Model>,
    ) -> MijiResult<Vec<TodoResponse>> {
        if todos.is_empty() {
            return Ok(Vec::new());
        }

        let todo_serial_nums: Vec<String> = todos.iter().map(|t| t.serial_num.clone()).collect();

        // --- 1. 查询 todo_project
        let todo_projects = todo_project::Entity::find()
            .filter(todo_project::Column::TodoSerialNum.is_in(todo_serial_nums.clone()))
            .all(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;

        let project_serial_nums: HashSet<String> = todo_projects
            .iter()
            .map(|tp| tp.project_serial_num.clone())
            .collect();

        let projects = if project_serial_nums.is_empty() {
            Vec::new()
        } else {
            project::Entity::find()
                .filter(project::Column::SerialNum.is_in(project_serial_nums))
                .all(db)
                .await
                .map_err(|e| {
                    let sql_error: SQLError = e.into();
                    MijiError::from(sql_error)
                })?
        };

        let project_map: HashMap<String, &project::Model> =
            projects.iter().map(|p| (p.serial_num.clone(), p)).collect();

        let mut todo_to_projects: HashMap<String, Vec<&project::Model>> = HashMap::new();
        for tp in &todo_projects {
            if let Some(project) = project_map.get(&tp.project_serial_num) {
                todo_to_projects
                    .entry(tp.todo_serial_num.clone())
                    .or_default()
                    .push(*project);
            }
        }

        // --- 2. 查询 reminder
        let reminders = reminder::Entity::find()
            .filter(reminder::Column::TodoSerialNum.is_in(todo_serial_nums.clone()))
            .all(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;

        let mut reminder_map: HashMap<String, Vec<reminder::Model>> = HashMap::new();
        for r in reminders {
            let key = r.todo_serial_num.clone();
            reminder_map.entry(key).or_default().push(r);
        }

        // --- 3. 查询 attachment
        let attachments = attachment::Entity::find()
            .filter(attachment::Column::TodoSerialNum.is_in(todo_serial_nums.clone()))
            .all(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;

        let mut attachment_map: HashMap<String, Vec<attachment::Model>> = HashMap::new();
        for a in attachments {
            let key = a.todo_serial_num.clone();
            attachment_map.entry(key).or_default().push(a);
        }

        // --- 4. 查询 todo_tag
        let todo_tags = todo_tag::Entity::find()
            .filter(todo_tag::Column::TodoSerialNum.is_in(todo_serial_nums.clone()))
            .all(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;

        let tag_serial_nums: HashSet<String> = todo_tags
            .iter()
            .map(|tt| tt.tag_serial_num.clone())
            .collect();

        let tags = if tag_serial_nums.is_empty() {
            Vec::new()
        } else {
            tag::Entity::find()
                .filter(tag::Column::SerialNum.is_in(tag_serial_nums))
                .all(db)
                .await
                .map_err(|e| {
                    let sql_error: SQLError = e.into();
                    MijiError::from(sql_error)
                })?
        };

        let tag_map: HashMap<String, &tag::Model> =
            tags.iter().map(|t| (t.serial_num.clone(), t)).collect();

        let mut todo_to_tags: HashMap<String, Vec<&tag::Model>> = HashMap::new();
        for tt in &todo_tags {
            if let Some(tag) = tag_map.get(&tt.tag_serial_num) {
                todo_to_tags
                    .entry(tt.todo_serial_num.clone())
                    .or_default()
                    .push(*tag);
            }
        }

        // --- 5. 最后组装
        let todo_futures = todos.into_iter().map(|todo| {
            let serial_num = todo.serial_num.clone();
            let projects = todo_to_projects.remove(&serial_num).unwrap_or_default();
            let reminders = reminder_map.remove(&serial_num).unwrap_or_default();
            let attachments = attachment_map.remove(&serial_num).unwrap_or_default();
            let tags = todo_to_tags.remove(&serial_num).unwrap_or_default();

            async move {
                load_response(vec![TodoResponseBundle {
                    todo,
                    project: projects.into_iter().cloned().collect(),
                    reminders,
                    attachments,
                    tags: tags.into_iter().cloned().collect(),
                }])
                .await
            }
        });

        let results = join_all(todo_futures).await;

        let mut todo_responses = Vec::new();
        for result in results {
            let mut inner = result?;
            todo_responses.append(&mut inner);
        }

        Ok(todo_responses)
    }
}

impl TagService {
    pub async fn list(
        state: State<'_, AppState>,
        param: &PaginationParams,
    ) -> MijiResult<Vec<TagResponse>> {
        let db = &*state.db;
        let tags: Vec<tag::Model> = tag::Entity::find()
            .order_by_desc(tag::Column::CreatedAt)
            .paginate(db, param.page_size.unwrap())
            .fetch_page(param.page.unwrap().saturating_sub(1))
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        load_response(tags).await
    }

    pub async fn get(state: State<'_, AppState>, serial_num: &str) -> MijiResult<TagResponse> {
        let db = &*state.db;
        let tag = tag::Entity::find()
            .filter(tag::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;

        let mut responses = load_response(vec![tag]).await?;
        Ok(responses.pop().unwrap())
    }

    pub async fn create(
        state: State<'_, AppState>,
        tag: &CreateOrUpdateForm,
    ) -> MijiResult<TagResponse> {
        let tag = tag::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            name: Set(tag
                .name
                .as_ref()
                .map_or("".to_string(), |s| s.as_str().to_string())),
            description: Set(tag.description.as_ref().map(|s| s.to_string())),
            created_at: Set(DateUtils::current_datetime_local_fixed()),
            ..Default::default()
        };
        let db = &*state.db;

        let tag: tag::Model = tag.insert(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        let mut response = load_response(vec![tag]).await?;

        Ok(response.pop().unwrap())
    }

    pub async fn update(
        state: State<'_, AppState>,
        serial_num: &str,
        param: &CreateOrUpdateForm,
    ) -> MijiResult<TagResponse> {
        let db = &*state.db;
        let tx = db.begin().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        let tag: tag::Model = tag::Entity::find()
            .filter(tag::Column::SerialNum.eq(serial_num))
            .one(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;

        let mut t_active: tag::ActiveModel = tag.clone().into();

        let mut should_update = false;
        p_set_fields!(
            t_active,
            param,
            should_update,
            name: String => |v| v,
            description: String => |v: String| Some(v),
        );

        let tag = if should_update {
            t_active.updated_at = Set(Some(DateUtils::current_datetime_local_fixed()));
            t_active.update(&tx).await.map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
        } else {
            tag
        };

        let mut response = load_response(vec![tag]).await?;
        tx.commit().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(response.pop().unwrap())
    }

    pub async fn delete(state: State<'_, AppState>, serial_num: &str) -> MijiResult<TagResponse> {
        let db = &*state.db;
        let tx = db.begin().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        todo_tag::Entity::delete_many()
            .filter(todo_tag::Column::TagSerialNum.eq(serial_num))
            .exec(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;

        let tag: tag::Model = tag::Entity::find()
            .filter(tag::Column::SerialNum.eq(serial_num))
            .one(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;

        tag::Entity::delete_by_id(serial_num)
            .exec(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        let mut response = load_response(vec![tag]).await?;

        tx.commit().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(response.pop().unwrap())
    }
}
impl ProjectService {
    pub async fn list(
        state: State<'_, AppState>,
        param: &PaginationParams,
    ) -> MijiResult<Vec<ProjectResponse>> {
        let db = &*state.db;
        let projects: Vec<project::Model> = project::Entity::find()
            .order_by_desc(project::Column::CreatedAt)
            .paginate(db, param.page_size.unwrap())
            .fetch_page(param.page.unwrap().saturating_sub(1))
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        load_response(projects).await
    }

    pub async fn get(state: State<'_, AppState>, serial_num: &str) -> MijiResult<ProjectResponse> {
        let db = &*state.db;
        let todo = project::Entity::find()
            .filter(project::Column::SerialNum.eq(serial_num))
            .one(db)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;

        let mut responses = load_response(vec![todo]).await?;
        Ok(responses.pop().unwrap())
    }

    pub async fn create(
        state: State<'_, AppState>,
        project: &CreateOrUpdateForm,
    ) -> MijiResult<ProjectResponse> {
        let proj = project::ActiveModel {
            serial_num: Set(McgUuid::uuid(32)),
            name: Set(project
                .name
                .as_ref()
                .map_or("".to_string(), |s| s.as_str().to_string())),
            description: Set(project.description.as_ref().map(|s| s.to_string())),
            created_at: Set(DateUtils::current_datetime_local_fixed()),
            ..Default::default()
        };

        let db = &*state.db;
        let proj: project::Model = proj.insert(db).await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        let mut response = load_response(vec![proj]).await?;

        Ok(response.pop().unwrap())
    }

    pub async fn update(
        state: State<'_, AppState>,
        serial_num: &str,
        param: &CreateOrUpdateForm,
    ) -> MijiResult<ProjectResponse> {
        let db = &*state.db;
        let tx = db.begin().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;

        let proj: project::Model = project::Entity::find()
            .filter(project::Column::SerialNum.eq(serial_num))
            .one(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;

        let mut t_active: project::ActiveModel = proj.clone().into();

        let mut should_update = false;
        p_set_fields!(
            t_active,
            param,
            should_update,
            name: String => |v| v,
            description: String => |v: String| Some(v),
        );
        let proj = if should_update {
            t_active.updated_at = Set(Some(DateUtils::current_datetime_local_fixed()));
            t_active.update(&tx).await.map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
        } else {
            proj
        };

        let mut response = load_response(vec![proj]).await?;
        tx.commit().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(response.pop().unwrap())
    }

    pub async fn delete(
        state: State<'_, AppState>,
        serial_num: &str,
    ) -> MijiResult<ProjectResponse> {
        let db = &*state.db;
        let tx = db.begin().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        let proj: Option<todo_project::Model> = todo_project::Entity::find()
            .filter(todo_project::Column::ProjectSerialNum.eq(serial_num))
            .one(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        if proj.is_some() {
            return Err(TodosError::Validation {
                code: BusinessCode::InvalidParameter,
                message: "Associated to-do tasks cannot be deleted".to_string(),
            }
            .into());
        };

        let proj: project::Model = project::Entity::find()
            .filter(project::Column::SerialNum.eq(serial_num))
            .one(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?
            .ok_or_else(|| not_found_error(serial_num))?;

        project::Entity::delete_by_id(serial_num)
            .exec(&tx)
            .await
            .map_err(|e| {
                let sql_error: SQLError = e.into();
                MijiError::from(sql_error)
            })?;
        let mut response = load_response(vec![proj]).await?;

        tx.commit().await.map_err(|e| {
            let sql_error: SQLError = e.into();
            MijiError::from(sql_error)
        })?;
        Ok(response.pop().unwrap())
    }
}
