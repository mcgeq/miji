use common::{
    ApiResponse, AppState,
    crud::service::CrudService,
    error::AppError,
    paginations::{PagedQuery, PagedResult},
};
use tauri::State;
use tracing::{info, warn, error, instrument};

use crate::{
    dto::users::{CreateUserDto, UpdateUserDto, User, UserQuery},
    services::user::{UserFilter, UserService},
};

// 创建用户
#[tauri::command]
#[instrument(skip(state))]
pub async fn create_user(
    state: State<'_, AppState>,
    data: CreateUserDto,
) -> Result<ApiResponse<User>, String> {
    info!(
        email = %data.email.clone(),
        role = %data.role,
        "开始创建用户"
    );
    
    let service = UserService::get_user_service();
    
    match service.create(&state.db, data.clone()).await {
        Ok(result) => {
            info!(
                user_serial_num = %result.serial_num,
                email = %result.email,
                role = %data.role,
                "用户创建成功"
            );
            Ok(ApiResponse::from_result(Ok(User::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                email = %data.email,
                role = %data.role,
                "用户创建失败"
            );
            Err(e.to_string())
        }
    }
}

// 获取单个用户（按 serial_num）
#[tauri::command]
#[instrument(skip(state), fields(user_serial_num = %serial_num))]
pub async fn get_user(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<User>, String> {
    let service = UserService::get_user_service();
    
    match service.get_by_id(&state.db, serial_num.clone()).await {
        Ok(result) => {
            info!(
                user_serial_num = %result.serial_num,
                email = %result.email,
                "获取用户成功"
            );
            Ok(ApiResponse::from_result(Ok(User::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                user_serial_num = %serial_num,
                "获取用户失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state), fields(email = %email))]
pub async fn get_user_with_email(
    state: State<'_, AppState>,
    email: String,
) -> Result<ApiResponse<User>, String> {
    let service = UserService::get_user_service();
    
    match service.get_user_with_email(&state.db, email.clone()).await {
        Ok(result) => {
            info!(
                user_serial_num = %result.serial_num,
                email = %result.email,
                "通过邮箱获取用户成功"
            );
            Ok(ApiResponse::from_result(Ok(User::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                email = %email,
                "获取用户失败"
            );
            Err(e.to_string())
        }
    }
}

// 更新用户
#[tauri::command]
#[instrument(skip(state), fields(user_serial_num = %serial_num))]
pub async fn update_user(
    state: State<'_, AppState>,
    serial_num: String,
    data: UpdateUserDto,
) -> Result<ApiResponse<User>, String> {
    info!(
        user_serial_num = %serial_num,
        "开始更新用户"
    );
    
    let service = UserService::get_user_service();
    
    match service.update(&state.db, serial_num.clone(), data).await {
        Ok(result) => {
            info!(
                user_serial_num = %result.serial_num,
                email = %result.email,
                "用户更新成功"
            );
            Ok(ApiResponse::from_result(Ok(User::from(result))))
        }
        Err(e) => {
            error!(
                error = %e,
                user_serial_num = %serial_num,
                "用户更新失败"
            );
            Err(e.to_string())
        }
    }
}

// 删除用户
#[tauri::command]
#[instrument(skip(state), fields(user_serial_num = %serial_num))]
pub async fn delete_user(
    state: State<'_, AppState>,
    serial_num: String,
) -> Result<ApiResponse<()>, String> {
    info!(
        user_serial_num = %serial_num,
        "开始删除用户"
    );
    
    let service = UserService::get_user_service();
    
    match service.delete(&state.db, serial_num.clone()).await {
        Ok(_) => {
            info!(
                user_serial_num = %serial_num,
                "用户删除成功"
            );
            Ok(ApiResponse::from_result(Ok(())))
        }
        Err(e) => {
            error!(
                error = %e,
                user_serial_num = %serial_num,
                "用户删除失败"
            );
            Err(e.to_string())
        }
    }
}

#[tauri::command]
#[instrument(skip(state))]
pub async fn exists_user(
    state: State<'_, AppState>,
    query: UserQuery,
) -> Result<ApiResponse<bool>, String> {
    if query.serial_num.is_none()
        && query.email.is_none()
        && query.phone.is_none()
        && query.name.is_none()
    {
        warn!("查询用户存在性：查询条件有误");
        return Err(
            AppError::simple(common::BusinessCode::InvalidParameter, "查询条件有误").to_string(),
        );
    }
    
    let service = UserService::get_user_service();
    
    match service.exists_user(&state.db, &query).await {
        Ok(exists) => {
            info!(
                exists = exists,
                "检查用户存在性成功"
            );
            Ok(ApiResponse::from_result(Ok(exists)))
        }
        Err(e) => {
            error!(
                error = %e,
                "检查用户存在性失败"
            );
            Err(e.to_string())
        }
    }
}

// 列出用户（带过滤条件）
#[tauri::command]
#[instrument(skip(state))]
pub async fn list_users(
    state: State<'_, AppState>,
    filter: UserFilter,
) -> Result<ApiResponse<Vec<User>>, String> {
    let service = UserService::get_user_service();
    
    match service.list_with_filter(&state.db, filter).await {
        Ok(users) => {
            info!(
                count = users.len(),
                "列出用户成功"
            );
            Ok(ApiResponse::from_result(Ok(users.into_iter().map(User::from).collect())))
        }
        Err(e) => {
            error!(
                error = %e,
                "列出用户失败"
            );
            Err(e.to_string())
        }
    }
}

// 分页列出用户
#[tauri::command]
#[instrument(skip(state))]
pub async fn list_users_paged(
    state: State<'_, AppState>,
    query: PagedQuery<UserFilter>,
) -> Result<ApiResponse<PagedResult<User>>, String> {
    let service = UserService::get_user_service();
    
    match service.list_paged(&state.db, query).await {
        Ok(paged) => {
            info!(
                total_count = paged.total_count,
                current_page = paged.current_page,
                page_size = paged.page_size,
                "分页列出用户成功"
            );
            Ok(ApiResponse::from_result(Ok(PagedResult {
                rows: paged.rows.into_iter().map(User::from).collect(),
                total_count: paged.total_count,
                current_page: paged.current_page,
                page_size: paged.page_size,
                total_pages: paged.total_pages,
            })))
        }
        Err(e) => {
            error!(
                error = %e,
                "分页列出用户失败"
            );
            Err(e.to_string())
        }
    }
}
