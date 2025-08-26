use std::sync::Arc;

use common::{
    crud::service::{CrudConverter, CrudService, GenericCrudService},
    error::{AppError, MijiResult},
    log::logger::{NoopLogger, OperationLogger},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use sea_orm::{
    ActiveValue::Set, ColumnTrait, Condition, DatabaseConnection, EntityTrait, QueryFilter,
    prelude::async_trait::async_trait, sea_query::IntoCondition,
};
use tracing::info;
use validator::Validate;

use crate::{
    dto::users::{CreateUserDto, UpdateUserDto, UserQuery},
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
        active_model.created_at = Set(model.created_at.clone());
        active_model.updated_at = Set(Some(DateUtils::local_rfc3339()));
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::users::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "users"
    }
}

impl UserService {
    pub fn get_user_service() -> Self {
        Self {
            inner: GenericCrudService::new(
                UserConverter,
                UserHooks,
                Arc::new(NoopLogger), // 默认使用 NoopLogger
            ),
        }
    }

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
        info!("{}", &query.email.clone().unwrap());
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
}
