use sea_orm_migration::prelude::{extension::postgres::Type, *};

use crate::money_scheme::{AccountType, RepeatPeriod, TransactionStatus, TransactionType};

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
                        Alias::new("Income"),
                        Alias::new("Expense"),
                        Alias::new("Transfer"),
                        Alias::new("Reimbursement"),
                        Alias::new("Gift"),
                    ])
                    .to_owned(),
            )
            .await?;

        manager
            .create_type(
                Type::create()
                    .as_enum(TransactionStatus::Type)
                    .values(vec![
                        Alias::new("Pending"),
                        Alias::new("Completed"),
                        Alias::new("Reversed"),
                    ])
                    .to_owned(),
            )
            .await?;

        manager
            .create_type(
                Type::create()
                    .as_enum(AccountType::Type)
                    .values(vec![
                        Alias::new("Cash"),
                        Alias::new("Bank"),
                        Alias::new("CreditCard"),
                        Alias::new("WeChat"),
                        Alias::new("Alipay"),
                        Alias::new("Investment"),
                    ])
                    .to_owned(),
            )
            .await?;

        manager
            .create_type(
                Type::create()
                    .as_enum(RepeatPeriod::Type)
                    .values(vec![
                        Alias::new("Daily"),
                        Alias::new("Weekly"),
                        Alias::new("Monthy"),
                        Alias::new("Quarterly"),
                        Alias::new("Yearly"),
                    ])
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
