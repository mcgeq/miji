use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 为 family_member 表的 name 字段添加唯一约束
        manager
            .create_index(
                Index::create()
                    .name("idx_family_member_name_unique")
                    .table(FamilyMember::Table)
                    .col(FamilyMember::Name)
                    .unique()
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除唯一约束
        manager
            .drop_index(
                Index::drop()
                    .name("idx_family_member_name_unique")
                    .table(FamilyMember::Table)
                    .to_owned(),
            )
            .await
    }
}

#[derive(DeriveIden)]
enum FamilyMember {
    Table,
    Name,
}
