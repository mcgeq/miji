use sea_orm_migration::prelude::{extension::postgres::Type, *};

use crate::period_scheme::{ExerciseIntensity, FlowLevel, Intensity, SymptomsType};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 创建 symptoms_type 枚举
        manager
            .create_type(
                Type::create()
                    .as_enum(SymptomsType::Type)
                    .values(vec![
                        Alias::new("Pain"),
                        Alias::new("Fatigue"),
                        Alias::new("MoodSwing"),
                    ])
                    .to_owned(),
            )
            .await?;

        // 创建 intensity 枚举
        manager
            .create_type(
                Type::create()
                    .as_enum(Intensity::Type)
                    .values(vec![
                        Alias::new("Light"),
                        Alias::new("Medium"),
                        Alias::new("Heavy"),
                    ])
                    .to_owned(),
            )
            .await?;

        // 创建 flow_level 枚举
        manager
            .create_type(
                Type::create()
                    .as_enum(FlowLevel::Type)
                    .values(vec![
                        Alias::new("Light"),
                        Alias::new("Medium"),
                        Alias::new("Heavy"),
                    ])
                    .to_owned(),
            )
            .await?;

        // 创建 exercise_intensity 枚举
        manager
            .create_type(
                Type::create()
                    .as_enum(ExerciseIntensity::Type)
                    .values(vec![
                        Alias::new("None"),
                        Alias::new("Light"),
                        Alias::new("Medium"),
                        Alias::new("Heavy"),
                    ])
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除枚举类型
        manager
            .drop_type(Type::drop().name(SymptomsType::Type).to_owned())
            .await?;
        manager
            .drop_type(Type::drop().name(Intensity::Type).to_owned())
            .await?;
        manager
            .drop_type(Type::drop().name(FlowLevel::Type).to_owned())
            .await?;
        manager
            .drop_type(Type::drop().name(ExerciseIntensity::Type).to_owned())
            .await?;

        Ok(())
    }
}
