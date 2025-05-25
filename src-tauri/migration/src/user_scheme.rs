use sea_orm_migration::prelude::*;

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
