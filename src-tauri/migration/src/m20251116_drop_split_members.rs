use sea_orm_migration::prelude::*;

/// 迁移：删除 transactions 表的 split_members 列
/// 
/// 背景：
/// - 所有历史数据的 split_members 都为空
/// - split_records 表已成为唯一数据源
/// - 删除 JSON 字段简化架构，提升性能
/// 
/// 时间：2025-11-16
#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 由于所有数据都为空，可以直接删除列
        // 无需数据迁移或验证步骤
        
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .drop_column(Transactions::SplitMembers)
                    .to_owned()
            )
            .await?;
        
        println!("✅ 成功删除 transactions.split_members 列");
        println!("📊 现在所有分摊数据只存储在 split_records 表");
        
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 回滚：重新添加列（通常不需要，但保留以防万一）
        
        manager
            .alter_table(
                Table::alter()
                    .table(Transactions::Table)
                    .add_column(
                        ColumnDef::new(Transactions::SplitMembers)
                            .json()
                            .null()
                            .comment("分摊成员（已废弃，使用 split_records 表）")
                    )
                    .to_owned()
            )
            .await?;
        
        println!("⚠️ 回滚：重新添加了 split_members 列");
        
        Ok(())
    }
}

#[derive(Iden)]
enum Transactions {
    Table,
    SplitMembers,
}

#[cfg(test)]
mod tests {
    use super::*;
    use sea_orm_migration::prelude::*;
    
    #[tokio::test]
    async fn test_migration() {
        // 测试迁移可以正常运行
        // 注意：这只是编译测试，实际运行需要数据库连接
    }
}
