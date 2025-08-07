// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcgeq. All rights reserved.
// Author:         mcgeq
// Email:          <mcgeq@outlook.com>
// File:           curd.rs
// Description:    About Common
// Create   Date:  2025-08-07 09:16:50
// Last Modified:  2025-08-07 18:19:12
// Modified   By:  mcgeq <mcgeq@outlook.com>
// ----------------------------------------------------------------------------

use sea_orm::{
    prelude::async_trait::async_trait, ActiveModelTrait,
    DatabaseConnection, EntityTrait, FromQueryResult,
    PaginatorTrait, QueryFilter, QuerySelect,
    PrimaryKeyTrait,
    IntoActiveModel,
};
use serde::Serialize;
use validator::{Validate};

use crate::{
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult, Sortable},
    BusinessCode,
};

#[async_trait]
pub trait CrudService<E: EntityTrait, F, C, U>
where
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
    E::Model: FromQueryResult + Serialize + Send + Sync,
    E::PrimaryKey: PrimaryKeyTrait,
    <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType: Send + Sync,
{
    async fn list(&self, db: &DatabaseConnection) -> MijiResult<Vec<E::Model>>;

    async fn list_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<F>,
    ) -> MijiResult<PagedResult<E::Model>>;

    async fn get_by_serial_num(
        &self,
        db: &DatabaseConnection,
        serial_num: <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<Option<E::Model>>;

    async fn create(&self, db: &DatabaseConnection, data: C) -> MijiResult<E::Model>;

    async fn update(
        &self,
        db: &DatabaseConnection,
        serial_num: <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model>;

    async fn delete(
        &self,
        db: &DatabaseConnection,
        serial_num: <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()>;
}

/// 通用 CRUD 实现
pub struct GenericCrudService<E, F, C, U> {
    _entity: std::marker::PhantomData<E>,
    _filter: std::marker::PhantomData<F>,
    _create: std::marker::PhantomData<C>,
    _update: std::marker::PhantomData<U>,
}

impl<E, F, C, U> GenericCrudService<E, F, C, U>
where
    E: EntityTrait,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
    E::Model: FromQueryResult + Serialize + Send + Sync,
    E::PrimaryKey: PrimaryKeyTrait,
    <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType: Send + Sync,
{
    pub fn new() -> Self {
        Self {
            _entity: std::marker::PhantomData,
            _filter: std::marker::PhantomData,
            _create: std::marker::PhantomData,
            _update: std::marker::PhantomData,
        }
    }
}

#[async_trait]
impl<E, F, C, U> CrudService<E, F, C, U> for GenericCrudService<E, F, C, U>
where
    E: EntityTrait,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
    E::Model: FromQueryResult + Serialize + Send + Sync,
    E::PrimaryKey: PrimaryKeyTrait,
    <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType: Send + Sync + 'static,
{
    async fn list(&self, db: &DatabaseConnection) -> MijiResult<Vec<E::Model>> {
        let all = E::find().all(db).await.map_err(AppError::from)?;
        Ok(all)
    }

    async fn list_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<F>,
    ) -> MijiResult<PagedResult<E::Model>> {
        // 验证查询参数
        query.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                e.to_string(),
                None,
            )
        })?;

        // 构建基础查询
        let mut query_builder = E::find();

        // 应用过滤条件
        query_builder = query_builder.filter(query.filter.to_condition());

        // 应用排序
        query_builder = query.sort_options.apply_sort(query_builder);

        // 计算总数
        let total_count = query_builder
            .clone()
            .count(db)
            .await
            .map_err(AppError::from)? as usize;

        // 计算总页数
        let total_pages = (total_count + query.page_size - 1) / query.page_size;

        // 应用分页
        let offset = (query.current_page - 1) * query.page_size;
        let rows = query_builder
            .offset(offset as u64)
            .limit(query.page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    async fn get_by_serial_num(
        &self,
        db: &DatabaseConnection,
        serial_num: <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<Option<E::Model>> {
        let entity = E::find_by_id(serial_num)
            .one(db)
            .await
            .map_err(AppError::from)?;
        Ok(entity)
    }

    async fn create(&self, db: &DatabaseConnection, data: C) -> MijiResult<E::Model> {
        // 验证数据
        data.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                e.to_string(),
                None,
            )
        })?;

        // 转换为 ActiveModel
        let active_model = self.convert_to_active_model(data);

        // 插入数据库
        let model = active_model.insert(db).await.map_err(AppError::from)?;
        Ok(model)
    }

    async fn update(
        &self,
        db: &DatabaseConnection,
        serial_num: <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model> {
        // 验证数据
        data.validate().map_err(|e| {
            AppError::simple(
                BusinessCode::ValidationError,
                e.to_string(),
            )
        })?;

        // 查找实体
        let entity = E::find_by_id(serial_num)
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    "Entity not found",
                )
            })?;

        // 转换为 ActiveModel
        let mut active_model: E::ActiveModel = entity.into_active_model();

        // 应用更新
        self.apply_update(&mut active_model, data);

        // 更新数据库
        let updated_model = active_model.update(db).await.map_err(AppError::from)?;
        Ok(updated_model)
    }

    async fn delete(
        &self,
        db: &DatabaseConnection,
        serial_num: <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        E::delete_by_id(serial_num)
            .exec(db)
            .await
            .map_err(AppError::from)?;
        Ok(())
    }
}

// 需要具体实现的方法
impl<E, F, C, U> GenericCrudService<E, F, C, U>
where
    E: EntityTrait,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
    E::Model: FromQueryResult + Serialize + Send + Sync,
    E::PrimaryKey: PrimaryKeyTrait,
    <<E as EntityTrait>::PrimaryKey as PrimaryKeyTrait>::ValueType: Send + Sync,
{
    /// 将创建数据转换为 ActiveModel
    fn convert_to_active_model(&self, _data: C) -> E::ActiveModel {
        // 需要具体实现
        unimplemented!()
    }

    /// 应用更新到 ActiveModel
    fn apply_update(&self, _active_model: &mut E::ActiveModel, _data: U) {
        // 需要具体实现
        unimplemented!()
    }
}
