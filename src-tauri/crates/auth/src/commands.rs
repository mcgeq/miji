use common::{
    ApiResponse, AppState,
    crud::service::CrudService,
    error::AppError,
    paginations::{PagedQuery, PagedResult},
};
use tauri::State;
use tracing::info;

use crate::{
    dto::users::{CreateUserDto, UpdateUserDto, User, UserQuery},
    services::user::{UserFilter, UserService},
};

// 创建用户
#[tauri::command]
pub async fn create_user(
    state: State<'_, AppState>,
    data: CreateUserDto,
) -> Result<ApiResponse<User>, String> {
    let service = UserService::get_user_service();
    info!("create_user role : {}", data.role);
    Ok(ApiResponse::from_result(
        service.create(&state.db, data).await.map(User::from),
    ))
}

// 获取单个用户（按 serial_num）
#[tauri::command]
pub async fn get_user(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<User>, String> {
    let service = UserService::get_user_service();
    Ok(ApiResponse::from_result(
        service
            .get_by_id(&state.db, serial_num)
            .await
            .map(User::from),
    ))
}

#[tauri::command]
pub async fn get_user_with_email(
    state: State<'_, AppState>,
    email: String,
) -> Result<ApiResponse<User>, String> {
    let service = UserService::get_user_service();
    Ok(ApiResponse::from_result(
        service
            .get_user_with_email(&state.db, email)
            .await
            .map(User::from),
    ))
}

// 更新用户
#[tauri::command]
pub async fn update_user(
    state: State<'_, AppState>,
    serial_num: String,
    data: UpdateUserDto,
) -> Result<ApiResponse<User>, String> {
    let service = UserService::get_user_service();
    Ok(ApiResponse::from_result(
        service
            .update(&state.db, serial_num, data)
            .await
            .map(User::from),
    ))
}

// 删除用户
#[tauri::command]
pub async fn delete_user(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    let service = UserService::get_user_service();
    Ok(ApiResponse::from_result(
        service.delete(&state.db, serial_num).await,
    ))
}

#[tauri::command]
pub async fn exists_user(
    state: State<'_, AppState>,
    query: UserQuery,
) -> Result<ApiResponse<bool>, String> {
    if query.serial_num.is_none()
        && query.email.is_none()
        && query.phone.is_none()
        && query.name.is_none()
    {
        return Err(
            AppError::simple(common::BusinessCode::InvalidParameter, "查询条件有误").to_string(),
        );
    }
    let service = UserService::get_user_service();
    Ok(ApiResponse::from_result(
        service.exists_user(&state.db, &query).await,
    ))
}

// 列出用户（带过滤条件）
#[tauri::command]
pub async fn list_users(
    state: State<'_, AppState>,
    filter: UserFilter,
) -> Result<ApiResponse<Vec<User>>, String> {
    let service = UserService::get_user_service();
    Ok(ApiResponse::from_result(
        service
            .list_with_filter(&state.db, filter)
            .await
            .map(|models| models.into_iter().map(User::from).collect()),
    ))
}

// 分页列出用户
#[tauri::command]
pub async fn list_users_paged(
    state: State<'_, AppState>,
    query: PagedQuery<UserFilter>,
) -> Result<ApiResponse<PagedResult<User>>, String> {
    let service = UserService::get_user_service();
    Ok(ApiResponse::from_result(
        service
            .list_paged(&state.db, query)
            .await
            .map(|paged| PagedResult {
                rows: paged.rows.into_iter().map(User::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            }),
    ))
}
