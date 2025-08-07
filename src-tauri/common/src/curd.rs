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
    ActiveModelTrait, ColumnTrait, DatabaseConnection, EntityTrait, FromQueryResult,
    IntoActiveModel, PaginatorTrait, PrimaryKeyTrait, QueryFilter, QuerySelect,
    prelude::async_trait::async_trait,
};
use serde::Serialize;
use std::str::FromStr;
use validator::Validate;

use crate::{
    BusinessCode,
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult, Sortable},
};

/// 重构后的 CRUD 服务 trait
#[async_trait]
pub trait CrudService<E, F, C, U>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
{
    // 基础 CRUD 操作
    async fn create(&self, db: &DatabaseConnection, data: C) -> MijiResult<E::Model>;
    async fn get_by_id(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<E::Model>;
    async fn update(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model>;
    async fn delete(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()>;

    // 查询操作
    async fn list(&self, db: &DatabaseConnection) -> MijiResult<Vec<E::Model>>;
    async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: F,
    ) -> MijiResult<Vec<E::Model>>;
    async fn list_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<F>,
    ) -> MijiResult<PagedResult<E::Model>>;

    // 批量操作
    async fn create_batch(
        &self,
        db: &DatabaseConnection,
        data: Vec<C>,
    ) -> MijiResult<Vec<E::Model>>;
    async fn delete_batch(
        &self,
        db: &DatabaseConnection,
        ids: Vec<<E::PrimaryKey as PrimaryKeyTrait>::ValueType>,
    ) -> MijiResult<u64>;

    // 存在性检查
    async fn exists(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<bool>;
    async fn count(&self, db: &DatabaseConnection) -> MijiResult<u64>;
    async fn count_with_filter(&self, db: &DatabaseConnection, filter: F) -> MijiResult<u64>;

    // 可选的钩子方法
    async fn before_create(&self, _data: &C) -> MijiResult<()> {
        Ok(())
    }
    async fn after_create(&self, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_update(&self, _model: &E::Model, _data: &U) -> MijiResult<()> {
        Ok(())
    }
    async fn after_update(&self, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn before_delete(&self, _model: &E::Model) -> MijiResult<()> {
        Ok(())
    }
    async fn after_delete(
        &self,
        _id: &<E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        Ok(())
    }
}

/// 转换器 trait - 分离数据转换逻辑
pub trait CrudConverter<E, C, U>
where
    E: EntityTrait,
    E::ActiveModel: ActiveModelTrait<Entity = E>,
{
    /// 将创建数据转换为 ActiveModel
    fn create_to_active_model(&self, data: C) -> MijiResult<E::ActiveModel>;

    /// 将更新数据应用到现有 ActiveModel
    fn update_to_active_model(&self, model: E::Model, data: U) -> MijiResult<E::ActiveModel>;
}

/// 通用 CRUD 服务实现
pub struct GenericCrudService<E, F, C, U, Conv> {
    converter: Conv,
    _phantom: std::marker::PhantomData<(E, F, C, U)>,
}

impl<E, F, C, U, Conv> GenericCrudService<E, F, C, U, Conv>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
    Conv: CrudConverter<E, C, U>,
{
    pub fn new(converter: Conv) -> Self {
        Self {
            converter,
            _phantom: std::marker::PhantomData,
        }
    }

    /// 获取转换器的引用
    pub fn converter(&self) -> &Conv {
        &self.converter
    }
}

#[async_trait]
impl<E, F, C, U, Conv> CrudService<E, F, C, U> for GenericCrudService<E, F, C, U, Conv>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone + IntoActiveModel<E::ActiveModel>,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static + PartialEq,
    E::Column: ColumnTrait + FromStr,
    F: Filter<E> + Send + Sync + Validate,
    C: Validate + Send + Sync + Clone,
    U: Validate + Send + Sync,
    Conv: CrudConverter<E, C, U> + Send + Sync,
{
    async fn create(&self, db: &DatabaseConnection, data: C) -> MijiResult<E::Model> {
        // 验证数据
        self.validate_data(&data)?;

        // 前置钩子
        self.before_create(&data).await?;

        // 转换为 ActiveModel
        let active_model = self.converter.create_to_active_model(data)?;

        // 插入数据库
        let model = active_model.insert(db).await.map_err(AppError::from)?;

        // 后置钩子
        self.after_create(&model).await?;

        Ok(model)
    }

    async fn get_by_id(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<E::Model> {
        E::find_by_id(id)
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Entity not found"))
    }

    async fn update(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model> {
        // 验证数据
        self.validate_update_data(&data)?;

        // 查找现有实体
        let existing_model = self.get_by_id(db, id).await?;

        // 前置钩子
        self.before_update(&existing_model, &data).await?;

        // 转换为 ActiveModel
        let active_model = self
            .converter
            .update_to_active_model(existing_model, data)?;

        // 更新数据库
        let updated_model = active_model.update(db).await.map_err(AppError::from)?;

        // 后置钩子
        self.after_update(&updated_model).await?;

        Ok(updated_model)
    }

    async fn delete(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()> {
        // 检查实体是否存在并获取实体信息
        let model = self.get_by_id(db, id.clone()).await?;

        // 前置钩子
        self.before_delete(&model).await?;

        // 删除实体
        E::delete_by_id(id.clone())
            .exec(db)
            .await
            .map_err(AppError::from)?;

        // 后置钩子
        self.after_delete(&id).await?;

        Ok(())
    }

    async fn list(&self, db: &DatabaseConnection) -> MijiResult<Vec<E::Model>> {
        E::find().all(db).await.map_err(AppError::from)
    }

    async fn list_with_filter(
        &self,
        db: &DatabaseConnection,
        filter: F,
    ) -> MijiResult<Vec<E::Model>> {
        E::find()
            .filter(filter.to_condition())
            .all(db)
            .await
            .map_err(AppError::from)
    }

    async fn list_paged(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<F>,
    ) -> MijiResult<PagedResult<E::Model>> {
        // 验证查询参数
        self.validate_paged_query(&query)?;

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
        let total_pages = total_count.div_ceil(query.page_size);

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

    async fn create_batch(
        &self,
        db: &DatabaseConnection,
        data: Vec<C>,
    ) -> MijiResult<Vec<E::Model>> {
        if data.is_empty() {
            return Ok(Vec::new());
        }

        let mut results = Vec::with_capacity(data.len());

        for item in data {
            // 验证每个数据项
            self.validate_data(&item)?;

            // 前置钩子
            self.before_create(&item).await?;

            // 转换并插入
            let active_model = self.converter.create_to_active_model(item)?;
            let model = active_model.insert(db).await.map_err(AppError::from)?;

            // 后置钩子
            self.after_create(&model).await?;

            results.push(model);
        }

        Ok(results)
    }

    async fn delete_batch(
        &self,
        db: &DatabaseConnection,
        ids: Vec<<E::PrimaryKey as PrimaryKeyTrait>::ValueType>,
    ) -> MijiResult<u64> {
        if ids.is_empty() {
            return Ok(0);
        }

        // 注意：这里简化了批量删除的实现，实际使用中可能需要根据具体 Entity 调整
        let mut deleted_count = 0u64;

        for id in ids.iter() {
            // 获取要删除的实体（用于钩子）
            if let Ok(model) = self.get_by_id(db, id.clone()).await {
                // 执行前置钩子
                self.before_delete(&model).await?;

                // 删除单个实体
                let delete_result = E::delete_by_id(id.clone())
                    .exec(db)
                    .await
                    .map_err(AppError::from)?;
                deleted_count += delete_result.rows_affected;

                // 执行后置钩子
                self.after_delete(id).await?;
            }
        }

        Ok(deleted_count)
    }

    async fn exists(
        &self,
        db: &DatabaseConnection,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<bool> {
        let count = E::find_by_id(id).count(db).await.map_err(AppError::from)?;
        Ok(count > 0)
    }

    async fn count(&self, db: &DatabaseConnection) -> MijiResult<u64> {
        E::find().count(db).await.map_err(AppError::from)
    }

    async fn count_with_filter(&self, db: &DatabaseConnection, filter: F) -> MijiResult<u64> {
        E::find()
            .filter(filter.to_condition())
            .count(db)
            .await
            .map_err(AppError::from)
    }
}

// 辅助方法实现
impl<E, F, C, U, Conv> GenericCrudService<E, F, C, U, Conv>
where
    E: EntityTrait,
    C: Validate,
    U: Validate,
    F: Validate,
{
    /// 验证创建数据
    fn validate_data(&self, data: &C) -> MijiResult<()> {
        data.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                "Validation failed",
                Some(self.format_validation_errors(e)),
            )
        })
    }

    /// 验证更新数据
    fn validate_update_data(&self, data: &U) -> MijiResult<()> {
        data.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                "Update validation failed",
                Some(self.format_validation_errors(e)),
            )
        })
    }

    /// 验证分页查询参数
    fn validate_paged_query(&self, query: &PagedQuery<F>) -> MijiResult<()> {
        query.validate().map_err(|e| {
            AppError::validation_failed(
                BusinessCode::ValidationError,
                "Query validation failed",
                Some(self.format_validation_errors(e)),
            )
        })
    }

    /// 格式化验证错误
    fn format_validation_errors(&self, errors: validator::ValidationErrors) -> serde_json::Value {
        let mut error_details = serde_json::Map::new();

        for (field, field_errors) in errors.field_errors() {
            let messages: Vec<String> = field_errors
                .iter()
                .filter_map(|e| e.message.as_ref().map(|m| m.to_string()))
                .collect();

            if !messages.is_empty() {
                error_details.insert(
                    field.to_string(),
                    serde_json::Value::Array(
                        messages
                            .into_iter()
                            .map(serde_json::Value::String)
                            .collect(),
                    ),
                );
            }
        }

        serde_json::Value::Object(error_details)
    }
}

/// 简化的转换器实现宏
#[macro_export]
macro_rules! impl_crud_converter {
    ($converter:ident, $entity:ty, $create:ty, $update:ty) => {
        pub struct $converter;

        impl CrudConverter<$entity, $create, $update> for $converter {
            fn create_to_active_model(
                &self,
                data: $create,
            ) -> MijiResult<<$entity as EntityTrait>::ActiveModel> {
                // 具体实现需要根据实际情况填写
                unimplemented!("需要实现 create_to_active_model 方法")
            }

            fn update_to_active_model(
                &self,
                model: <$entity as EntityTrait>::Model,
                data: $update,
            ) -> MijiResult<<$entity as EntityTrait>::ActiveModel> {
                // 具体实现需要根据实际情况填写
                unimplemented!("需要实现 update_to_active_model 方法")
            }
        }
    };
}

/// 事务支持的 CRUD 服务
#[async_trait]
pub trait TransactionalCrudService<E, F, C, U>: CrudService<E, F, C, U>
where
    E: EntityTrait,
    E::Model: FromQueryResult + Serialize + Send + Sync + Clone,
    E::ActiveModel: ActiveModelTrait<Entity = E> + Send,
    E::PrimaryKey: PrimaryKeyTrait,
    <E::PrimaryKey as PrimaryKeyTrait>::ValueType: Clone + Send + Sync + 'static,
    F: Filter<E> + Send + Sync,
    C: Validate + Send + Sync,
    U: Validate + Send + Sync,
{
    /// 在事务中创建
    async fn create_in_txn(
        &self,
        txn: &sea_orm::DatabaseTransaction,
        data: C,
    ) -> MijiResult<E::Model>;

    /// 在事务中更新
    async fn update_in_txn(
        &self,
        txn: &sea_orm::DatabaseTransaction,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
        data: U,
    ) -> MijiResult<E::Model>;

    /// 在事务中删除
    async fn delete_in_txn(
        &self,
        txn: &sea_orm::DatabaseTransaction,
        id: <E::PrimaryKey as PrimaryKeyTrait>::ValueType,
    ) -> MijiResult<()>;
}
