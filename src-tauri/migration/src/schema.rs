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
    RepeatPeriodType,
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
    // 新增提醒相关字段
    ReminderEnabled,
    ReminderAdvanceValue,
    ReminderAdvanceUnit,
    LastReminderSentAt,
    ReminderFrequency,
    SnoozeUntil,
    ReminderMethods,
    Timezone,
    SmartReminderEnabled,
    LocationBasedReminder,
    WeatherDependent,
    PriorityBoostEnabled,
    BatchReminderId,
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
pub enum ProjectTag {
    Table,
    ProjectSerialNum,
    TagSerialNum,
    Orders,
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
    // 新增提醒执行相关字段
    ReminderMethod,
    RetryCount,
    LastRetryAt,
    SnoozeCount,
    EscalationLevel,
    NotificationId,
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
pub enum PeriodSettings {
    Table,
    SerialNum,
    AverageCycleLength,
    AveragePeriodLength,
    PeriodReminder,
    OvulationReminder,
    PmsReminder,
    ReminderDays,
    DataSync,
    Analytics,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Currency {
    Table,
    Code,
    Locale,
    Symbol,
    IsDefault,
    IsActive,
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
    // 新增字段
    UserId,
    AvatarUrl,
    Color,
    TotalPaid,
    TotalOwed,
    Balance,
    Status,
    Email,
    Phone,
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
    IsVirtual,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum Budget {
    Table,
    SerialNum,
    AccountSerialNum,
    Name,
    Description,
    Amount,
    Currency,
    RepeatPeriodType,
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
    CurrentPeriodUsed,  // 当前周期已用金额
    CurrentPeriodStart, // 当前周期开始日期
    LastResetAt,        // 最后重置时间
    BudgetType,         // 预算类型（标准/储蓄/债务等）
    Progress,           // 进度百分比
    LinkedGoal,         // 关联目标
    Reminders,          // 提醒设置
    Priority,           // 优先级（1-5）
    Tags,               // 标签
    AutoRollover,       // 是否自动滚动
    RolloverHistory,    // 滚动历史记录
    SharingSettings,    // 共享设置
    Attachments,        // 附件信息
    // 新增字段 - 预算范围系统
    BudgetScopeType, // 预算范围类型: Category/Account/Hybrid/RuleBased
    AccountScope,    // JSONB 账户范围配置
    CategoryScope,   // JSONB 分类范围配置
    AdvancedRules,   // JSONB 高级规则数组
    // Phase 6: 家庭预算扩展字段
    FamilyLedgerSerialNum, // 家庭账本序列号（与account_serial_num互斥）
    CreatedBy,             // 创建者（个人预算=用户ID，家庭预算=成员SerialNum）
}
#[derive(DeriveIden)]
pub enum Transactions {
    Table,                       // 表名：交易记录主表（核心交易流水存储）
    SerialNum,                   // 主键：交易唯一标识（全局唯一序列号，如UUID或雪花ID）
    TransactionType,             // 交易类型（枚举值：消费/收入/转账/退款/代付/分摊等）
    TransactionStatus,           // 交易状态（枚举值：待处理/已完成/失败/已撤销/退款中）
    Date,                        // 交易日期（业务发生日期，如消费刷卡日；区别于创建时间）
    Amount,           // 交易金额（数值型：正数=收入/出账，负数=支出/入账，需结合业务规则解读）
    RefundAmount,     // 退款金额（仅退款交易或原交易的退款部分填写，非必填）
    Currency,         // 货币类型（ISO 4217标准：如CNY/USD/EUR，默认CNY）
    Description,      // 交易描述（系统自动生成或手动填写，如"美团外卖-午餐"）
    Notes,            // 备注（用户/系统补充说明，如"客户报销款"、"项目备用金"）
    AccountSerialNum, // 外键：当前交易所属账户（关联账户表主键，标识资金来源/去向）
    ToAccountSerialNum, // 外键：交易对方账户（如转账接收方、消费商户账户，可选）
    Category,         // 交易一级分类（如"餐饮"、"交通"、"工资"、"娱乐"）
    SubCategory,      // 交易二级分类（如"餐饮"下的"快餐"、"奶茶"，可选）
    Tags,             // 交易标签（自定义标签，如"#出差"、"#日常消费"、"#会员充值"，支持多标签）
    SplitMembers,     // 分摊成员（多人分摊交易时的参与用户，如JSON数组存储用户ID）
    PaymentMethod,    // 支付方式（如"微信支付"、"支付宝"、"银行卡"、"现金"、"信用卡"）
    ActualPayerAccount, // 外键：实际付款账户（代付场景下，与所属账户不同的实际付款人，可选）
    PayeeAccountType, // 收款方账户类型（枚举值：个人/企业/平台/商户，辅助分类）
    RelatedTransactionSerialNum, // 外键：关联交易记录（如退款关联原交易、转账的对方流水，可选）
    IsDeleted,        // 软删除标记（布尔值：true=已逻辑删除，false=未删除；避免物理删除）
    CreatedAt,        // 创建时间（交易记录入库时间，时间戳）
    UpdatedAt,        // 最后更新时间（交易状态/金额变更的时间，时间戳）

    // ---------------------- 分期业务扩展字段 ----------------------
    IsInstallment, // 是否为分期交易（布尔值：true=该交易是分期首期/后续期，false=普通交易）
    FirstDueDate,
    InstallmentAmount,
    RemainingPeriodsAmount,
    TotalPeriods,             // 分期总期数（仅分期交易有效：如"12期"）
    RemainingPeriods,         // 剩余未还期数（仅分期交易有效：随每期还款递减，0表示已结清）
    InstallmentPlanSerialNum, // 外键：关联分期计划（指向InstallmentPlans表的主键，绑定分期规则）
}

/// 分期付款计划表 (installment_plans)
#[derive(DeriveIden)]
pub enum InstallmentPlans {
    /// 表名
    Table,
    /// 序列号 (唯一标识)
    SerialNum,
    /// 关联的交易序列号
    TransactionSerialNum,
    /// 关联的账户序列号
    AccountSerialNum,
    /// 总金额
    TotalAmount,
    /// 总期数
    TotalPeriods,
    /// 每期还款金额
    InstallmentAmount,
    /// 首期应还日期
    FirstDueDate,
    /// 当前状态 (如: 未开始/还款中/已完成)
    Status,
    /// 创建时间
    CreatedAt,
    /// 更新时间
    UpdatedAt,
}

/// 分期付款详情表 (installment_details)
#[derive(DeriveIden)]
pub enum InstallmentDetails {
    /// 表名
    Table,
    /// 序列号 (唯一标识)
    SerialNum,
    /// 关联的分期计划序列号
    PlanSerialNum,
    /// 当前期数
    PeriodNumber,
    /// 本期应还日期
    DueDate,
    /// 本期应还金额
    Amount,
    /// 关联的账户序列号
    AccountSerialNum,
    /// 当前状态 (如: 待支付/已支付/逾期)
    Status,
    /// 实际还款日期
    PaidDate,
    /// 实际还款金额
    PaidAmount,
    /// 创建时间
    CreatedAt,
    /// 更新时间
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum FamilyLedger {
    Table,
    SerialNum,
    Name,
    Description,
    BaseCurrency,
    Members,      // 字段名不变，但类型从 JSON 字符串改为整数
    Accounts,     // 字段名不变，但类型从 JSON 字符串改为整数
    Transactions, // 字段名不变，但类型从 JSON 字符串改为整数
    Budgets,      // 字段名不变，但类型从 JSON 字符串改为整数
    AuditLogs,
    // 新增字段
    LedgerType,
    SettlementCycle,
    SettlementDay,
    AutoSettlement,
    DefaultSplitRule,
    LastSettlementAt,
    NextSettlementAt,
    Status,
    // 财务统计字段
    TotalIncome,
    TotalExpense,
    SharedExpense,
    PersonalExpense,
    PendingSettlement,
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
    RepeatPeriodType,
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
    // 新增高级提醒功能字段
    LastReminderSentAt,
    ReminderFrequency,
    SnoozeUntil,
    ReminderMethods,
    EscalationEnabled,
    EscalationAfterHours,
    Timezone,
    SmartReminderEnabled,
    AutoReschedule,
    PaymentReminderEnabled,
    BatchReminderId,
}

#[derive(DeriveIden)]
pub enum Categories {
    Table,
    Name,
    Icon,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum SubCategories {
    Table,
    Name,
    Icon,
    CategoryName,
    CreatedAt,
    UpdatedAt,
}

// 新增通知系统相关表定义
#[derive(DeriveIden)]
pub enum NotificationLogs {
    Table,
    SerialNum,
    ReminderSerialNum,
    NotificationType,
    Priority,
    Status,
    SentAt,
    ErrorMessage,
    RetryCount,
    LastRetryAt,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum NotificationSettings {
    Table,
    SerialNum,
    UserId,
    NotificationType,
    Enabled,
    QuietHoursStart,
    QuietHoursEnd,
    QuietDays,
    SoundEnabled,
    VibrationEnabled,
    CreatedAt,
    UpdatedAt,
}

#[derive(DeriveIden)]
pub enum BatchReminders {
    Table,
    SerialNum,
    Name,
    Description,
    ScheduledAt,
    Status,
    TotalCount,
    SentCount,
    FailedCount,
    CreatedAt,
    UpdatedAt,
}

// 分摊规则表
#[derive(DeriveIden)]
pub enum SplitRules {
    Table,
    SerialNum,
    FamilyLedgerSerialNum,
    Name,
    Description,
    RuleType,
    RuleConfig,
    ParticipantMembers,
    IsTemplate,
    IsDefault,
    Category,
    SubCategory,
    MinAmount,
    MaxAmount,
    Tags,
    Priority,
    IsActive,
    CreatedBy,
    CreatedAt,
    UpdatedAt,
}

// 分摊记录表
#[derive(DeriveIden)]
pub enum SplitRecords {
    Table,
    SerialNum,
    TransactionSerialNum,
    FamilyLedgerSerialNum,
    SplitRuleSerialNum,
    PayerMemberSerialNum,
    OweMemberSerialNum,
    TotalAmount,
    SplitAmount,
    SplitPercentage,
    Currency,
    Status,
    SplitType,
    Description,
    Notes,
    ConfirmedAt,
    PaidAt,
    DueDate,
    ReminderSent,
    LastReminderAt,
    CreatedAt,
    UpdatedAt,
}

// 债务关系表
#[derive(DeriveIden)]
pub enum DebtRelations {
    Table,
    SerialNum,
    FamilyLedgerSerialNum,
    CreditorMemberSerialNum,
    DebtorMemberSerialNum,
    Amount,
    Currency,
    Status,
    LastUpdatedBy,
    LastCalculatedAt,
    SettledAt,
    Notes,
    CreatedAt,
    UpdatedAt,
}

// 结算记录表
#[derive(DeriveIden)]
pub enum SettlementRecords {
    Table,
    SerialNum,
    FamilyLedgerSerialNum,
    SettlementType,
    PeriodStart,
    PeriodEnd,
    TotalAmount,
    Currency,
    ParticipantMembers,
    SettlementDetails,
    OptimizedTransfers,
    Status,
    InitiatedBy,
    CompletedBy,
    Description,
    Notes,
    CompletedAt,
    CancelledAt,
    CreatedAt,
    UpdatedAt,
}

// 分摊记录明细表
#[derive(DeriveIden)]
pub enum SplitRecordDetails {
    Table,
    SerialNum,
    SplitRecordSerialNum,
    MemberSerialNum,
    Amount,
    Percentage,
    Weight,
    IsPaid,
    PaidAt,
    CreatedAt,
    UpdatedAt,
}

// 预算分配表（支持家庭预算的分类/成员分配）
#[derive(DeriveIden)]
pub enum BudgetAllocations {
    Table,
    SerialNum,
    BudgetSerialNum,
    CategorySerialNum,
    MemberSerialNum,
    AllocatedAmount,
    UsedAmount,
    RemainingAmount,
    Percentage,
    // 增强字段 - 分配规则
    AllocationType, // 分配类型: FIXED_AMOUNT, PERCENTAGE, SHARED, DYNAMIC
    RuleConfig,     // 规则配置（JSONB）
    // 增强字段 - 超支控制
    AllowOverspend,      // 是否允许超支
    OverspendLimitType,  // 超支限额类型: NONE, PERCENTAGE, FIXED_AMOUNT
    OverspendLimitValue, // 超支限额值
    // 增强字段 - 预警设置
    AlertEnabled,   // 启用预警
    AlertThreshold, // 预警阈值百分比
    AlertConfig,    // 预警配置（JSONB）
    // 增强字段 - 管理
    Priority,    // 优先级 1-5
    IsMandatory, // 是否强制（不可削减）
    Status,      // 状态: ACTIVE, PAUSED, COMPLETED
    Notes,       // 备注
    CreatedAt,
    UpdatedAt,
}

// 用户设置表
#[derive(DeriveIden)]
pub enum UserSettings {
    Table,
    SerialNum,
    UserSerialNum,
    SettingKey,
    SettingValue,
    SettingType,
    Module,
    Description,
    IsDefault,
    CreatedAt,
    UpdatedAt,
}

// 用户设置配置文件表
#[derive(DeriveIden)]
pub enum UserSettingProfiles {
    Table,
    SerialNum,
    UserSerialNum,
    ProfileName,
    ProfileData,
    IsActive,
    IsDefault,
    Description,
    CreatedAt,
    UpdatedAt,
}

// 用户设置历史记录表
#[derive(DeriveIden)]
pub enum UserSettingHistory {
    Table,
    SerialNum,
    UserSerialNum,
    SettingKey,
    OldValue,
    NewValue,
    ChangeType,
    ChangedBy,
    IpAddress,
    UserAgent,
    CreatedAt,
}

// 调度器配置表
#[derive(DeriveIden)]
pub enum SchedulerConfig {
    Table,
    SerialNum,
    UserSerialNum,
    TaskType,
    Enabled,
    IntervalSeconds,
    MaxRetryCount,
    RetryDelaySeconds,
    Platform,
    BatteryThreshold,
    NetworkRequired,
    WifiOnly,
    ActiveHoursStart,
    ActiveHoursEnd,
    Priority,
    Description,
    IsDefault,
    CreatedAt,
    UpdatedAt,
}
