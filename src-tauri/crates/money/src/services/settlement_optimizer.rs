use common::error::{AppError, MijiResult};
use sea_orm::prelude::Decimal;
use std::collections::HashMap;

use crate::dto::debt_relations::MemberDebtSummary;
use crate::dto::settlement_records::{
    OptimizedTransfer, SettlementDetailItem, SettlementSuggestion,
};

/// 结算优化器
#[derive(Debug)]
pub struct SettlementOptimizer;

/// 成员净余额
#[derive(Debug, Clone)]
pub struct MemberBalance {
    pub member_serial_num: String,
    pub member_name: String,
    pub net_balance: Decimal,
    pub is_creditor: bool, // true: 债权人(余额>0), false: 债务人(余额<0)
}

impl Default for SettlementOptimizer {
    fn default() -> Self {
        Self::new()
    }
}

impl SettlementOptimizer {
    /// 创建新的结算优化器实例
    pub fn new() -> Self {
        Self
    }

    /// 生成结算建议
    pub fn generate_settlement_suggestion(
        &self,
        member_summaries: Vec<MemberDebtSummary>,
        family_ledger_serial_num: String,
        period_start: chrono::NaiveDate,
        period_end: chrono::NaiveDate,
        currency: String,
    ) -> MijiResult<SettlementSuggestion> {
        // 转换为内部数据结构
        let member_balances: Vec<MemberBalance> = member_summaries
            .iter()
            .map(|summary| MemberBalance {
                member_serial_num: summary.member_serial_num.clone(),
                member_name: summary.member_name.clone(),
                net_balance: summary.net_balance,
                is_creditor: summary.net_balance > Decimal::ZERO,
            })
            .collect();

        // 计算优化转账
        let optimized_transfers = self.calculate_optimized_transfers(&member_balances)?;

        // 计算节省的转账次数
        let direct_transfer_count = self.calculate_direct_transfer_count(&member_balances);
        let optimized_transfer_count = optimized_transfers.len() as i32;
        let estimated_savings = Decimal::from(direct_transfer_count - optimized_transfer_count);

        // 构建结算详情
        let settlement_details: Vec<SettlementDetailItem> = member_summaries
            .into_iter()
            .map(|summary| SettlementDetailItem {
                member_serial_num: summary.member_serial_num,
                member_name: summary.member_name,
                total_paid: summary.total_credit,
                total_owed: summary.total_debt,
                net_balance: summary.net_balance,
                transactions_count: summary.active_credits + summary.active_debts,
            })
            .collect();

        let total_amount: Decimal = settlement_details
            .iter()
            .map(|d| d.total_paid.max(d.total_owed))
            .sum();

        Ok(SettlementSuggestion {
            family_ledger_serial_num,
            period_start,
            period_end,
            total_amount,
            currency,
            participant_count: settlement_details.len() as i32,
            settlement_details,
            optimized_transfers,
            transfer_count: optimized_transfer_count,
            estimated_savings,
        })
    }

    /// 计算优化转账方案（最小转账次数算法）
    pub fn calculate_optimized_transfers(
        &self,
        member_balances: &[MemberBalance],
    ) -> MijiResult<Vec<OptimizedTransfer>> {
        // 分离债权人和债务人
        let mut creditors: Vec<MemberBalance> = member_balances
            .iter()
            .filter(|m| m.net_balance > Decimal::ZERO)
            .cloned()
            .collect();

        let mut debtors: Vec<MemberBalance> = member_balances
            .iter()
            .filter(|m| m.net_balance < Decimal::ZERO)
            .map(|m| MemberBalance {
                member_serial_num: m.member_serial_num.clone(),
                member_name: m.member_name.clone(),
                net_balance: -m.net_balance, // 转为正数便于计算
                is_creditor: false,
            })
            .collect();

        // 验证余额平衡
        let total_credit: Decimal = creditors.iter().map(|c| c.net_balance).sum();
        let total_debt: Decimal = debtors.iter().map(|d| d.net_balance).sum();

        if (total_credit - total_debt).abs() > Decimal::new(1, 2) {
            return Err(AppError::simple(
                common::BusinessCode::ValidationError,
                format!(
                    "债权债务不平衡: 债权总额 {} vs 债务总额 {}",
                    total_credit, total_debt
                ),
            ));
        }

        // 按金额降序排序
        creditors.sort_by(|a, b| b.net_balance.cmp(&a.net_balance));
        debtors.sort_by(|a, b| b.net_balance.cmp(&a.net_balance));

        let mut transfers = Vec::new();
        let mut creditor_idx = 0;
        let mut debtor_idx = 0;

        // 贪心算法：大债权对大债务
        while creditor_idx < creditors.len() && debtor_idx < debtors.len() {
            let creditor = &mut creditors[creditor_idx];
            let debtor = &mut debtors[debtor_idx];

            if creditor.net_balance == Decimal::ZERO {
                creditor_idx += 1;
                continue;
            }

            if debtor.net_balance == Decimal::ZERO {
                debtor_idx += 1;
                continue;
            }

            // 计算转账金额（取较小值）
            let transfer_amount = creditor.net_balance.min(debtor.net_balance);

            transfers.push(OptimizedTransfer {
                from_member: debtor.member_serial_num.clone(),
                from_member_name: debtor.member_name.clone(),
                to_member: creditor.member_serial_num.clone(),
                to_member_name: creditor.member_name.clone(),
                amount: transfer_amount,
                currency: "CNY".to_string(), // 默认货币
                description: Some(format!(
                    "{} 向 {} 转账 {}",
                    debtor.member_name, creditor.member_name, transfer_amount
                )),
            });

            // 更新余额
            creditor.net_balance -= transfer_amount;
            debtor.net_balance -= transfer_amount;

            // 如果某一方余额为0，移动到下一个
            if creditor.net_balance == Decimal::ZERO {
                creditor_idx += 1;
            }
            if debtor.net_balance == Decimal::ZERO {
                debtor_idx += 1;
            }
        }

        Ok(transfers)
    }

    /// 计算直接转账次数（不优化的情况下）
    fn calculate_direct_transfer_count(&self, member_balances: &[MemberBalance]) -> i32 {
        let creditor_count = member_balances
            .iter()
            .filter(|m| m.net_balance > Decimal::ZERO)
            .count() as i32;

        let debtor_count = member_balances
            .iter()
            .filter(|m| m.net_balance < Decimal::ZERO)
            .count() as i32;

        // 在最坏情况下，每个债务人都需要向每个债权人转账
        creditor_count * debtor_count
    }

    /// 使用图论算法进一步优化转账（适用于复杂场景）
    pub fn optimize_with_graph_algorithm(
        &self,
        transfers: Vec<OptimizedTransfer>,
    ) -> MijiResult<Vec<OptimizedTransfer>> {
        // 构建图结构
        let mut graph: HashMap<String, HashMap<String, Decimal>> = HashMap::new();

        for transfer in &transfers {
            graph
                .entry(transfer.from_member.clone())
                .or_default()
                .insert(transfer.to_member.clone(), transfer.amount);
        }

        // 使用Floyd-Warshall算法寻找最短路径
        let members: Vec<String> = graph.keys().cloned().collect();
        let n = members.len();

        if n <= 2 {
            return Ok(transfers); // 小规模直接返回
        }

        // 初始化距离矩阵
        let mut dist = vec![vec![Decimal::MAX; n]; n];
        let mut next = vec![vec![None; n]; n];

        for (i, member_i) in members.iter().enumerate() {
            dist[i][i] = Decimal::ZERO;

            if let Some(edges) = graph.get(member_i) {
                for (member_j, &weight) in edges {
                    if let Some(j) = members.iter().position(|m| m == member_j) {
                        dist[i][j] = weight;
                        next[i][j] = Some(j);
                    }
                }
            }
        }

        // Floyd-Warshall算法
        for k in 0..n {
            for i in 0..n {
                for j in 0..n {
                    if dist[i][k] != Decimal::MAX && dist[k][j] != Decimal::MAX {
                        let new_dist = dist[i][k] + dist[k][j];
                        if new_dist < dist[i][j] {
                            dist[i][j] = new_dist;
                            next[i][j] = next[i][k];
                        }
                    }
                }
            }
        }

        // 重构优化后的转账路径
        let mut optimized_transfers = Vec::new();

        for transfer in transfers {
            let from_idx = members.iter().position(|m| m == &transfer.from_member);
            let to_idx = members.iter().position(|m| m == &transfer.to_member);

            if let (Some(from), Some(to)) = (from_idx, to_idx) {
                if let Some(path) = self.reconstruct_path(&next, from, to) {
                    // 如果路径长度 > 2，说明有中间节点，可以优化
                    if path.len() > 2 {
                        for window in path.windows(2) {
                            let from_member = &members[window[0]];
                            let to_member = &members[window[1]];

                            optimized_transfers.push(OptimizedTransfer {
                                from_member: from_member.clone(),
                                from_member_name: from_member.clone(), // 简化处理
                                to_member: to_member.clone(),
                                to_member_name: to_member.clone(),
                                amount: transfer.amount,
                                currency: transfer.currency.clone(),
                                description: Some(format!(
                                    "优化路径: {} -> {}",
                                    from_member, to_member
                                )),
                            });
                        }
                    } else {
                        optimized_transfers.push(transfer);
                    }
                } else {
                    optimized_transfers.push(transfer);
                }
            }
        }

        Ok(optimized_transfers)
    }

    /// 重构路径
    fn reconstruct_path(
        &self,
        next: &[Vec<Option<usize>>],
        from: usize,
        to: usize,
    ) -> Option<Vec<usize>> {
        if next[from][to].is_none() {
            return None;
        }

        let mut path = vec![from];
        let mut current = from;

        while current != to {
            if let Some(next_node) = next[current][to] {
                current = next_node;
                path.push(current);
            } else {
                return None;
            }
        }

        Some(path)
    }

    /// 验证转账方案的正确性
    pub fn validate_transfers(
        &self,
        member_balances: &[MemberBalance],
        transfers: &[OptimizedTransfer],
    ) -> MijiResult<()> {
        let mut net_changes: HashMap<String, Decimal> = HashMap::new();

        // 计算每个成员的净变化
        for transfer in transfers {
            *net_changes
                .entry(transfer.from_member.clone())
                .or_insert(Decimal::ZERO) -= transfer.amount;
            *net_changes
                .entry(transfer.to_member.clone())
                .or_insert(Decimal::ZERO) += transfer.amount;
        }

        // 验证每个成员的最终余额是否为0
        for member in member_balances {
            let net_change = net_changes
                .get(&member.member_serial_num)
                .copied()
                .unwrap_or(Decimal::ZERO);
            let final_balance = member.net_balance + net_change;

            if final_balance.abs() > Decimal::new(1, 2) {
                return Err(AppError::simple(
                    common::BusinessCode::ValidationError,
                    format!(
                        "成员 {} 的最终余额不为零: {}",
                        member.member_name, final_balance
                    ),
                ));
            }
        }

        Ok(())
    }

    /// 计算转账方案的效率指标
    pub fn calculate_efficiency_metrics(
        &self,
        member_balances: &[MemberBalance],
        transfers: &[OptimizedTransfer],
    ) -> MijiResult<EfficiencyMetrics> {
        let direct_count = self.calculate_direct_transfer_count(member_balances);
        let optimized_count = transfers.len() as i32;
        let reduction_rate = if direct_count > 0 {
            (Decimal::from(direct_count - optimized_count) / Decimal::from(direct_count))
                * Decimal::ONE_HUNDRED
        } else {
            Decimal::ZERO
        };

        let total_amount: Decimal = transfers.iter().map(|t| t.amount).sum();
        let average_amount = if !transfers.is_empty() {
            total_amount / Decimal::from(transfers.len())
        } else {
            Decimal::ZERO
        };

        Ok(EfficiencyMetrics {
            direct_transfer_count: direct_count,
            optimized_transfer_count: optimized_count,
            reduction_count: direct_count - optimized_count,
            reduction_rate,
            total_transfer_amount: total_amount,
            average_transfer_amount: average_amount,
        })
    }
}

/// 效率指标
#[derive(Debug, Clone)]
pub struct EfficiencyMetrics {
    pub direct_transfer_count: i32,
    pub optimized_transfer_count: i32,
    pub reduction_count: i32,
    pub reduction_rate: Decimal, // 减少比例（百分比）
    pub total_transfer_amount: Decimal,
    pub average_transfer_amount: Decimal,
}
