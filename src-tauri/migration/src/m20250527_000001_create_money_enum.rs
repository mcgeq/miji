use sea_orm_migration::prelude::{extension::postgres::Type, *};

use crate::money_scheme::{RepeatPeriod, TransactionStatus, TransactionType};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_type(
                Type::create()
                    .as_enum(TransactionType::Type)
                    .values(vec![
                        "Income",
                        "Expense",
                        "Transfer",
                        "Reimbursement",
                        "Gift",
                    ])
                    .to_owned(),
            )
            .await?;

        manager
            .create_type(
                Type::create()
                    .as_enum(TransactionStatus::Type)
                    .values(vec!["Pending", "Completed", "Reversed"])
                    .to_owned(),
            )
            .await?;

        manager
            .create_type(
                Type::create()
                    .as_enum(TransactionStatus::Type)
                    .values(vec![
                        "Cash",
                        "Bank",
                        "CreditCard",
                        "WeChat",
                        "Alipay",
                        "Investment",
                    ])
                    .to_owned(),
            )
            .await?;

        manager
            .create_type(
                Type::create()
                    .as_enum(RepeatPeriod::Type)
                    .values(vec!["Daily", "Weekly", "Monthy", "Quarterly", "Yearly"])
                    .to_owned(),
            )
            .await?;
        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除枚举类型
        manager
            .drop_type(Type::drop().name(TransactionType::Type).to_owned())
            .await?;

        Ok(())
    }
}
