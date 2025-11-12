use common::error::{AppError, MijiResult};
use sea_orm::{ColumnTrait, DbConn, EntityTrait, QueryFilter};
use std::collections::HashSet;

/// 权限管理服务
#[derive(Debug)]
pub struct PermissionService;

/// 权限检查结果
#[derive(Debug, Clone)]
pub struct PermissionCheckResult {
    pub has_permission: bool,
    pub member_role: String,
    pub permissions: Vec<String>,
    pub reason: Option<String>,
}

impl PermissionService {
    pub fn new() -> Self {
        Self
    }

    /// 检查成员是否有指定权限
    pub async fn check_permission(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        user_id: &str,
        required_permission: &str,
    ) -> MijiResult<PermissionCheckResult> {
        // 获取用户在该账本中的成员信息
        let member = self
            .get_member_by_user_id(db, family_ledger_serial_num, user_id)
            .await?;

        if let Some(member) = member {
            let permissions = self.parse_permissions(&member.permissions)?;
            let has_permission =
                self.has_permission(&member.role, &permissions, required_permission);

            Ok(PermissionCheckResult {
                has_permission,
                member_role: member.role.clone(),
                permissions,
                reason: if !has_permission {
                    Some(format!("缺少权限: {}", required_permission))
                } else {
                    None
                },
            })
        } else {
            Ok(PermissionCheckResult {
                has_permission: false,
                member_role: "None".to_string(),
                permissions: Vec::new(),
                reason: Some("用户不是该账本的成员".to_string()),
            })
        }
    }

    /// 检查多个权限
    pub async fn check_multiple_permissions(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        user_id: &str,
        required_permissions: &[&str],
    ) -> MijiResult<PermissionCheckResult> {
        let member = self
            .get_member_by_user_id(db, family_ledger_serial_num, user_id)
            .await?;

        if let Some(member) = member {
            let permissions = self.parse_permissions(&member.permissions)?;
            let missing_permissions: Vec<String> = required_permissions
                .iter()
                .filter(|&perm| !self.has_permission(&member.role, &permissions, perm))
                .map(|&perm| perm.to_string())
                .collect();

            let has_permission = missing_permissions.is_empty();

            Ok(PermissionCheckResult {
                has_permission,
                member_role: member.role.clone(),
                permissions,
                reason: if !has_permission {
                    Some(format!("缺少权限: {}", missing_permissions.join(", ")))
                } else {
                    None
                },
            })
        } else {
            Ok(PermissionCheckResult {
                has_permission: false,
                member_role: "None".to_string(),
                permissions: Vec::new(),
                reason: Some("用户不是该账本的成员".to_string()),
            })
        }
    }

    /// 获取角色的默认权限
    pub fn get_role_default_permissions(&self, role: &str) -> Vec<String> {
        match role {
            "Owner" => vec![
                // 账本权限
                "ledger:view",
                "ledger:edit",
                "ledger:delete",
                "ledger:manage",
                // 成员权限
                "member:view",
                "member:add",
                "member:edit",
                "member:remove",
                // 交易权限
                "transaction:view",
                "transaction:add",
                "transaction:edit",
                "transaction:delete",
                // 分摊权限
                "split:view",
                "split:create",
                "split:edit",
                "split:confirm",
                // 结算权限
                "settlement:view",
                "settlement:initiate",
                "settlement:complete",
                // 统计权限
                "stats:view",
                "stats:export",
            ]
            .iter()
            .map(|s| s.to_string())
            .collect(),

            "Admin" => vec![
                // 账本权限（除删除外）
                "ledger:view",
                "ledger:edit",
                "ledger:manage",
                // 成员权限
                "member:view",
                "member:add",
                "member:edit",
                // 交易权限
                "transaction:view",
                "transaction:add",
                "transaction:edit",
                "transaction:delete",
                // 分摊权限
                "split:view",
                "split:create",
                "split:edit",
                "split:confirm",
                // 结算权限
                "settlement:view",
                "settlement:initiate",
                "settlement:complete",
                // 统计权限
                "stats:view",
                "stats:export",
            ]
            .iter()
            .map(|s| s.to_string())
            .collect(),

            "Member" => vec![
                // 账本权限（仅查看）
                "ledger:view",
                // 成员权限（仅查看）
                "member:view",
                // 交易权限
                "transaction:view",
                "transaction:add",
                "transaction:edit",
                // 分摊权限
                "split:view",
                "split:create",
                "split:confirm",
                // 结算权限（仅查看）
                "settlement:view",
                // 统计权限（仅查看）
                "stats:view",
            ]
            .iter()
            .map(|s| s.to_string())
            .collect(),

            "Viewer" => vec![
                // 仅查看权限
                "ledger:view",
                "member:view",
                "transaction:view",
                "split:view",
                "settlement:view",
                "stats:view",
            ]
            .iter()
            .map(|s| s.to_string())
            .collect(),

            _ => Vec::new(),
        }
    }

    /// 更新成员权限
    pub async fn update_member_permissions(
        &self,
        db: &DbConn,
        member_serial_num: &str,
        permissions: Vec<String>,
    ) -> MijiResult<()> {
        let permissions_json = serde_json::to_string(&permissions).map_err(|e| {
            AppError::simple(
                common::BusinessCode::ValidationError,
                format!("权限序列化失败: {}", e),
            )
        })?;

        entity::family_member::Entity::update_many()
            .col_expr(
                entity::family_member::Column::Permissions,
                sea_orm::sea_query::Expr::value(permissions_json),
            )
            .filter(entity::family_member::Column::SerialNum.eq(member_serial_num))
            .exec(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        Ok(())
    }

    /// 验证权限配置的有效性
    pub fn validate_permissions(&self, permissions: &[String]) -> MijiResult<()> {
        let valid_permissions = self.get_all_valid_permissions();

        for permission in permissions {
            if !valid_permissions.contains(permission) {
                return Err(AppError::simple(
                    common::BusinessCode::ValidationError,
                    format!("无效的权限: {}", permission),
                ));
            }
        }

        Ok(())
    }

    /// 获取所有有效权限列表
    pub fn get_all_valid_permissions(&self) -> HashSet<String> {
        vec![
            // 账本权限
            "ledger:view",
            "ledger:edit",
            "ledger:delete",
            "ledger:manage",
            // 成员权限
            "member:view",
            "member:add",
            "member:edit",
            "member:remove",
            // 交易权限
            "transaction:view",
            "transaction:add",
            "transaction:edit",
            "transaction:delete",
            // 分摊权限
            "split:view",
            "split:create",
            "split:edit",
            "split:confirm",
            // 结算权限
            "settlement:view",
            "settlement:initiate",
            "settlement:complete",
            // 统计权限
            "stats:view",
            "stats:export",
        ]
        .iter()
        .map(|s| s.to_string())
        .collect()
    }

    /// 获取权限分组
    pub fn get_permission_groups(&self) -> Vec<PermissionGroup> {
        vec![
            PermissionGroup {
                name: "账本管理".to_string(),
                permissions: vec![
                    PermissionInfo {
                        code: "ledger:view".to_string(),
                        name: "查看账本".to_string(),
                    },
                    PermissionInfo {
                        code: "ledger:edit".to_string(),
                        name: "编辑账本".to_string(),
                    },
                    PermissionInfo {
                        code: "ledger:delete".to_string(),
                        name: "删除账本".to_string(),
                    },
                    PermissionInfo {
                        code: "ledger:manage".to_string(),
                        name: "管理账本".to_string(),
                    },
                ],
            },
            PermissionGroup {
                name: "成员管理".to_string(),
                permissions: vec![
                    PermissionInfo {
                        code: "member:view".to_string(),
                        name: "查看成员".to_string(),
                    },
                    PermissionInfo {
                        code: "member:add".to_string(),
                        name: "添加成员".to_string(),
                    },
                    PermissionInfo {
                        code: "member:edit".to_string(),
                        name: "编辑成员".to_string(),
                    },
                    PermissionInfo {
                        code: "member:remove".to_string(),
                        name: "移除成员".to_string(),
                    },
                ],
            },
            PermissionGroup {
                name: "交易管理".to_string(),
                permissions: vec![
                    PermissionInfo {
                        code: "transaction:view".to_string(),
                        name: "查看交易".to_string(),
                    },
                    PermissionInfo {
                        code: "transaction:add".to_string(),
                        name: "添加交易".to_string(),
                    },
                    PermissionInfo {
                        code: "transaction:edit".to_string(),
                        name: "编辑交易".to_string(),
                    },
                    PermissionInfo {
                        code: "transaction:delete".to_string(),
                        name: "删除交易".to_string(),
                    },
                ],
            },
            PermissionGroup {
                name: "分摊管理".to_string(),
                permissions: vec![
                    PermissionInfo {
                        code: "split:view".to_string(),
                        name: "查看分摊".to_string(),
                    },
                    PermissionInfo {
                        code: "split:create".to_string(),
                        name: "创建分摊".to_string(),
                    },
                    PermissionInfo {
                        code: "split:edit".to_string(),
                        name: "编辑分摊".to_string(),
                    },
                    PermissionInfo {
                        code: "split:confirm".to_string(),
                        name: "确认分摊".to_string(),
                    },
                ],
            },
            PermissionGroup {
                name: "结算管理".to_string(),
                permissions: vec![
                    PermissionInfo {
                        code: "settlement:view".to_string(),
                        name: "查看结算".to_string(),
                    },
                    PermissionInfo {
                        code: "settlement:initiate".to_string(),
                        name: "发起结算".to_string(),
                    },
                    PermissionInfo {
                        code: "settlement:complete".to_string(),
                        name: "完成结算".to_string(),
                    },
                ],
            },
            PermissionGroup {
                name: "统计分析".to_string(),
                permissions: vec![
                    PermissionInfo {
                        code: "stats:view".to_string(),
                        name: "查看统计".to_string(),
                    },
                    PermissionInfo {
                        code: "stats:export".to_string(),
                        name: "导出数据".to_string(),
                    },
                ],
            },
        ]
    }

    /// 检查是否有权限
    fn has_permission(
        &self,
        role: &str,
        permissions: &[String],
        required_permission: &str,
    ) -> bool {
        // Owner 拥有所有权限
        if role == "Owner" {
            return true;
        }

        // 检查显式权限
        if permissions.contains(&required_permission.to_string()) {
            return true;
        }

        // 检查角色默认权限
        let role_permissions = self.get_role_default_permissions(role);
        role_permissions.contains(&required_permission.to_string())
    }

    /// 解析权限字符串
    fn parse_permissions(&self, permissions_str: &str) -> MijiResult<Vec<String>> {
        if permissions_str.is_empty() {
            return Ok(Vec::new());
        }

        serde_json::from_str::<Vec<String>>(permissions_str)
            .or_else(|_| {
                // 兼容旧格式（逗号分隔）
                Ok(permissions_str
                    .split(',')
                    .map(|s| s.trim().to_string())
                    .filter(|s| !s.is_empty())
                    .collect())
            })
            .map_err(|e: serde_json::Error| {
                AppError::simple(
                    common::BusinessCode::ValidationError,
                    format!("权限格式错误: {}", e),
                )
            })
    }

    /// 根据用户ID获取成员信息
    async fn get_member_by_user_id(
        &self,
        db: &DbConn,
        family_ledger_serial_num: &str,
        user_id: &str,
    ) -> MijiResult<Option<entity::family_member::Model>> {
        // 通过家庭账本成员关联表查找
        let member_relation = entity::family_ledger_member::Entity::find()
            .filter(
                entity::family_ledger_member::Column::FamilyLedgerSerialNum
                    .eq(family_ledger_serial_num),
            )
            .find_also_related(entity::family_member::Entity)
            .all(db)
            .await
            .map_err(|e| {
                AppError::simple(
                    common::BusinessCode::DatabaseError,
                    format!("Database error: {}", e),
                )
            })?;

        for (_, member_opt) in member_relation {
            if let Some(member) = member_opt {
                if let Some(member_user_id) = &member.user_id {
                    if member_user_id == user_id {
                        return Ok(Some(member));
                    }
                }
            }
        }

        Ok(None)
    }
}

/// 权限信息
#[derive(Debug, Clone)]
pub struct PermissionInfo {
    pub code: String,
    pub name: String,
}

/// 权限分组
#[derive(Debug, Clone)]
pub struct PermissionGroup {
    pub name: String,
    pub permissions: Vec<PermissionInfo>,
}
