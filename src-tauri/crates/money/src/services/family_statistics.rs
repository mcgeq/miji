use std::collections::HashMap;
use sea_orm::prelude::Decimal;
use chrono::{NaiveDate, Datelike};
use common::error::{AppError, MijiResult};
use sea_orm::{DbConn, EntityTrait, ColumnTrait, QueryFilter, Condition};
use serde::{Deserialize, Serialize};

use crate::services::{
    split_records::SplitRecordsService,
    debt_relations::DebtRelationsService,
    settlement_records::SettlementRecordsService,
};

/// 家庭财务统计服务
#[derive(Debug)]
pub struct FamilyStatisticsService {
    split_service: SplitRecordsService,
    debt_service: DebtRelationsService,
    settlement_service: SettlementRecordsService,
}

/// 家庭财务总览
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FamilyFinancialOverview {
    pub family_ledger_serial_num: String,
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,
    pub total_income: Decimal,
    pub total_expense: Decimal,
    pub shared_expense: Decimal,
    pub personal_expense: Decimal,
    pub net_balance: Decimal,
    pub member_count: i32,
    pub transaction_count: i64,
    pub split_count: i64,
    pub settlement_count: i64,
}

/// 成员贡献统计
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberContribution {
    pub member_serial_num: String,
    pub member_name: String,
    pub total_income: Decimal,
    pub total_expense: Decimal,
    pub shared_expense: Decimal,
    pub personal_expense: Decimal,
    pub split_paid: Decimal,
    pub split_owed: Decimal,
    pub net_contribution: Decimal,
    pub contribution_percentage: Decimal,
    pub transaction_count: i64,
}

/// 分类统计
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CategoryStatistics {
    pub category: String,
    pub sub_category: Option<String>,
    pub total_amount: Decimal,
    pub transaction_count: i64,
    pub percentage: Decimal,
    pub average_amount: Decimal,
    pub member_distribution: HashMap<String, Decimal>,
}

/// 趋势分析数据
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TrendAnalysis {
    pub period: String, // YYYY-MM 或 YYYY-MM-DD
    pub total_income: Decimal,
    pub total_expense: Decimal,
    pub shared_expense: Decimal,
    pub net_balance: Decimal,
    pub transaction_count: i64,
    pub split_count: i64,
    pub average_transaction_amount: Decimal,
}

/// 债务分析
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DebtAnalysis {
    pub total_active_debt: Decimal,
    pub total_settled_debt: Decimal,
    pub average_debt_amount: Decimal,
    pub debt_distribution: Vec<MemberDebtDistribution>,
    pub settlement_efficiency: Decimal, // 结算效率百分比
    pub pending_settlement_amount: Decimal,
}

/// 成员债务分布
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MemberDebtDistribution {
    pub member_serial_num: String,
    pub member_name: String,
    pub as_creditor: Decimal,
    pub as_debtor: Decimal,
    pub net_position: Decimal,
    pub debt_relationships: i32,
}

impl FamilyStatisticsService {
    pub fn new() -> Self {
        Self {
            split_service: SplitRecordsService::new(),
            debt_service: DebtRelationsService::new(),
            settlement_service: SettlementRecordsService::new(),
        }
    }

    /// 获取家庭财务总览
    pub async fn get_financial_overview(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        period_start: NaiveDate,
        period_end: NaiveDate,
    ) -> MijiResult<FamilyFinancialOverview> {
        // 获取交易数据
        let transactions = entity::transactions::Entity::find()
            .find_also_related(entity::family_ledger_transaction::Entity)
            .filter(
                Condition::all()
                    .add(entity::family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
                    .add(entity::transactions::Column::Date.between(period_start, period_end))
            )
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let mut total_income = Decimal::ZERO;
        let mut total_expense = Decimal::ZERO;
        let mut shared_expense = Decimal::ZERO;
        let mut personal_expense = Decimal::ZERO;

        for (transaction, _) in &transactions {
            if transaction.transaction_type == "Income" {
                total_income += transaction.amount;
            } else if transaction.transaction_type == "Expense" {
                total_expense += transaction.amount;
                
                // 判断是否为共享支出（有分摊记录）
                let has_split = entity::split_records::Entity::find()
                    .filter(entity::split_records::Column::TransactionSerialNum.eq(&transaction.serial_num))
                    .count(db)
                    .await
                    .map_err(AppError::from_db_error)? > 0;
                
                if has_split {
                    shared_expense += transaction.amount;
                } else {
                    personal_expense += transaction.amount;
                }
            }
        }

        // 获取成员数量
        let member_count = entity::family_ledger_member::Entity::find()
            .filter(entity::family_ledger_member::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
            .count(db)
            .await
            .map_err(AppError::from_db_error)? as i32;

        // 获取分摊记录数量
        let split_count = entity::split_records::Entity::find()
            .filter(
                Condition::all()
                    .add(entity::split_records::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
                    .add(entity::split_records::Column::CreatedAt.between(period_start, period_end))
            )
            .count(db)
            .await
            .map_err(AppError::from_db_error)?;

        // 获取结算记录数量
        let settlement_count = entity::settlement_records::Entity::find()
            .filter(
                Condition::all()
                    .add(entity::settlement_records::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
                    .add(entity::settlement_records::Column::PeriodStart.gte(period_start))
                    .add(entity::settlement_records::Column::PeriodEnd.lte(period_end))
            )
            .count(db)
            .await
            .map_err(AppError::from_db_error)?;

        Ok(FamilyFinancialOverview {
            family_ledger_serial_num: family_ledger_serial_num.to_string(),
            period_start,
            period_end,
            total_income,
            total_expense,
            shared_expense,
            personal_expense,
            net_balance: total_income - total_expense,
            member_count,
            transaction_count: transactions.len() as i64,
            split_count,
            settlement_count,
        })
    }

    /// 获取成员贡献统计
    pub async fn get_member_contributions(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        period_start: NaiveDate,
        period_end: NaiveDate,
    ) -> MijiResult<Vec<MemberContribution>> {
        // 获取所有成员
        let members = entity::family_ledger_member::Entity::find()
            .find_also_related(entity::family_member::Entity)
            .filter(entity::family_ledger_member::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let mut contributions = Vec::new();
        let mut total_contribution = Decimal::ZERO;

        for (_, member_opt) in members {
            if let Some(member) = member_opt {
                let contribution = self.calculate_member_contribution(
                    db,
                    family_ledger_serial_num,
                    &member,
                    period_start,
                    period_end,
                ).await?;
                
                total_contribution += contribution.net_contribution;
                contributions.push(contribution);
            }
        }

        // 计算贡献百分比
        for contribution in &mut contributions {
            if total_contribution > Decimal::ZERO {
                contribution.contribution_percentage = 
                    (contribution.net_contribution / total_contribution) * Decimal::from(100);
            }
        }

        // 按贡献排序
        contributions.sort_by(|a, b| b.net_contribution.cmp(&a.net_contribution));

        Ok(contributions)
    }

    /// 获取分类统计
    pub async fn get_category_statistics(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        period_start: NaiveDate,
        period_end: NaiveDate,
    ) -> MijiResult<Vec<CategoryStatistics>> {
        // 获取交易数据
        let transactions = entity::transactions::Entity::find()
            .find_also_related(entity::family_ledger_transaction::Entity)
            .filter(
                Condition::all()
                    .add(entity::family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
                    .add(entity::transactions::Column::Date.between(period_start, period_end))
                    .add(entity::transactions::Column::TransactionType.eq("Expense"))
            )
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let mut category_map: HashMap<(String, Option<String>), CategoryData> = HashMap::new();
        let mut total_amount = Decimal::ZERO;

        for (transaction, _) in transactions {
            let key = (transaction.category.clone(), transaction.sub_category.clone());
            let entry = category_map.entry(key).or_insert_with(|| CategoryData {
                total_amount: Decimal::ZERO,
                transaction_count: 0,
                member_distribution: HashMap::new(),
            });

            entry.total_amount += transaction.amount;
            entry.transaction_count += 1;
            total_amount += transaction.amount;

            // 获取账户所有者（简化处理）
            if let Some(account) = entity::account::Entity::find_by_id(&transaction.account_serial_num)
                .one(db)
                .await
                .map_err(AppError::from_db_error)? 
            {
                *entry.member_distribution.entry(account.owner_id).or_insert(Decimal::ZERO) += transaction.amount;
            }
        }

        let mut statistics = Vec::new();
        for ((category, sub_category), data) in category_map {
            let percentage = if total_amount > Decimal::ZERO {
                (data.total_amount / total_amount) * Decimal::from(100)
            } else {
                Decimal::ZERO
            };

            let average_amount = if data.transaction_count > 0 {
                data.total_amount / Decimal::from(data.transaction_count)
            } else {
                Decimal::ZERO
            };

            statistics.push(CategoryStatistics {
                category,
                sub_category,
                total_amount: data.total_amount,
                transaction_count: data.transaction_count,
                percentage,
                average_amount,
                member_distribution: data.member_distribution,
            });
        }

        // 按金额排序
        statistics.sort_by(|a, b| b.total_amount.cmp(&a.total_amount));

        Ok(statistics)
    }

    /// 获取趋势分析
    pub async fn get_trend_analysis(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        period_start: NaiveDate,
        period_end: NaiveDate,
        granularity: &str, // "monthly" 或 "daily"
    ) -> MijiResult<Vec<TrendAnalysis>> {
        let transactions = entity::transactions::Entity::find()
            .find_also_related(entity::family_ledger_transaction::Entity)
            .filter(
                Condition::all()
                    .add(entity::family_ledger_transaction::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
                    .add(entity::transactions::Column::Date.between(period_start, period_end))
            )
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let mut period_map: HashMap<String, TrendData> = HashMap::new();

        for (transaction, _) in transactions {
            let period_key = match granularity {
                "monthly" => format!("{}-{:02}", transaction.date.year(), transaction.date.month()),
                "daily" => transaction.date.format("%Y-%m-%d").to_string(),
                _ => return Err(AppError::bad_request("不支持的时间粒度")),
            };

            let entry = period_map.entry(period_key).or_insert_with(|| TrendData {
                total_income: Decimal::ZERO,
                total_expense: Decimal::ZERO,
                shared_expense: Decimal::ZERO,
                transaction_count: 0,
                split_count: 0,
            });

            entry.transaction_count += 1;

            if transaction.transaction_type == "Income" {
                entry.total_income += transaction.amount;
            } else if transaction.transaction_type == "Expense" {
                entry.total_expense += transaction.amount;

                // 检查是否有分摊
                let split_count = entity::split_records::Entity::find()
                    .filter(entity::split_records::Column::TransactionSerialNum.eq(&transaction.serial_num))
                    .count(db)
                    .await
                    .map_err(AppError::from_db_error)?;

                if split_count > 0 {
                    entry.shared_expense += transaction.amount;
                    entry.split_count += split_count as i64;
                }
            }
        }

        let mut trends: Vec<TrendAnalysis> = period_map
            .into_iter()
            .map(|(period, data)| {
                let average_amount = if data.transaction_count > 0 {
                    (data.total_income + data.total_expense) / Decimal::from(data.transaction_count)
                } else {
                    Decimal::ZERO
                };

                TrendAnalysis {
                    period,
                    total_income: data.total_income,
                    total_expense: data.total_expense,
                    shared_expense: data.shared_expense,
                    net_balance: data.total_income - data.total_expense,
                    transaction_count: data.transaction_count,
                    split_count: data.split_count,
                    average_transaction_amount: average_amount,
                }
            })
            .collect();

        trends.sort_by(|a, b| a.period.cmp(&b.period));
        Ok(trends)
    }

    /// 获取债务分析
    pub async fn get_debt_analysis(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
    ) -> MijiResult<DebtAnalysis> {
        let debt_stats = self.debt_service.get_debt_statistics(db, family_ledger_serial_num).await?;
        let settlement_stats = self.settlement_service.get_settlement_statistics(db, family_ledger_serial_num).await?;

        // 获取成员债务分布
        let members = entity::family_ledger_member::Entity::find()
            .find_also_related(entity::family_member::Entity)
            .filter(entity::family_ledger_member::Column::FamilyLedgerSerialNum.eq(family_ledger_serial_num))
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let mut debt_distribution = Vec::new();
        for (_, member_opt) in members {
            if let Some(member) = member_opt {
                let summary = self.debt_service.get_member_debt_summary(
                    db,
                    family_ledger_serial_num,
                    &member.serial_num,
                ).await?;

                debt_distribution.push(MemberDebtDistribution {
                    member_serial_num: member.serial_num,
                    member_name: member.name,
                    as_creditor: summary.total_credit,
                    as_debtor: summary.total_debt,
                    net_position: summary.net_balance,
                    debt_relationships: (summary.active_credits + summary.active_debts) as i32,
                });
            }
        }

        // 计算结算效率
        let settlement_efficiency = if debt_stats.total_debts > 0 {
            (Decimal::from(debt_stats.settled_debts) / Decimal::from(debt_stats.total_debts)) * Decimal::from(100)
        } else {
            Decimal::ZERO
        };

        // 计算待结算金额
        let pending_settlement_amount = debt_stats.active_amount;

        Ok(DebtAnalysis {
            total_active_debt: debt_stats.active_amount,
            total_settled_debt: debt_stats.settled_amount,
            average_debt_amount: if debt_stats.total_debts > 0 {
                debt_stats.total_amount / Decimal::from(debt_stats.total_debts)
            } else {
                Decimal::ZERO
            },
            debt_distribution,
            settlement_efficiency,
            pending_settlement_amount,
        })
    }

    /// 计算单个成员的贡献
    async fn calculate_member_contribution(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        member: &entity::family_member::Model,
        period_start: NaiveDate,
        period_end: NaiveDate,
    ) -> MijiResult<MemberContribution> {
        // 获取成员的账户
        let accounts = entity::account::Entity::find()
            .filter(entity::account::Column::OwnerId.eq(&member.serial_num))
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let account_ids: Vec<String> = accounts.iter().map(|a| a.serial_num.clone()).collect();

        // 获取成员的交易
        let transactions = entity::transactions::Entity::find()
            .filter(
                Condition::all()
                    .add(entity::transactions::Column::AccountSerialNum.is_in(&account_ids))
                    .add(entity::transactions::Column::Date.between(period_start, period_end))
            )
            .all(db)
            .await
            .map_err(AppError::from_db_error)?;

        let mut total_income = Decimal::ZERO;
        let mut total_expense = Decimal::ZERO;
        let mut shared_expense = Decimal::ZERO;
        let mut personal_expense = Decimal::ZERO;

        for transaction in &transactions {
            if transaction.transaction_type == "Income" {
                total_income += transaction.amount;
            } else if transaction.transaction_type == "Expense" {
                total_expense += transaction.amount;

                // 检查是否有分摊
                let has_split = entity::split_records::Entity::find()
                    .filter(entity::split_records::Column::TransactionSerialNum.eq(&transaction.serial_num))
                    .count(db)
                    .await
                    .map_err(AppError::from_db_error)? > 0;

                if has_split {
                    shared_expense += transaction.amount;
                } else {
                    personal_expense += transaction.amount;
                }
            }
        }

        // 获取分摊统计
        let split_summary = self.split_service.get_member_summary(
            db,
            family_ledger_serial_num,
            &member.serial_num,
            Some(period_start),
            Some(period_end),
        ).await?;

        Ok(MemberContribution {
            member_serial_num: member.serial_num.clone(),
            member_name: member.name.clone(),
            total_income,
            total_expense,
            shared_expense,
            personal_expense,
            split_paid: split_summary.total_paid,
            split_owed: split_summary.total_owed,
            net_contribution: total_income - total_expense + split_summary.net_balance,
            contribution_percentage: Decimal::ZERO, // 在调用方计算
            transaction_count: transactions.len() as i64,
        })
    }
}

/// 内部数据结构
#[derive(Debug)]
struct CategoryData {
    total_amount: Decimal,
    transaction_count: i64,
    member_distribution: HashMap<String, Decimal>,
}

#[derive(Debug)]
struct TrendData {
    total_income: Decimal,
    total_expense: Decimal,
    shared_expense: Decimal,
    transaction_count: i64,
    split_count: i64,
}
