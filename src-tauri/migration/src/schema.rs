use sea_orm_migration::prelude::*;

#[derive(DeriveIden)]
pub enum Todo {
    Table,           // 任务表
    SerialNum,       // 主键 UUID
    Title,           // 任务标题
    Description,     // 任务描述
    CreatedAt,       // 创建时间
    UpdatedAt,       // 更新时间
    DueAt,           // 截止时间
    Priority,        // 优先级（如 low / medium / high）
    Status,          // 状态（如 pending / completed）
    Repeat,          // 重复规则（如 daily / weekly）
    CompletedAt,     // 完成时间
    AssigneeId,      // 被指派人（user UUID）
    Progress,        // 进度百分比（0~100）
    Location,        // 位置或地点描述
    OwnerId,         // 拥有者用户 ID
    IsArchived,      // 是否已归档
    IsPinned,        // 是否置顶
    EstimateMinutes, // 预计所需时间（分钟）
    ReminderCount,   // 关联提醒数量
    ParentId,        // 父任务 ID（自关联字段）
    SubtaskOrder,    // 子任务顺序
}

#[derive(DeriveIden)]
pub enum User {
    Table,           // 用户表
    SerialNum,       // 主键 UUID
    Name,            // 显示名
    Email,           // 邮箱地址（唯一）
    Phone,           // 手机号（唯一，可选）
    PasswordHash,    // 密码哈希
    AvatarUrl,       // 头像链接
    Bio,             // 自我介绍
    Language,        // 用户语言（如 en / zh）
    Timezone,        // 时区（如 Asia/Shanghai）
    IsVerified,      // 是否已认证
    EmailVerifiedAt, // 邮箱验证时间
    PhoneVerifiedAt, // 手机验证时间
    CreatedAt,       // 创建时间
    UpdatedAt,       // 更新时间
    LastLoginAt,     // 最近登录时间
    LastActiveAt,    // 最近活跃时间
    DeletedAt,       // 删除时间（软删）
    Role,            // 角色（如 admin / user）
    Status,          // 状态（如 active / inactive）
}
// 定义 UserRole 和 UserStatus 枚举用于 Iden
#[derive(DeriveIden)]
pub enum UserRole {
    #[sea_orm(iden = "user_role")]
    Type,
}

#[derive(DeriveIden)]
pub enum UserStatus {
    #[sea_orm(iden = "user_status")]
    Type,
}

#[derive(DeriveIden)]
pub enum Project {
    Table,       // 项目表
    SerialNum,   // 主键 UUID
    Name,        // 项目名称
    Description, // 描述
    OwnerId,     // 所有者（用户 UUID）
    Color,       // 项目颜色
    IsArchived,  // 是否已归档
    CreatedAt,   // 创建时间
    UpdatedAt,   // 更新时间
}

#[derive(DeriveIden)]
pub enum TodoProject {
    Table,            // 多对多关系表：任务 ↔ 项目
    TodoSerialNum,    // 任务 ID
    ProjectSerialNum, // 项目 ID
    Order,            // 排序
    CreatedAt,        // 创建时间
    UpdatedAt,        // 更新时间
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
pub enum TodoTag {
    Table,         // 多对多关系表：任务 ↔ 标签
    TodoSerialNum, // 任务 ID
    TagSerialNum,  // 标签 ID
    Order,         // 排序
    CreatedAt,     // 创建时间
    UpdatedAt,     // 更新时间
}

#[derive(DeriveIden)]
pub enum TaskDependency {
    Table,
    TaskSerialNum,
    DependsOnTaskSerialNum,
}

#[derive(DeriveIden)]
pub enum Attachment {
    Table,         // 附件表
    SerialNum,     // 主键 UUID
    TodoSerialNum, // 所属任务 ID
    FilePath,      // 文件路径
    Url,           // 下载链接
    FileName,      // 原始文件名
    MimeType,      // MIME 类型（如 image/png）
    Size,          // 文件大小（字节）
    CreatedAt,     // 上传时间
}

#[derive(DeriveIden)]
pub enum Reminder {
    Table,         // 提醒表
    SerialNum,     // 主键 UUID
    TodoSerialNum, // 所属任务 ID
    RemindAt,      // 提醒时间
    Type,          // 提醒类型（email / popup / etc）
    IsSent,        // 是否已发送
    CreatedAt,     // 创建时间
}

#[derive(DeriveIden)]
pub enum ReminderType {
    #[sea_orm(iden = "reminder_type")]
    Type,
}
