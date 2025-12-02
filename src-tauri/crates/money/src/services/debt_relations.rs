use std::collections::HashMap;

use common::{
    crud::service::{CrudConverter, GenericCrudService, LocalizableConverter},
    error::{AppError, MijiResult},
    log::logger::NoopLogger,
    paginations::{EmptyFilter, PagedResult},
    utils::date::DateUtils,
};
use entity::localize::LocalizeModel;
use sea_orm::prelude::Decimal;
use sea_orm::{
    ActiveValue, ColumnTrait, Condition, DbConn, EntityTrait, Order, PaginatorTrait, QueryFilter,
    QueryOrder, QuerySelect, prelude::async_trait::async_trait,
};

use crate::{
    dto::debt_relations::{
        DebtGraph, DebtGraphEdge, DebtGraphNode, DebtRelationCreate, DebtRelationQuery,
        DebtRelationResponse, DebtRelationUpdate, DebtSettlement, DebtStats, MemberDebtSummary,
    },
    services::debt_relations_hooks::DebtRelationsHooks,
};

pub type DebtRelationsFilter = EmptyFilter;

#[derive(Debug)]
pub struct DebtRelationsConverter;

impl CrudConverter<entity::debt_relations::Entity, DebtRelationCreate, DebtRelationUpdate>
    for DebtRelationsConverter
{
    fn create_to_active_model(
        &self,
        data: DebtRelationCreate,
    ) -> MijiResult<entity::debt_relations::ActiveModel> {
        entity::debt_relations::ActiveModel::try_from(data)
            .map_err(AppError::from_validation_errors)
    }

    fn update_to_active_model(
        &self,
        model: entity::debt_relations::Model,
        data: DebtRelationUpdate,
    ) -> MijiResult<entity::debt_relations::ActiveModel> {
        let mut active_model = entity::debt_relations::ActiveModel {
            serial_num: ActiveValue::Set(model.serial_num.clone()),
            family_ledger_serial_num: ActiveValue::Set(model.family_ledger_serial_num.clone()),
            creditor_member_serial_num: ActiveValue::Set(model.creditor_member_serial_num.clone()),
            debtor_member_serial_num: ActiveValue::Set(model.debtor_member_serial_num.clone()),
            currency: ActiveValue::Set(model.currency.clone()),
            last_updated_by: ActiveValue::Set(model.last_updated_by.clone()),
            created_at: ActiveValue::Set(model.created_at),
            ..Default::default()
        };

        data.apply_to_model(&mut active_model);
        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::debt_relations::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "debt_relations"
    }
}

#[async_trait]
impl LocalizableConverter<entity::debt_relations::Model> for DebtRelationsConverter {
    async fn model_with_local(
        &self,
        model: entity::debt_relations::Model,
    ) -> MijiResult<entity::debt_relations::Model> {
        Ok(model.to_local())
    }
}

pub struct DebtRelationsService {
    pub inner: GenericCrudService<
        entity::debt_relations::Entity,
        DebtRelationsFilter,
        DebtRelationCreate,
        DebtRelationUpdate,
        DebtRelationsConverter,
        DebtRelationsHooks,
    >,
}

impl Default for DebtRelationsService {
    fn default() -> Self {
        use std::sync::Arc;
        Self::new(
            DebtRelationsConverter,
            DebtRelationsHooks,
            Arc::new(NoopLogger),
        )
    }
}

impl DebtRelationsService {
    pub fn new(
        converter: DebtRelationsConverter,
        hooks: DebtRelationsHooks,
        logger: std::sync::Arc<dyn common::log::logger::OperationLogger>,
    ) -> Self {
        Self {
            inner: GenericCrudService::new(converter, hooks, logger),
        }
    }
}

impl std::ops::Deref for DebtRelationsService {
    type Target = GenericCrudService<
        entity::debt_relations::Entity,
        DebtRelationsFilter,
        DebtRelationCreate,
        DebtRelationUpdate,
        DebtRelationsConverter,
        DebtRelationsHooks,
    >;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl DebtRelationsService {
    /// 根据家庭账本ID查询债务关系
    pub async fn find_by_family_ledger(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<Vec<DebtRelationResponse>> {
        self.find_with_query(
            db,
            DebtRelationQuery {
                family_ledger_serial_num: Some(family_ledger_serial_num.to_string()),
                ..Default::default()
            },
        )
        .await
        .map(|paged| paged.rows)
    }

    /// 根据查询条件获取债务关系
    pub async fn find_with_query(
        &self,
        db: &DbConn,
        query: DebtRelationQuery,
    ) -> MijiResult<PagedResult<DebtRelationResponse>> {
        let mut select = entity::debt_relations::Entity::find();

        // 应用查询条件
        if let Some(family_ledger_serial_num) = &query.family_ledger_serial_num {
            select = select.filter(
                entity::debt_relations::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num),
            );
        }

        if let Some(creditor_member_serial_num) = &query.creditor_member_serial_num {
            select = select.filter(
                entity::debt_relations::Column::CreditorMemberSerialNum
                    .eq(creditor_member_serial_num),
            );
        }

        if let Some(debtor_member_serial_num) = &query.debtor_member_serial_num {
            select = select.filter(
                entity::debt_relations::Column::DebtorMemberSerialNum.eq(debtor_member_serial_num),
            );
        }

        if let Some(status) = &query.status {
            select = select.filter(entity::debt_relations::Column::Status.eq(status));
        }

        if let Some(min_amount) = query.min_amount {
            select = select.filter(entity::debt_relations::Column::Amount.gte(min_amount));
        }

        if let Some(max_amount) = query.max_amount {
            select = select.filter(entity::debt_relations::Column::Amount.lte(max_amount));
        }

        // 排序：金额降序
        select = select.order_by(entity::debt_relations::Column::Amount, Order::Desc);

        let page = query.page.unwrap_or(1);
        let page_size = query.page_size.unwrap_or(20);

        // 简化分页实现
        let offset = (page - 1) * page_size;
        let models = select
            .limit(page_size)
            .offset(offset)
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        let total_count = if let Some(family_ledger_serial_num) = &query.family_ledger_serial_num {
            entity::debt_relations::Entity::find()
                .filter(
                    entity::debt_relations::Column::FamilyLedgerSerialNum
                        .eq(family_ledger_serial_num),
                )
                .count(db)
                .await
        } else {
            entity::debt_relations::Entity::find().count(db).await
        }
        .map_err(|e| {
            AppError::simple(
                common::BusinessCode::DatabaseError,
                format!("Database error: {}", e),
            )
        })? as u64;

        let responses: Vec<DebtRelationResponse> =
            models.into_iter().map(DebtRelationResponse::from).collect();

        Ok(PagedResult {
            rows: responses,
            total_count: total_count as usize,
            current_page: page as usize,
            page_size: page_size as usize,
            total_pages: total_count.div_ceil(page_size) as usize,
        })
    }

    /// 获取成员间的债务关系
    pub async fn get_member_debt_relation(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        creditor_member_serial_num: &str,
        debtor_member_serial_num: &str,
    ) -> MijiResult<Option<DebtRelationResponse>> {
        let debt_relation = entity::debt_relations::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::debt_relations::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(
                        entity::debt_relations::Column::CreditorMemberSerialNum
                            .eq(creditor_member_serial_num),
                    )
                    .add(
                        entity::debt_relations::Column::DebtorMemberSerialNum
                            .eq(debtor_member_serial_num),
                    )
                    .add(entity::debt_relations::Column::Status.eq("Active")),
            )
            .one(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(debt_relation.map(DebtRelationResponse::from))
    }

    /// 更新或创建债务关系
    pub async fn upsert_debt_relation(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        creditor_member_serial_num: &str,
        debtor_member_serial_num: &str,
        amount: Decimal,
        currency: &str,
        updated_by: &str,
    ) -> MijiResult<DebtRelationResponse> {
        // 查找现有债务关系
        let existing_relation = entity::debt_relations::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::debt_relations::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(
                        entity::debt_relations::Column::CreditorMemberSerialNum
                            .eq(creditor_member_serial_num),
                    )
                    .add(
                        entity::debt_relations::Column::DebtorMemberSerialNum
                            .eq(debtor_member_serial_num),
                    )
                    .add(entity::debt_relations::Column::Status.eq("Active")),
            )
            .one(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        if let Some(existing) = existing_relation {
            // 更新现有关系
            let update_data = DebtRelationUpdate {
                amount: Some(amount),
                status: None,
                notes: None,
            };

            let active_model =
                DebtRelationsConverter.update_to_active_model(existing, update_data)?;
            let updated = entity::debt_relations::Entity::update(active_model)
                .exec(db)
                .await
                .map_err(|e| {
                    AppError::simple(
                        common::BusinessCode::DatabaseError,
                        format!("Database error: {}", e),
                    )
                })?;
            Ok(DebtRelationResponse::from(updated))
        } else {
            // 创建新关系
            let create_data = DebtRelationCreate {
                creditor_member_serial_num: creditor_member_serial_num.to_string(),
                debtor_member_serial_num: debtor_member_serial_num.to_string(),
                amount,
                currency: currency.to_string(),
                notes: None,
            };

            let mut active_model = DebtRelationsConverter.create_to_active_model(create_data)?;
            active_model.family_ledger_serial_num =
                ActiveValue::Set(family_ledger_serial_num.to_string());
            active_model.last_updated_by = ActiveValue::Set(updated_by.to_string());

            let created = entity::debt_relations::Entity::insert(active_model)
                .exec_with_returning(db)
                .await
                .map_err(|e| {
                    AppError::simple(
                        common::BusinessCode::DatabaseError,
                        format!("Database error: {}", e),
                    )
                })?;

            Ok(DebtRelationResponse::from(created))
        }
    }

    /// 结算债务
    pub async fn settle_debts(
        &self,
        db: &DbConn,
        settlement_request: DebtSettlement,
    ) -> MijiResult<Vec<DebtRelationResponse>> {
        let now = DateUtils::local_now();

        // 批量更新状态为已结算
        entity::debt_relations::Entity::update_many()
            .col_expr(
                entity::debt_relations::Column::Status,
                sea_orm::sea_query::Expr::value("Settled"),
            )
            .col_expr(
                entity::debt_relations::Column::SettledAt,
                sea_orm::sea_query::Expr::value(now),
            )
            .col_expr(
                entity::debt_relations::Column::UpdatedAt,
                sea_orm::sea_query::Expr::value(Some(now)),
            )
            .filter(
                entity::debt_relations::Column::SerialNum
                    .is_in(&settlement_request.debt_serial_nums),
            )
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 如果有备注，更新备注
        if let Some(notes) = settlement_request.notes {
            entity::debt_relations::Entity::update_many()
                .col_expr(
                    entity::debt_relations::Column::Notes,
                    sea_orm::sea_query::Expr::value(Some(notes)),
                )
                .filter(
                    entity::debt_relations::Column::SerialNum
                        .is_in(&settlement_request.debt_serial_nums),
                )
                .exec(db)
                .await
                .map_err(|e| {
                    AppError::simple(
                        common::BusinessCode::DatabaseError,
                        format!("Database error: {}", e),
                    )
                })?;
        }

        // 返回更新后的记录
        let updated_records = entity::debt_relations::Entity::find()
            .filter(
                entity::debt_relations::Column::SerialNum
                    .is_in(&settlement_request.debt_serial_nums),
            )
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(updated_records
            .into_iter()
            .map(DebtRelationResponse::from)
            .collect())
    }

    /// 获取债务统计
    pub async fn get_debt_statistics(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<DebtStats> {
        let debts = entity::debt_relations::Entity::find()
            .filter(
                entity::debt_relations::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num),
            )
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        let total_debts = debts.len() as i64;
        let active_debts = debts.iter().filter(|d| d.status == "Active").count() as i64;
        let settled_debts = debts.iter().filter(|d| d.status == "Settled").count() as i64;

        let total_amount: Decimal = debts.iter().map(|d| d.amount).sum();
        let active_amount: Decimal = debts
            .iter()
            .filter(|d| d.status == "Active")
            .map(|d| d.amount)
            .sum();
        let settled_amount: Decimal = debts
            .iter()
            .filter(|d| d.status == "Settled")
            .map(|d| d.amount)
            .sum();

        Ok(DebtStats {
            total_debts,
            active_debts,
            settled_debts,
            total_amount,
            active_amount,
            settled_amount,
        })
    }

    /// 获取成员债务汇总
    pub async fn get_member_debt_summary(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        member_serial_num: &str,
    ) -> MijiResult<MemberDebtSummary> {
        // 获取作为债权人的债务
        let credit_debts = entity::debt_relations::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::debt_relations::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(
                        entity::debt_relations::Column::CreditorMemberSerialNum
                            .eq(member_serial_num),
                    )
                    .add(entity::debt_relations::Column::Status.eq("Active")),
            )
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 获取作为债务人的债务
        let debt_debts = entity::debt_relations::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::debt_relations::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(
                        entity::debt_relations::Column::DebtorMemberSerialNum.eq(member_serial_num),
                    )
                    .add(entity::debt_relations::Column::Status.eq("Active")),
            )
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        let total_credit: Decimal = credit_debts.iter().map(|d| d.amount).sum();
        let total_debt: Decimal = debt_debts.iter().map(|d| d.amount).sum();
        let net_balance = total_credit - total_debt;
        let active_credits = credit_debts.len() as i64;
        let active_debts = debt_debts.len() as i64;

        // 获取成员名称
        let member = entity::family_member::Entity::find_by_id(member_serial_num)
            .one(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?
            .ok_or_else(|| AppError::simple(common::BusinessCode::NotFound, "成员不存在"))?;

        Ok(MemberDebtSummary {
            member_serial_num: member_serial_num.to_string(),
            member_name: member.name,
            total_credit,
            total_debt,
            net_balance,
            active_credits,
            active_debts,
        })
    }

    /// 获取债务关系图谱
    pub async fn get_debt_graph(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<DebtGraph> {
        // 获取所有活跃的债务关系
        let debts = entity::debt_relations::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::debt_relations::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(entity::debt_relations::Column::Status.eq("Active")),
            )
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 获取所有相关成员
        let mut member_ids: std::collections::HashSet<String> = std::collections::HashSet::new();
        for debt in &debts {
            member_ids.insert(debt.creditor_member_serial_num.clone());
            member_ids.insert(debt.debtor_member_serial_num.clone());
        }

        let members = entity::family_member::Entity::find()
            .filter(entity::family_member::Column::SerialNum.is_in(member_ids))
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 计算每个成员的净余额
        let mut member_balances: HashMap<String, Decimal> = HashMap::new();
        for debt in &debts {
            *member_balances
                .entry(debt.creditor_member_serial_num.clone())
                .or_insert(Decimal::ZERO) += debt.amount;
            *member_balances
                .entry(debt.debtor_member_serial_num.clone())
                .or_insert(Decimal::ZERO) -= debt.amount;
        }

        // 构建节点
        let nodes: Vec<DebtGraphNode> = members
            .into_iter()
            .map(|member| DebtGraphNode {
                member_serial_num: member.serial_num.clone(),
                member_name: member.name,
                avatar_url: member.avatar_url,
                color: member.color,
                net_balance: member_balances
                    .get(&member.serial_num)
                    .copied()
                    .unwrap_or(Decimal::ZERO),
            })
            .collect();

        // 构建边
        let edges: Vec<DebtGraphEdge> = debts
            .into_iter()
            .map(|debt| DebtGraphEdge {
                from_member: debt.creditor_member_serial_num,
                to_member: debt.debtor_member_serial_num,
                amount: debt.amount,
                currency: debt.currency,
                status: debt.status,
            })
            .collect();

        let total_amount: Decimal = edges.iter().map(|e| e.amount).sum();

        Ok(DebtGraph {
            nodes,
            edges,
            total_amount,
            currency: "CNY".to_string(), // 默认货币，实际应该从配置获取
        })
    }

    /// 重新计算所有债务关系
    pub async fn recalculate_all_debts(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        updated_by: &str,
    ) -> MijiResult<i64> {
        // 获取所有未支付的分摊记录
        let split_records = entity::split_records::Entity::find()
            .filter(
                Condition::all()
                    .add(
                        entity::split_records::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(entity::split_records::Column::Status.ne("Paid")),
            )
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 按成员对计算债务
        let mut debt_map: HashMap<(String, String), Decimal> = HashMap::new();

        for record in split_records {
            let key = (record.payer_member_serial_num, record.owe_member_serial_num);
            *debt_map.entry(key).or_insert(Decimal::ZERO) += record.split_amount;
        }

        // 清除现有的活跃债务关系
        entity::debt_relations::Entity::delete_many()
            .filter(
                Condition::all()
                    .add(
                        entity::debt_relations::Column::FamilyLedgerSerialNum
                            .eq(family_ledger_serial_num),
                    )
                    .add(entity::debt_relations::Column::Status.eq("Active")),
            )
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        // 创建新的债务关系
        let mut created_count = 0i64;
        for ((creditor, debtor), amount) in debt_map {
            if amount > Decimal::ZERO {
                self.upsert_debt_relation(
                    db,
                    family_ledger_serial_num,
                    &creditor,
                    &debtor,
                    amount,
                    "CNY", // 默认货币
                    updated_by,
                )
                .await?;
                created_count += 1;
            }
        }

        Ok(created_count)
    }

    /// 从分摊记录同步债务关系（别名方法）
    pub async fn sync_from_split_records(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        updated_by: &str,
    ) -> MijiResult<i64> {
        self.recalculate_all_debts(db, family_ledger_serial_num, updated_by)
            .await
    }
}
