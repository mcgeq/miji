use std::str::FromStr;
use common::{
    BusinessCode,
    crud::service::{CrudConverter, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::{Filter, PagedQuery, PagedResult},
    utils::date::DateUtils,
};
use sea_orm::{
    ActiveValue::Set, ColumnTrait, Condition, DatabaseConnection, EntityTrait, PaginatorTrait,
    QueryFilter, QueryOrder, QuerySelect, SelectTwo,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use validator::Validate;

use crate::{
    dto::account::{CreateAccountRequest, UpdateAccountRequest},
    services::account_hooks::NoOpHooks,
};

/// 账户过滤器
#[derive(Debug, Validate, Serialize, Deserialize)]
pub struct AccountFilter {
    pub serial_num: Option<String>,
    pub name: Option<String>,
    pub r#type: Option<String>,
    pub currency: Option<String>,
    pub is_shared: Option<bool>,
    pub owner_id: Option<String>,
    pub is_active: Option<bool>,
}

/// 包含完整关联信息的账户数据结构
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountWithRelations {
    pub account: entity::account::Model,
    pub currency: entity::currency::Model,
    pub owner: Option<entity::family_member::Model>,
}

impl Filter<entity::account::Entity> for AccountFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();

        if let Some(serial_num) = &self.serial_num {
            condition = condition.add(entity::account::Column::SerialNum.eq(serial_num));
        }
        if let Some(name) = &self.name {
            condition = condition.add(entity::account::Column::Name.eq(name));
        }
        if let Some(r#type) = &self.r#type {
            condition = condition.add(entity::account::Column::Type.eq(r#type));
        }
        if let Some(currency) = &self.currency {
            condition = condition.add(entity::account::Column::Currency.eq(currency));
        }
        if let Some(is_shared) = self.is_shared {
            condition = condition.add(entity::account::Column::IsShared.eq(is_shared as i32));
        }
        if let Some(owner_id) = &self.owner_id {
            condition = condition.add(entity::account::Column::OwnerId.eq(owner_id));
        }
        if let Some(is_active) = self.is_active {
            condition = condition.add(entity::account::Column::IsActive.eq(is_active as i32));
        }

        condition
    }
}

/// 账户转换器
#[derive(Debug)]
pub struct AccountConverter;

impl CrudConverter<entity::account::Entity, CreateAccountRequest, UpdateAccountRequest>
    for AccountConverter
{
    fn create_to_active_model(
        &self,
        data: CreateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data).map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::account::Model,
        data: UpdateAccountRequest,
    ) -> MijiResult<entity::account::ActiveModel> {
        entity::account::ActiveModel::try_from(data)
            .map(|mut active_model| {
                // 保留主键和创建时间等不可变字段
                active_model.serial_num = Set(model.serial_num.clone());
                active_model.created_at = Set(model.created_at.clone());

                // 设置更新时间
                active_model.updated_at =
                    Set(Some(DateUtils::local_rfc3339()));

                active_model
            })
            .map_err(AppError::from_validation_errors)
    }

    fn primary_key_to_string(&self, model: &entity::account::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "accounts"
    }
}

/// 账户服务类型别名
pub type BaseAccountService = GenericCrudService<
    entity::account::Entity,
    AccountFilter,
    CreateAccountRequest,
    UpdateAccountRequest,
    AccountConverter,
    NoOpHooks,
>;

pub struct AccountService {
    base_service: BaseAccountService,
}

impl AccountService {
    pub fn new(
        converter: AccountConverter,
        hooks: NoOpHooks,
        logger: Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        let base_service = BaseAccountService::new(converter, hooks, logger);
        Self { base_service }
    }

    /// 获取基础服务引用
    pub fn base(&self) -> &BaseAccountService {
        &self.base_service
    }

    /// 获取账户详情（带货币信息）
    pub async fn get_account_with_currency(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<(entity::account::Model, entity::currency::Model)> {
        entity::account::Entity::find_by_id(id)
            .find_also_related(entity::currency::Entity)
            .one(db)
            .await
            .map_err(AppError::from)?
            .and_then(|(account, currency)| currency.map(|c| (account, c)))
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::NotFound,
                    "Account not found or currency missing",
                )
            })
    }

    /// 获取账户详情（带完整关联信息：货币和所有者）
    pub async fn get_account_with_relations(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )> {
        // 首先获取账户和货币信息
        let (account, currency) = self.get_account_with_currency(db, id.clone()).await?;

        // 如果有 owner_id，获取所有者信息
        let owner = if let Some(owner_id) = &account.owner_id {
            entity::family_member::Entity::find_by_id(owner_id.clone())
                .one(db)
                .await
                .map_err(AppError::from)?
        } else {
            None
        };

        Ok((account, currency, owner))
    }

    /// 使用自定义查询获取账户和所有关联信息（更高效的方法）
    pub async fn get_account_with_relations_optimized(
        &self,
        db: &DatabaseConnection,
        id: String,
    ) -> MijiResult<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )> {

        let result = entity::account::Entity::find_by_id(id)
            .find_also_related(entity::currency::Entity)
            .find_also_related(entity::family_member::Entity)
            .one(db)
            .await
            .map_err(AppError::from)?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "Account not found"))?;

        let (account, currency, owner) = result;
        let currency = currency.ok_or_else(|| {
            AppError::simple(BusinessCode::NotFound, "Currency information missing")
        })?;

        Ok((account, currency, owner))
    }

    pub async fn list_with_filter(&self,
        db: &DatabaseConnection,
        query: AccountFilter) -> MijiResult<
    PagedResult<(
        entity::account::Model, 
        entity::currency::Model,
        Option<entity::family_member::Model>)>> {
        query.validate().map_err(AppError::from_validation_errors)?;

        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.to_condition());

        let total_count = query_builder
        .clone()
        .count(db)
        .await
        .map_err(AppError::from)? as usize;

    // 获取所有符合条件的账户+货币记录（无分页，全量查询）
    let accounts_with_currency = query_builder
        .all(db)
        .await
        .map_err(AppError::from)?;

    // 提取所有关联的 owner_id（用于批量查询家庭成员）
    let owner_ids: Vec<String> = accounts_with_currency
        .iter()
        .filter_map(|(account, _)| account.owner_id.as_ref())  // 过滤无 owner_id 的记录
        .cloned()
        .collect();

    // 批量查询家庭成员信息（减少数据库交互次数）
    let owners = if !owner_ids.is_empty() {
        entity::family_member::Entity::find()
            .filter(entity::family_member::Column::SerialNum.is_in(owner_ids))  // IN 条件批量查询
            .all(db)
            .await
            .map_err(AppError::from)?
    } else {
        Vec::new()  // 无 owner_id 时返回空数组
    };

    // 构建 owner_id -> family_member 的映射（O(1) 查找）
    let owners_map: std::collections::HashMap<String, entity::family_member::Model> = owners
        .into_iter()
        .map(|owner| (owner.serial_num.clone(), owner))
        .collect();

    // 组装最终结果：合并账户、货币、家庭成员信息
    let rows: Vec<(
        entity::account::Model,
        entity::currency::Model,
        Option<entity::family_member::Model>,
    )> = accounts_with_currency
        .into_iter()
        .filter_map(|(account, currency)| {
            // 仅保留有货币信息的记录（根据业务需求调整，若允许无货币可移除 filter_map）
            currency.map(|c| {
                // 查找当前账户关联的家庭成员（可能为 None）
                let owner = account.owner_id.as_ref()
                    .and_then(|id| owners_map.get(id))
                    .cloned();
                (account, c, owner)
            })
        })
        .collect();

    // 构造 PagedResult（无分页时，当前页为 1，每页大小为总记录数，总页数为 1）
    Ok(PagedResult {
        rows,
        total_count,
        current_page: 1,
        page_size: total_count,
        total_pages: 1,
    })

    }
    /// 分页查询账户列表（带完整关联信息）
    pub async fn list_accounts_paged_with_relations(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<
        PagedResult<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )>,
    > {
        // 验证查询参数
        query.validate().map_err(AppError::from_validation_errors)?;

        // 构建查询 - 先获取基础的 account + currency 信息
        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.filter.to_condition());

        // 应用排序
        query_builder = Self::apply_sort_to_select_two(
            query_builder,
            &query.sort_options.sort_by,
            query.sort_options.desc,
        );

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
        let accounts_with_currency = query_builder
            .offset(offset as u64)
            .limit(query.page_size as u64)
            .all(db)
            .await
            .map_err(AppError::from)?;

        // 获取所有 owner_id 并批量查询 family_member 信息
        let owner_ids: Vec<String> = accounts_with_currency
            .iter()
            .filter_map(|(account, _)| account.owner_id.as_ref())
            .cloned()
            .collect();

        let owners = if !owner_ids.is_empty() {
            entity::family_member::Entity::find()
                .filter(entity::family_member::Column::SerialNum.is_in(owner_ids))
                .all(db)
                .await
                .map_err(AppError::from)?
        } else {
            Vec::new()
        };

        // 创建 owner_id -> family_member 的映射
        let owners_map: std::collections::HashMap<String, entity::family_member::Model> = owners
            .into_iter()
            .map(|owner| (owner.serial_num.clone(), owner))
            .collect();

        // 组装最终结果
        let rows: Vec<(
            entity::account::Model,
            entity::currency::Model,
            Option<entity::family_member::Model>,
        )> = accounts_with_currency
            .into_iter()
            .filter_map(|(account, currency)| {
                currency.map(|c| {
                    let owner = account
                        .owner_id
                        .as_ref()
                        .and_then(|id| owners_map.get(id))
                        .cloned();

                    (account, c, owner)
                })
            })
            .collect();

        Ok(PagedResult {
            rows,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    /// 分页查询账户列表（带货币信息）
    pub async fn list_accounts_paged_with_currency(
        &self,
        db: &DatabaseConnection,
        query: PagedQuery<AccountFilter>,
    ) -> MijiResult<PagedResult<(entity::account::Model, entity::currency::Model)>> {
        // 验证查询参数
        query.validate().map_err(AppError::from_validation_errors)?;

        let mut query_builder = entity::account::Entity::find()
            .find_also_related(entity::currency::Entity)
            .filter(query.filter.to_condition());

        // 应用排序
        query_builder = Self::apply_sort_to_select_two(
            query_builder,
            &query.sort_options.sort_by,
            query.sort_options.desc,
        );

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

        // 过滤掉货币信息缺失的记录
        let rows_with_currency: Vec<_> = rows
            .into_iter()
            .filter_map(|(account, currency)| currency.map(|c| (account, c)))
            .collect();

        Ok(PagedResult {
            rows: rows_with_currency,
            total_count,
            current_page: query.current_page,
            page_size: query.page_size,
            total_pages,
        })
    }

    /// 自定义排序方法处理 SelectTwo 类型
    fn apply_sort_to_select_two(
        query_builder: SelectTwo<entity::account::Entity, entity::currency::Entity>,
        sort_by: &Option<String>,
        desc: bool,
    ) -> SelectTwo<entity::account::Entity, entity::currency::Entity> {
        if let Some(sort_by) = sort_by {
            // 尝试解析为账户字段
            if let Ok(column) = entity::account::Column::from_str(sort_by) {
                return if desc {
                    query_builder.order_by_desc(column)
                } else {
                    query_builder.order_by_asc(column)
                };
            }

            // 尝试解析为货币字段 (格式: currency.field)
            if let Some(("currency", field)) = sort_by.split_once('.') {
                if let Ok(column) = entity::currency::Column::from_str(field) {
                    return if desc {
                        query_builder.order_by_desc(column)
                    } else {
                        query_builder.order_by_asc(column)                        };
                }
            }
        }
        query_builder
    }
}

/// 获取账户服务实例
pub fn get_account_service() -> AccountService {
    AccountService::new(
        AccountConverter,
        NoOpHooks,
        Arc::new(common::log::logger::NoopLogger),
    )
}
