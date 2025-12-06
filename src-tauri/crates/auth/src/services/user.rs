use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    log::logger::OperationLogger,
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use sea_orm::{
    ActiveValue::Set, ColumnTrait, Condition, DatabaseConnection, EntityTrait, QueryFilter,
    prelude::async_trait::async_trait, sea_query::IntoCondition,
};
use validator::Validate;

use crate::{
    dto::users::{CreateUserDto, UpdateUserDto, UserQuery, UserSearchQuery},
    services::user_hooks::UserHooks,
};

#[derive(Debug)]
pub struct UserConverter;

#[derive(Debug, Validate)]
pub struct UserFilter {
    pub name: Option<String>,
    pub email: Option<String>,
    pub status: Option<String>,
    pub role: Option<String>,
}

pub struct UserService {
    inner: GenericCrudService<
        entity::users::Entity,
        UserFilter,
        CreateUserDto,
        UpdateUserDto,
        UserConverter,
        UserHooks,
    >,
}

impl Filter<entity::users::Entity> for UserFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();
        if let Some(name) = &self.name {
            condition = condition.add(entity::users::Column::Name.eq(name));
        }
        if let Some(email) = &self.email {
            condition = condition.add(entity::users::Column::Email.eq(email));
        }
        if let Some(status) = &self.status {
            condition = condition.add(entity::users::Column::Status.eq(status));
        }
        if let Some(role) = &self.role {
            condition = condition.add(entity::users::Column::Role.eq(role));
        }
        condition
    }
}

impl CrudConverter<entity::users::Entity, CreateUserDto, UpdateUserDto> for UserConverter {
    fn create_to_active_model(
        &self,
        data: CreateUserDto,
    ) -> MijiResult<entity::users::ActiveModel> {
        entity::users::ActiveModel::try_from(data)
    }

    fn update_to_active_model(
        &self,
        model: entity::users::Model,
        data: UpdateUserDto,
    ) -> MijiResult<entity::users::ActiveModel> {
        let mut active_model = entity::users::ActiveModel::try_from(data)?;
        active_model.serial_num = Set(model.serial_num.clone());
        active_model.created_at = Set(model.created_at);
        active_model.updated_at = Set(Some(DateUtils::local_now()));
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::users::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "users"
    }
}

impl Default for UserService {
    fn default() -> Self {
        Self::new(Arc::new(common::log::logger::NoopLogger))
    }
}

impl UserService {
    pub fn new(logger: Arc<dyn OperationLogger>) -> Self {
        Self {
            inner: GenericCrudService::new(UserConverter, UserHooks, logger),
        }
    }
}

// 实现 CrudService 特性
#[async_trait]
impl CrudService<entity::users::Entity, UserFilter, CreateUserDto, UpdateUserDto> for UserService {
    async fn create(
        &self,
        db: &DatabaseConnection,
        data: CreateUserDto,
    ) -> MijiResult<entity::users::Model> {
        self.inner.create(db, data).await
    }

    async fn get_by_id(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<entity::users::Model> {
        self.inner.get_by_id(db, id).await
    }

    async fn update(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
        data: UpdateUserDto,
    ) -> MijiResult<entity::users::Model> {
        self.inner.update(db, serial_num, data).await
    }

    async fn delete(&self, db: &DatabaseConnection, serial_num: String) -> MijiResult<()> {
        self.inner.delete(db, serial_num).await
    }

    async fn list(&self, db: &DatabaseConnection) -> MijiResult<Vec<entity::users::Model>> {
        self.inner.list(db).await
    }

    async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: UserFilter,
    ) -> MijiResult<Vec<entity::users::Model>> {
        self.inner.list_with_filter(db, filter).await
    }

    async fn list_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<UserFilter>,
    ) -> MijiResult<PagedResult<entity::users::Model>> {
        self.inner.list_paged(db, query).await
    }

    async fn create_batch(
        &self,
        db: &DatabaseConnection,
        data: Vec<CreateUserDto>,
    ) -> MijiResult<Vec<entity::users::Model>> {
        self.inner.create_batch(db, data).await
    }

    async fn delete_batch(&self, db: &DatabaseConnection, ids: Vec<String>) -> MijiResult<u64> {
        self.inner.delete_batch(db, ids).await
    }

    async fn exists(&self, db: &DatabaseConnection, id: String) -> MijiResult<bool> {
        self.inner.exists(db, id).await
    }

    async fn count(&self, db: &DatabaseConnection) -> MijiResult<u64> {
        self.inner.count(db).await
    }

    async fn count_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: UserFilter,
    ) -> MijiResult<u64> {
        self.inner.count_with_filter(db, filter).await
    }
}

impl UserService {
    pub async fn exists_user(
        &self,
        db: &DatabaseConnection,
        query: &UserQuery,
    ) -> MijiResult<bool> {
        use entity::users::Entity as UserEntity;
        let mut conditions = Condition::all();

        if let Some(serial_num) = &query.serial_num {
            conditions = conditions.add(entity::users::Column::SerialNum.eq(serial_num));
        }
        if let Some(email) = &query.email {
            conditions = conditions.add(entity::users::Column::Email.eq(email));
        }
        if let Some(phone) = &query.phone {
            conditions = conditions.add(entity::users::Column::Phone.eq(phone));
        }
        if let Some(name) = &query.name {
            conditions = conditions.add(entity::users::Column::Name.eq(name));
        }
        if conditions.is_empty() {
            return Ok(false);
        }
        let exists = UserEntity::find()
            .filter(conditions.into_condition())
            .one(db)
            .await?
            .is_some();
        Ok(exists)
    }

    pub async fn get_user_with_email(
        &self,
        db: &DatabaseConnection,
        email: String,
    ) -> MijiResult<entity::users::Model> {
        entity::users::Entity::find()
            .filter(entity::users::Column::Email.eq(email))
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| {
                AppError::simple(
                    common::BusinessCode::NotFound,
                    "User with given email not found",
                )
            })
    }

    pub async fn get_user_password(
        &self,
        db: &DatabaseConnection,
        serial_num: String,
    ) -> MijiResult<String> {
        let model = self.get_by_id(db, serial_num).await?;
        Ok(model.password)
    }

    /// 搜索用户
    pub async fn search_users(
        &self,
        db: &DatabaseConnection,
        query: UserSearchQuery,
        limit: Option<u32>,
    ) -> MijiResult<Vec<entity::users::Model>> {
        use entity::users::Entity as UserEntity;
        use sea_orm::{QueryOrder, QuerySelect};

        let mut conditions = Condition::all();

        // 添加基础过滤条件 - 排除已删除用户
        conditions = conditions.add(entity::users::Column::DeletedAt.is_null());

        // 关键词搜索 - 支持姓名或邮箱模糊匹配
        if let Some(keyword) = &query.keyword {
            if !keyword.trim().is_empty() {
                let keyword_condition = Condition::any()
                    .add(entity::users::Column::Name.contains(keyword.trim()))
                    .add(entity::users::Column::Email.contains(keyword.trim()));
                conditions = conditions.add(keyword_condition);
            }
        }

        // 精确姓名搜索
        if let Some(name) = &query.name {
            if !name.trim().is_empty() {
                conditions = conditions.add(entity::users::Column::Name.contains(name.trim()));
            }
        }

        // 精确邮箱搜索
        if let Some(email) = &query.email {
            if !email.trim().is_empty() {
                conditions = conditions.add(entity::users::Column::Email.contains(email.trim()));
            }
        }

        // 状态过滤
        if let Some(status) = &query.status {
            conditions = conditions.add(entity::users::Column::Status.eq(status));
        }

        // 角色过滤
        if let Some(role) = &query.role {
            conditions = conditions.add(entity::users::Column::Role.eq(role));
        }

        let mut query_builder = UserEntity::find()
            .filter(conditions)
            .order_by_desc(entity::users::Column::LastActiveAt)
            .order_by_desc(entity::users::Column::CreatedAt);

        // 应用限制
        if let Some(limit) = limit {
            query_builder = query_builder.limit(limit as u64);
        }

        query_builder.all(db).await.map_err(AppError::from)
    }

    /// 获取最近活跃的用户
    pub async fn list_recent_users(
        &self,
        db: &DatabaseConnection,
        limit: Option<u32>,
        days_back: Option<u32>,
    ) -> MijiResult<Vec<entity::users::Model>> {
        use chrono::{Duration, Utc};
        use entity::users::Entity as UserEntity;
        use sea_orm::{QueryOrder, QuerySelect};

        let limit = limit.unwrap_or(10);
        let days = days_back.unwrap_or(30);

        // 计算日期范围
        let cutoff_date = Utc::now() - Duration::days(days as i64);

        UserEntity::find()
            .filter(entity::users::Column::DeletedAt.is_null())
            .filter(
                entity::users::Column::LastActiveAt.gte(
                    cutoff_date.with_timezone(&chrono::FixedOffset::east_opt(8 * 3600).unwrap()),
                ),
            )
            .order_by_desc(entity::users::Column::LastActiveAt)
            .limit(limit as u64)
            .all(db)
            .await
            .map_err(AppError::from)
    }
}
