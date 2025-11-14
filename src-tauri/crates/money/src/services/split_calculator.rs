use common::error::{AppError, MijiResult};
use sea_orm::prelude::Decimal;
use serde_json::Value as JsonValue;
use std::collections::HashMap;
use std::str::FromStr;

/// 分摊计算引擎
#[derive(Debug)]
pub struct SplitCalculator;

/// 分摊计算结果
#[derive(Debug, Clone)]
pub struct SplitCalculationResult {
    pub total_amount: Decimal,
    pub split_records: Vec<SplitRecordItem>,
    pub validation_errors: Vec<String>,
}

/// 分摊记录项
#[derive(Debug, Clone)]
pub struct SplitRecordItem {
    pub payer_member_serial_num: String,
    pub owe_member_serial_num: String,
    pub split_amount: Decimal,
    pub split_percentage: Option<Decimal>,
    pub split_type: String,
    pub description: Option<String>,
}

impl Default for SplitCalculator {
    fn default() -> Self {
        Self::new()
    }
}

impl SplitCalculator {
    /// 创建新的分摊计算器实例
    pub fn new() -> Self {
        Self
    }

    /// 根据分摊规则计算分摊结果
    pub fn calculate_split(
        &self,
        total_amount: Decimal,
        payer_member_serial_num: &str,
        rule_type: &str,
        rule_config: &JsonValue,
        participant_members: &JsonValue,
    ) -> MijiResult<SplitCalculationResult> {
        match rule_type {
            "Equal" => self.calculate_equal_split(
                total_amount,
                payer_member_serial_num,
                participant_members,
            ),
            "Percentage" => self.calculate_percentage_split(
                total_amount,
                payer_member_serial_num,
                rule_config,
                participant_members,
            ),
            "FixedAmount" => self.calculate_fixed_amount_split(
                total_amount,
                payer_member_serial_num,
                rule_config,
                participant_members,
            ),
            "Weighted" => self.calculate_weighted_split(
                total_amount,
                payer_member_serial_num,
                rule_config,
                participant_members,
            ),
            "Custom" => self.calculate_custom_split(
                total_amount,
                payer_member_serial_num,
                rule_config,
                participant_members,
            ),
            _ => Err(AppError::simple(
                common::BusinessCode::ValidationError,
                "不支持的分摊规则类型",
            )),
        }
    }

    /// 均摊计算
    fn calculate_equal_split(
        &self,
        total_amount: Decimal,
        payer_member_serial_num: &str,
        participant_members: &JsonValue,
    ) -> MijiResult<SplitCalculationResult> {
        let participants = self.parse_participants(participant_members)?;

        if participants.is_empty() {
            return Err(AppError::simple(
                common::BusinessCode::ValidationError,
                "参与成员不能为空",
            ));
        }

        let participant_count = Decimal::from(participants.len());
        let base_amount = total_amount / participant_count;

        // 处理余数分配
        let remainder = total_amount % participant_count;
        let mut split_records = Vec::new();
        let mut allocated_remainder = Decimal::ZERO;

        for participant in participants.iter() {
            let mut split_amount = base_amount;

            // 将余数分配给前几个参与者
            if allocated_remainder < remainder {
                split_amount += Decimal::new(1, 2); // 加0.01
                allocated_remainder += Decimal::new(1, 2);
            }

            // 跳过付款人自己
            if participant != payer_member_serial_num {
                split_records.push(SplitRecordItem {
                    payer_member_serial_num: payer_member_serial_num.to_string(),
                    owe_member_serial_num: participant.clone(),
                    split_amount,
                    split_percentage: Some(Decimal::ONE_HUNDRED / participant_count),
                    split_type: "Equal".to_string(),
                    description: Some("均摊".to_string()),
                });
            }
        }

        Ok(SplitCalculationResult {
            total_amount,
            split_records,
            validation_errors: Vec::new(),
        })
    }

    /// 按比例分摊计算
    fn calculate_percentage_split(
        &self,
        total_amount: Decimal,
        payer_member_serial_num: &str,
        rule_config: &JsonValue,
        participant_members: &JsonValue,
    ) -> MijiResult<SplitCalculationResult> {
        let participants = self.parse_participants(participant_members)?;
        let percentages = self.parse_percentages(rule_config)?;

        let mut split_records = Vec::new();
        let mut validation_errors = Vec::new();
        let mut total_percentage = Decimal::ZERO;

        for participant in &participants {
            if let Some(&percentage) = percentages.get(participant) {
                total_percentage += percentage;

                // 跳过付款人自己
                if participant != payer_member_serial_num {
                    let split_amount = total_amount * percentage / Decimal::ONE_HUNDRED;

                    split_records.push(SplitRecordItem {
                        payer_member_serial_num: payer_member_serial_num.to_string(),
                        owe_member_serial_num: participant.clone(),
                        split_amount: split_amount.round_dp(2),
                        split_percentage: Some(percentage),
                        split_type: "Percentage".to_string(),
                        description: Some(format!("按比例分摊 ({}%)", percentage)),
                    });
                }
            } else {
                validation_errors.push(format!("成员 {} 缺少分摊比例配置", participant));
            }
        }

        // 验证比例总和
        if (total_percentage - Decimal::ONE_HUNDRED).abs() > Decimal::new(1, 2) {
            validation_errors.push(format!(
                "分摊比例总和为 {}%，应该等于 100%",
                total_percentage
            ));
        }

        Ok(SplitCalculationResult {
            total_amount,
            split_records,
            validation_errors,
        })
    }

    /// 固定金额分摊计算
    fn calculate_fixed_amount_split(
        &self,
        total_amount: Decimal,
        payer_member_serial_num: &str,
        rule_config: &JsonValue,
        participant_members: &JsonValue,
    ) -> MijiResult<SplitCalculationResult> {
        let participants = self.parse_participants(participant_members)?;
        let amounts = self.parse_amounts(rule_config)?;

        let mut split_records = Vec::new();
        let mut validation_errors = Vec::new();
        let mut total_allocated = Decimal::ZERO;

        for participant in &participants {
            if let Some(&amount) = amounts.get(participant) {
                total_allocated += amount;

                // 跳过付款人自己
                if participant != payer_member_serial_num {
                    split_records.push(SplitRecordItem {
                        payer_member_serial_num: payer_member_serial_num.to_string(),
                        owe_member_serial_num: participant.clone(),
                        split_amount: amount,
                        split_percentage: Some(amount / total_amount * Decimal::ONE_HUNDRED),
                        split_type: "FixedAmount".to_string(),
                        description: Some(format!("固定金额分摊 ({})", amount)),
                    });
                }
            } else {
                validation_errors.push(format!("成员 {} 缺少固定金额配置", participant));
            }
        }

        // 验证金额总和
        if total_allocated != total_amount {
            validation_errors.push(format!(
                "固定金额总和为 {}，与交易金额 {} 不匹配",
                total_allocated, total_amount
            ));
        }

        Ok(SplitCalculationResult {
            total_amount,
            split_records,
            validation_errors,
        })
    }

    /// 权重分摊计算
    fn calculate_weighted_split(
        &self,
        total_amount: Decimal,
        payer_member_serial_num: &str,
        rule_config: &JsonValue,
        participant_members: &JsonValue,
    ) -> MijiResult<SplitCalculationResult> {
        let participants = self.parse_participants(participant_members)?;
        let weights = self.parse_weights(rule_config)?;

        let mut split_records = Vec::new();
        let mut validation_errors = Vec::new();

        // 计算总权重
        let total_weight: Decimal = weights.values().sum();

        if total_weight == Decimal::ZERO {
            return Err(AppError::simple(
                common::BusinessCode::ValidationError,
                "权重总和不能为零",
            ));
        }

        for participant in &participants {
            if let Some(&weight) = weights.get(participant) {
                // 跳过付款人自己
                if participant != payer_member_serial_num {
                    let percentage = weight / total_weight * Decimal::ONE_HUNDRED;
                    let split_amount = total_amount * weight / total_weight;

                    split_records.push(SplitRecordItem {
                        payer_member_serial_num: payer_member_serial_num.to_string(),
                        owe_member_serial_num: participant.clone(),
                        split_amount: split_amount.round_dp(2),
                        split_percentage: Some(percentage),
                        split_type: "Weighted".to_string(),
                        description: Some(format!("权重分摊 (权重: {})", weight)),
                    });
                }
            } else {
                validation_errors.push(format!("成员 {} 缺少权重配置", participant));
            }
        }

        Ok(SplitCalculationResult {
            total_amount,
            split_records,
            validation_errors,
        })
    }

    /// 自定义分摊计算
    fn calculate_custom_split(
        &self,
        total_amount: Decimal,
        payer_member_serial_num: &str,
        rule_config: &JsonValue,
        _participant_members: &JsonValue,
    ) -> MijiResult<SplitCalculationResult> {
        // 自定义规则直接从配置中读取分摊详情
        let custom_splits = rule_config
            .get("custom_splits")
            .and_then(|v| v.as_array())
            .ok_or_else(|| {
                AppError::simple(
                    common::BusinessCode::ValidationError,
                    "自定义规则缺少分摊配置",
                )
            })?;

        let mut split_records = Vec::new();
        let mut validation_errors = Vec::new();
        let mut total_allocated = Decimal::ZERO;

        for split_config in custom_splits {
            let member_id = split_config
                .get("member_id")
                .and_then(|v| v.as_str())
                .ok_or_else(|| {
                    AppError::simple(
                        common::BusinessCode::ValidationError,
                        "自定义分摊缺少成员ID",
                    )
                })?;

            let amount = split_config
                .get("amount")
                .and_then(|v| v.as_str())
                .and_then(|s| Decimal::from_str(s).ok())
                .ok_or_else(|| {
                    AppError::simple(
                        common::BusinessCode::ValidationError,
                        "自定义分摊金额格式错误",
                    )
                })?;

            total_allocated += amount;

            // 跳过付款人自己
            if member_id != payer_member_serial_num {
                let description = split_config
                    .get("description")
                    .and_then(|v| v.as_str())
                    .map(|s| s.to_string());

                split_records.push(SplitRecordItem {
                    payer_member_serial_num: payer_member_serial_num.to_string(),
                    owe_member_serial_num: member_id.to_string(),
                    split_amount: amount,
                    split_percentage: Some(amount / total_amount * Decimal::ONE_HUNDRED),
                    split_type: "Custom".to_string(),
                    description: description.or_else(|| Some("自定义分摊".to_string())),
                });
            }
        }

        // 验证金额总和
        if (total_allocated - total_amount).abs() > Decimal::new(1, 2) {
            validation_errors.push(format!(
                "自定义分摊总和为 {}，与交易金额 {} 不匹配",
                total_allocated, total_amount
            ));
        }

        Ok(SplitCalculationResult {
            total_amount,
            split_records,
            validation_errors,
        })
    }

    /// 解析参与成员列表
    fn parse_participants(&self, participant_members: &JsonValue) -> MijiResult<Vec<String>> {
        participant_members
            .as_array()
            .ok_or_else(|| {
                AppError::simple(common::BusinessCode::ValidationError, "参与成员格式错误")
            })?
            .iter()
            .map(|v| {
                v.as_str().map(|s| s.to_string()).ok_or_else(|| {
                    AppError::simple(common::BusinessCode::ValidationError, "参与成员ID格式错误")
                })
            })
            .collect()
    }

    /// 解析百分比配置
    fn parse_percentages(&self, rule_config: &JsonValue) -> MijiResult<HashMap<String, Decimal>> {
        let percentages_obj = rule_config
            .get("percentages")
            .and_then(|v| v.as_object())
            .ok_or_else(|| {
                AppError::simple(common::BusinessCode::ValidationError, "百分比配置格式错误")
            })?;

        let mut percentages = HashMap::new();
        for (member_id, percentage_value) in percentages_obj {
            let percentage = percentage_value
                .as_str()
                .and_then(|s| Decimal::from_str(s).ok())
                .or_else(|| {
                    percentage_value
                        .as_f64()
                        .and_then(|f| Decimal::try_from(f).ok())
                })
                .ok_or_else(|| {
                    AppError::simple(common::BusinessCode::ValidationError, "百分比值格式错误")
                })?;

            percentages.insert(member_id.clone(), percentage);
        }

        Ok(percentages)
    }

    /// 解析金额配置
    fn parse_amounts(&self, rule_config: &JsonValue) -> MijiResult<HashMap<String, Decimal>> {
        let amounts_obj = rule_config
            .get("amounts")
            .and_then(|v| v.as_object())
            .ok_or_else(|| {
                AppError::simple(common::BusinessCode::ValidationError, "金额配置格式错误")
            })?;

        let mut amounts = HashMap::new();
        for (member_id, amount_value) in amounts_obj {
            let amount = amount_value
                .as_str()
                .and_then(|s| Decimal::from_str(s).ok())
                .or_else(|| {
                    amount_value
                        .as_f64()
                        .and_then(|f| Decimal::try_from(f).ok())
                })
                .ok_or_else(|| {
                    AppError::simple(common::BusinessCode::ValidationError, "金额值格式错误")
                })?;

            amounts.insert(member_id.clone(), amount);
        }

        Ok(amounts)
    }

    /// 解析权重配置
    fn parse_weights(&self, rule_config: &JsonValue) -> MijiResult<HashMap<String, Decimal>> {
        let weights_obj = rule_config
            .get("weights")
            .and_then(|v| v.as_object())
            .ok_or_else(|| {
                AppError::simple(common::BusinessCode::ValidationError, "权重配置格式错误")
            })?;

        let mut weights = HashMap::new();
        for (member_id, weight_value) in weights_obj {
            let weight = weight_value
                .as_str()
                .and_then(|s| Decimal::from_str(s).ok())
                .or_else(|| {
                    weight_value
                        .as_f64()
                        .and_then(|f| Decimal::try_from(f).ok())
                })
                .ok_or_else(|| {
                    AppError::simple(common::BusinessCode::ValidationError, "权重值格式错误")
                })?;

            weights.insert(member_id.clone(), weight);
        }

        Ok(weights)
    }

    /// 验证分摊结果
    pub fn validate_split_result(&self, result: &SplitCalculationResult) -> MijiResult<()> {
        if !result.validation_errors.is_empty() {
            return Err(AppError::simple(
                common::BusinessCode::ValidationError,
                format!("分摊计算验证失败: {}", result.validation_errors.join(", ")),
            ));
        }

        // 验证分摊金额总和
        let total_split: Decimal = result.split_records.iter().map(|r| r.split_amount).sum();

        if (total_split - result.total_amount).abs() > Decimal::new(1, 2) {
            return Err(AppError::simple(
                common::BusinessCode::ValidationError,
                format!(
                    "分摊金额总和 {} 与交易金额 {} 不匹配",
                    total_split, result.total_amount
                ),
            ));
        }

        Ok(())
    }
}
