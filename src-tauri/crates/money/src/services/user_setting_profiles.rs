use common::{
    error::{AppError, MijiResult},
    utils::date::DateUtils,
    BusinessCode,
};
use sea_orm::{
    ActiveModelTrait, ActiveValue::Set, ColumnTrait, DatabaseConnection, EntityTrait, QueryFilter,
    QueryOrder,
};
use serde_json::Value as JsonValue;
use tracing::{debug, info};

use crate::dto::user_settings::{
    CreateUserSettingProfileRequest, UserSettingProfileResponse,
};

/// 用户设置配置方案服务
pub struct UserSettingProfileService;

impl UserSettingProfileService {
    /// 创建配置方案
    pub async fn create_profile(
        db: &DatabaseConnection,
        request: CreateUserSettingProfileRequest,
    ) -> MijiResult<UserSettingProfileResponse> {
        info!(
            "Creating profile '{}' for user {}",
            request.profile_name, request.user_serial_num
        );

        // 检查是否已存在同名配置
        let existing = entity::user_setting_profiles::Entity::find()
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(&request.user_serial_num))
            .filter(entity::user_setting_profiles::Column::ProfileName.eq(&request.profile_name))
            .one(db)
            .await?;

        if existing.is_some() {
            return Err(AppError::simple(
                BusinessCode::ValidationError,
                format!("配置方案 '{}' 已存在", request.profile_name),
            ));
        }

        let active_model: entity::user_setting_profiles::ActiveModel = request.into();
        let model = active_model.insert(db).await?;

        info!("Profile '{}' created successfully", model.profile_name);
        Ok(UserSettingProfileResponse::from(model))
    }

    /// 获取用户的所有配置方案
    pub async fn get_user_profiles(
        db: &DatabaseConnection,
        user_serial_num: &str,
    ) -> MijiResult<Vec<UserSettingProfileResponse>> {
        debug!("Getting profiles for user {}", user_serial_num);

        let profiles = entity::user_setting_profiles::Entity::find()
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
            .order_by_desc(entity::user_setting_profiles::Column::IsActive)
            .order_by_desc(entity::user_setting_profiles::Column::IsDefault)
            .order_by_asc(entity::user_setting_profiles::Column::CreatedAt)
            .all(db)
            .await?;

        Ok(profiles.into_iter().map(UserSettingProfileResponse::from).collect())
    }

    /// 获取当前激活的配置方案
    pub async fn get_active_profile(
        db: &DatabaseConnection,
        user_serial_num: &str,
    ) -> MijiResult<Option<UserSettingProfileResponse>> {
        let profile = entity::user_setting_profiles::Entity::find()
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
            .filter(entity::user_setting_profiles::Column::IsActive.eq(true))
            .one(db)
            .await?;

        Ok(profile.map(UserSettingProfileResponse::from))
    }

    /// 切换到指定配置方案（会批量更新设置）
    pub async fn switch_profile(
        db: &DatabaseConnection,
        user_serial_num: &str,
        profile_serial_num: &str,
    ) -> MijiResult<UserSettingProfileResponse> {
        info!(
            "Switching to profile {} for user {}",
            profile_serial_num, user_serial_num
        );

        // 查找目标配置
        let profile = entity::user_setting_profiles::Entity::find_by_id(profile_serial_num)
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "配置方案不存在"))?;

        // 停用所有配置
        entity::user_setting_profiles::Entity::update_many()
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
            .col_expr(
                entity::user_setting_profiles::Column::IsActive,
                sea_orm::sea_query::Expr::value(false),
            )
            .exec(db)
            .await?;

        // 激活目标配置
        let mut active_model = profile.clone().into_active_model();
        active_model.is_active = Set(true);
        active_model.updated_at = Set(DateUtils::local_now().into());
        let updated_profile = active_model.update(db).await?;

        // 应用配置数据到 user_settings 表
        Self::apply_profile_settings(db, user_serial_num, &profile.profile_data).await?;

        info!(
            "Successfully switched to profile '{}'",
            updated_profile.profile_name
        );
        Ok(UserSettingProfileResponse::from(updated_profile))
    }

    /// 应用配置数据到 user_settings 表（批量更新）
    async fn apply_profile_settings(
        db: &DatabaseConnection,
        user_serial_num: &str,
        profile_data: &JsonValue,
    ) -> MijiResult<()> {
        debug!("Applying profile settings for user {}", user_serial_num);

        // 假设 profile_data 格式为: { "settings.general.theme": "dark", "settings.general.locale": "zh-CN", ... }
        if let Some(settings_map) = profile_data.as_object() {
            for (setting_key, setting_value) in settings_map {
                // 解析 setting_key 获取 module 和 type
                let parts: Vec<&str> = setting_key.split('.').collect();
                if parts.len() < 3 {
                    continue;
                }

                let module = parts[1].to_string(); // settings.general.locale -> general
                let setting_type = Self::infer_type(setting_value);

                // 使用 user_settings 服务保存
                super::user_settings::UserSettingExtService::save_setting(
                    db,
                    user_serial_num,
                    setting_key,
                    setting_value.clone(),
                    setting_type,
                    module,
                )
                .await?;
            }
        }

        info!("Profile settings applied successfully");
        Ok(())
    }

    /// 推断值类型
    fn infer_type(value: &JsonValue) -> String {
        match value {
            JsonValue::String(_) => "string".to_string(),
            JsonValue::Number(_) => "number".to_string(),
            JsonValue::Bool(_) => "boolean".to_string(),
            JsonValue::Array(_) => "array".to_string(),
            JsonValue::Object(_) => "object".to_string(),
            JsonValue::Null => "null".to_string(),
        }
    }

    /// 从当前设置创建配置方案
    pub async fn create_from_current(
        db: &DatabaseConnection,
        user_serial_num: &str,
        profile_name: String,
        description: Option<String>,
    ) -> MijiResult<UserSettingProfileResponse> {
        info!(
            "Creating profile '{}' from current settings for user {}",
            profile_name, user_serial_num
        );

        // 获取用户的所有当前设置
        let settings = super::user_settings::UserSettingExtService::get_all_user_settings(
            db,
            user_serial_num,
        )
        .await?;

        // 转换为 JSON
        let profile_data = serde_json::to_value(&settings)
            .map_err(|e| AppError::simple(BusinessCode::SerializationError, format!("序列化失败: {}", e)))?;

        let request = CreateUserSettingProfileRequest {
            user_serial_num: user_serial_num.to_string(),
            profile_name,
            profile_data,
            description,
        };

        Self::create_profile(db, request).await
    }

    /// 更新配置方案
    pub async fn update_profile(
        db: &DatabaseConnection,
        user_serial_num: &str,
        profile_serial_num: &str,
        profile_name: Option<String>,
        profile_data: Option<JsonValue>,
        description: Option<String>,
    ) -> MijiResult<UserSettingProfileResponse> {
        let profile = entity::user_setting_profiles::Entity::find_by_id(profile_serial_num)
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "配置方案不存在"))?;

        let mut active_model = profile.into_active_model();

        if let Some(name) = profile_name {
            // 检查新名称是否冲突
            let existing = entity::user_setting_profiles::Entity::find()
                .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
                .filter(entity::user_setting_profiles::Column::ProfileName.eq(&name))
                .filter(entity::user_setting_profiles::Column::SerialNum.ne(profile_serial_num))
                .one(db)
                .await?;

            if existing.is_some() {
                return Err(AppError::simple(
                    BusinessCode::ValidationError,
                    format!("配置方案 '{}' 已存在", name),
                ));
            }

            active_model.profile_name = Set(name);
        }

        if let Some(data) = profile_data {
            active_model.profile_data = Set(data);
        }

        if let Some(desc) = description {
            active_model.description = Set(Some(desc));
        }

        active_model.updated_at = Set(DateUtils::local_now().into());

        let updated = active_model.update(db).await?;
        Ok(UserSettingProfileResponse::from(updated))
    }

    /// 删除配置方案
    pub async fn delete_profile(
        db: &DatabaseConnection,
        user_serial_num: &str,
        profile_serial_num: &str,
    ) -> MijiResult<bool> {
        let profile = entity::user_setting_profiles::Entity::find_by_id(profile_serial_num)
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "配置方案不存在"))?;

        // 不允许删除默认配置
        if profile.is_default {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "不能删除默认配置方案",
            ));
        }

        // 不允许删除当前激活的配置
        if profile.is_active {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "不能删除当前激活的配置方案，请先切换到其他配置",
            ));
        }

        let result = entity::user_setting_profiles::Entity::delete_by_id(profile_serial_num)
            .exec(db)
            .await?;

        info!("Profile '{}' deleted", profile.profile_name);
        Ok(result.rows_affected > 0)
    }

    /// 导出配置方案为 JSON
    pub async fn export_profile(
        db: &DatabaseConnection,
        user_serial_num: &str,
        profile_serial_num: &str,
    ) -> MijiResult<JsonValue> {
        let profile = entity::user_setting_profiles::Entity::find_by_id(profile_serial_num)
            .filter(entity::user_setting_profiles::Column::UserSerialNum.eq(user_serial_num))
            .one(db)
            .await?
            .ok_or_else(|| AppError::simple(BusinessCode::NotFound, "配置方案不存在"))?;

        Ok(serde_json::json!({
            "version": "1.0",
            "profile_name": profile.profile_name,
            "description": profile.description,
            "profile_data": profile.profile_data,
            "exported_at": DateUtils::local_now().to_rfc3339(),
        }))
    }

    /// 从 JSON 导入配置方案
    pub async fn import_profile(
        db: &DatabaseConnection,
        user_serial_num: &str,
        import_data: JsonValue,
    ) -> MijiResult<UserSettingProfileResponse> {
        let profile_name = import_data["profile_name"]
            .as_str()
            .ok_or_else(|| {
                AppError::simple(
                    BusinessCode::InvalidParameter,
                    "无效的导入数据：缺少 profile_name",
                )
            })?
            .to_string();

        let profile_data = import_data["profile_data"].clone();
        if !profile_data.is_object() {
            return Err(AppError::simple(
                BusinessCode::InvalidParameter,
                "无效的导入数据：profile_data 必须是对象",
            ));
        }

        let description = import_data["description"].as_str().map(|s| s.to_string());

        let request = CreateUserSettingProfileRequest {
            user_serial_num: user_serial_num.to_string(),
            profile_name,
            profile_data,
            description,
        };

        Self::create_profile(db, request).await
    }
}
