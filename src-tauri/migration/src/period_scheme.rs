use sea_orm_migration::prelude::*;

// PeriodRecords: 表示周期记录表，对应历史记录中的 cycles 表
#[derive(DeriveIden)]
pub enum PeriodRecords {
    Table,
    SerialNum, // 主键
    StartDate, // 开始日期
    EndDate,   // 结束日期
    CreatedAt, // 创建时间
    UpdatedAt, // 更新时间
}

// PeriodDailyRecords: 表示每日记录表，对应历史记录中的 daily_records 表
#[derive(DeriveIden)]
pub enum PeriodDailyRecords {
    Table,
    SerialNum,         // 主键
    PeriodSerialNum,   // 外键，关联 PeriodRecords.SerialNum
    Date,              // 日期
    FlowLevel,         // 流量等级（枚举类型）
    SexualActivity,    // 性活动（布尔值）
    ExerciseIntensity, // 运动强度（枚举类型）
    Diet,              // 饮食（字符串）
    CreatedAt,         // 创建时间
    UpdatedAt,         // 更新时间
}

// PeriodSymptoms: 表示每日症状表，对应历史记录中的 daily_symptoms 表
#[derive(DeriveIden)]
pub enum PeriodSymptoms {
    Table,
    SerialNum,                   // 主键
    PeriodDailyRecordsSerialNum, // 外键，关联 PeriodDailyRecords.SerialNum
    #[sea_orm(iden = "symptom_type")]
    SymptomType, // 症状类型（枚举类型）
    #[sea_orm(iden = "intensity")]
    Intensity, // 强度（枚举类型）
    CreatedAt,                   // 创建时间
    UpdatedAt,                   // 更新时间
}

// PeriodPmsRecords: 表示经前综合症记录表，对应历史记录中的 pms_records 表
#[derive(DeriveIden)]
pub enum PeriodPmsRecords {
    Table,
    SerialNum,       // 主键
    PeriodSerialNum, // 外键，关联 PeriodRecords.SerialNum（新增）
    StartDate,       // 开始日期
    EndDate,         // 结束日期
    CreatedAt,       // 创建时间
    UpdatedAt,       // 更新时间
}

// PeriodPmsSymptoms: 表示经前综合症症状表，对应历史记录中的 pms_symptoms 表
#[derive(DeriveIden)]
pub enum PeriodPmsSymptoms {
    Table,
    SerialNum,                 // 主键
    PeriodPmsRecordsSerialNum, // 外键，关联 PeriodPmsRecords.SerialNum
    #[sea_orm(iden = "symptom_type")]
    SymptomType, // 症状类型（枚举类型）
    #[sea_orm(iden = "intensity")]
    Intensity, // 强度（枚举类型）
    CreatedAt,                 // 创建时间
    UpdatedAt,                 // 更新时间
}

// SymptomsType: 症状类型的枚举名称定义
#[derive(DeriveIden)]
pub enum SymptomsType {
    #[sea_orm(iden = "symptoms_type")]
    Type, // 在迁移中用作枚举类型名称
}

// Intensity: 强度枚举名称定义（新增）
#[derive(DeriveIden)]
pub enum Intensity {
    #[sea_orm(iden = "intensity")]
    Type, // 在迁移中用作枚举类型名称
}

// FlowLevel: 流量等级枚举名称定义（新增）
#[derive(DeriveIden)]
pub enum FlowLevel {
    #[sea_orm(iden = "flow_level")]
    Type, // 在迁移中用作枚举类型名称
}

// ExerciseIntensity: 运动强度枚举名称定义（新增）
#[derive(DeriveIden)]
pub enum ExerciseIntensity {
    #[sea_orm(iden = "exercise_intensity")]
    Type, // 在迁移中用作枚举类型名称
}
