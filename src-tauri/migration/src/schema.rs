use sea_orm_migration::prelude::*;
use tauri_plugin_sql::Migration;

pub trait MijiMigrationTrait {
    fn up() -> Migration;
    fn down() -> Migration;
}

#[derive(DeriveIden)]
pub enum Users {
    Table,
    SerialNum,
    Name,
    Email,
    Phone,
    Password,
    AvatarUrl,
    LastLoginAt,
    IsVerified,
    Role,
    Status,
    EmailVerifiedAt,
    PhoneVerifiedAt,
    Bio,
    Language,
    Timezone,
    LastActiveAt,
    DeletedAt,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Project {
    Table,
    SerialNum,
    Name,
    Description,
    OwnerId,
    Color,
    IsArchived,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Tag {
    Table,
    SerialNum,
    Name,
    Description,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Todo {
    Table,
    SerialNum,
    Title,
    Description,
    CreatedAt,
    UpdatedAt,
    DueAt,
    Priority,
    Status,
    Repeat,
    CompletedAt,
    AssigneeId,
    Progress,
    Location,
    OwnerId,
    IsArchived,
    IsPinned,
    EstimateMinutes,
    ReminderCount,
    ParentId,
    SubtaskOrder,
}

#[derive(DeriveIden)]
pub enum TodoTag {
    Table,
    TodoSerialNum,
    TagSerialNum,
    Orders,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum TodoProject {
    Table,
    TodoSerialNum,
    ProjectSerialNum,
    OrderIndex,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum TaskDependency {
    Table,
    TaskSerialNum,
    DependsOnTaskSerialNum,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Attachment {
    Table,
    SerialNum,
    TodoSerialNum,
    FilePath,
    Url,
    FileName,
    MimeType,
    Size,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Reminder {
    Table,
    SerialNum,
    TodoSerialNum,
    RemindAt,
    Type,
    IsSent,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum OperationLog {
    Table,
    SerialNum,
    RecordedAt,
    Operation,
    TargetTable,
    RecordId,
    ActorId,
    ChangesJson,
    SnapshotJson,
    DeviceId,
}

#[derive(DeriveIden)]
pub enum PeriodRecords {
    Table,
    SerialNum,
    Notes,
    StartDate,
    EndDate,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum PeriodDailyRecords {
    Table,
    SerialNum,
    PeriodSerialNum,
    Date,
    FlowLevel,
    ExerciseIntensity,
    SexualActivity,
    ContraceptionMethod,
    Diet,
    Mood,
    WaterIntake,
    SleepHours,
    Notes,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum PeriodSymptoms {
    Table,
    SerialNum,
    PeriodDailyRecordsSerialNum,
    SymptomType,
    Intensity,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum PeriodPmsRecords {
    Table,
    SerialNum,
    PeriodSerialNum,
    StartDate,
    EndDate,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum PeriodPmsSymptoms {
    Table,
    SerialNum,
    PeriodPmsRecordsSerialNum,
    SymptomType,
    Intensity,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Currency {
    Table,
    Code,
    Locale,
    Symbol,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum FamilyMember {
    Table,
    SerialNum,
    Name,
    Role,
    IsPrimary,
    Permissions,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Account {
    Table,
    SerialNum,
    Name,
    Description,
    Type,
    Balance,
    InitialBalance,
    Currency,
    IsShared,
    OwnerId,
    Color,
    IsActive,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Budget {
    Table,
    SerialNum,
    AccountSerialNum,
    Name,
    Category,
    Amount,
    Currency,
    RepeatPeriod,
    StartDate,
    EndDate,
    UsedAmount,
    IsActive,
    AlertEnabled,
    AlertThreshold,
    Color,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Transactions {
    Table,
    SerialNum,
    TransactionType,
    TransactionStatus,
    Date,
    Amount,
    RefundAmount,
    Currency,
    Description,
    Notes,
    AccountSerialNum,
    ToAccountSerialNum,
    Category,
    SubCategory,
    Tags,
    SplitMembers,
    PaymentMethod,
    ActualPayerAccount,
    PayeeAccountType,
    RelatedTransactionSerialNum,
    IsDeleted,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum FamilyLedger {
    Table,
    SerialNum,
    Name,
    Description,
    BaseCurrency,
    Members,
    Accounts,
    Transactions,
    Budgets,
    AuditLogs,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum FamilyLedgerAccount {
    Table,
    SerialNum,
    FamilyLedgerSerialNum,
    AccountSerialNum,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum FamilyLedgerTransaction {
    Table,
    FamilyLedgerSerialNum,
    TransactionSerialNum,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum FamilyLedgerMember {
    Table,
    FamilyLedgerSerialNum,
    FamilyMemberSerialNum,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum BilReminder {
    Table,
    SerialNum,
    Name,
    Enabled,
    Type,
    Description,
    Category,
    Amount,
    Currency,
    DueAt,
    BillDate,
    RemindDate,
    RepeatPeriod,
    IsPaid,
    Priority,
    AdvanceValue,
    AdvanceUnit,
    RelatedTransactionSerialNum,
    Color,
    IsDeleted,
    CreatedAt,
    UpdatedAt,
}

