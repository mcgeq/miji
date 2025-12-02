use sea_orm_migration::{prelude::*, sea_orm::prelude::Decimal};

use crate::schema::{Account, Currency, FamilyMember};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 account 表（包含所有字段）
        manager
            .create_table(
                Table::create()
                    .table(Account::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Account::SerialNum)
                            .string_len(38)
                            .not_null()
                            .primary_key(),
                    )
                    .col(
                        ColumnDef::new(Account::Name)
                            .string_len(200)
                            .not_null()
                            .unique_key(),
                    )
                    .col(ColumnDef::new(Account::Description).string_len(1000).null())
                    .col(ColumnDef::new(Account::Type).string().not_null())
                    .col(
                        ColumnDef::new(Account::Balance)
                            .decimal_len(16, 4)
                            .not_null()
                            .default(Decimal::ZERO),
                    )
                    .col(
                        ColumnDef::new(Account::InitialBalance)
                            .decimal_len(16, 4)
                            .not_null()
                            .default(Decimal::ZERO),
                    )
                    .col(ColumnDef::new(Account::Currency).string_len(3).not_null())
                    .col(
                        ColumnDef::new(Account::IsShared)
                            .boolean()
                            .null()
                            .default(false),
                    )
                    .col(
                        ColumnDef::new(Account::IsVirtual)
                            .boolean()
                            .not_null()
                            .default(false),
                    )
                    .col(ColumnDef::new(Account::OwnerId).string_len(38))
                    .col(ColumnDef::new(Account::Color).string_len(7))
                    .col(
                        ColumnDef::new(Account::IsActive)
                            .boolean()
                            .not_null()
                            .default(true),
                    )
                    .col(
                        ColumnDef::new(Account::CreatedAt)
                            .timestamp_with_time_zone()
                            .not_null(),
                    )
                    .col(
                        ColumnDef::new(Account::UpdatedAt)
                            .timestamp_with_time_zone()
                            .null(),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_account_currency")
                            .from(Account::Table, Account::Currency)
                            .to(Currency::Table, Currency::Code)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .foreign_key(
                        ForeignKey::create()
                            .name("fk_account_owner")
                            .from(Account::Table, Account::OwnerId)
                            .to(FamilyMember::Table, FamilyMember::SerialNum)
                            .on_delete(ForeignKeyAction::Restrict)
                            .on_update(ForeignKeyAction::Cascade),
                    )
                    .to_owned(),
            )
            .await?;

        // 创建索引
        manager
            .create_index(
                Index::create()
                    .name("idx_account_owner")
                    .table(Account::Table)
                    .col(Account::OwnerId)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("idx_account_currency")
                    .table(Account::Table)
                    .col(Account::Currency)
                    .if_not_exists()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(Index::drop().name("idx_account_owner").to_owned())
            .await?;
        manager
            .drop_index(Index::drop().name("idx_account_currency").to_owned())
            .await?;
        manager
            .drop_table(Table::drop().table(Account::Table).to_owned())
            .await?;

        Ok(())
    }
}
