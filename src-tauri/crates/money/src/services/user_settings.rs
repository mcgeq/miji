use std::collections::HashMap;

use common::{
    crud::service::{CrudConverter, GenericCrudService},
    error::{AppError, MijiResult},
    paginations::Filter,
    utils::date::DateUtils,
};
use sea_orm::{
    ActiveModelTrait, ActiveValue, ColumnTrait, Condition, DatabaseConnection, EntityTrait,
    IntoActiveModel, QueryFilter, QueryOrder,
};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use tracing::{debug, info};
use validator::Validate;

use crate::dto::user_settings::{
    CreateUserSettingRequest, UpdateUserSettingRequest, UserSettingResponse,
};

/// 用户设置过滤器
#[derive(Debug, Validate, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UserSettingFilter {
    /// 用户ID
    pub user_serial_num: Option<String>,
    /// 模块名称
    pub module: Option<String>,
    /// 设置键名（支持前缀匹配）
    pub setting_key_prefix: Option<String>,
    /// 是否只返回非默认值
    pub only_custom: Option<bool>,
}

impl Filter<entity::user_settings::Entity> for UserSettingFilter {
    fn to_condition(&self) -> Condition {
        let mut condition = Condition::all();
        
        if let Some(user_serial_num) = &self.user_serial_num {
            condition = condition.add(entity::user_settings::Column::UserSerialNum.eq(user_serial_num));
        }
        
        if let Some(module) = &self.module {
            condition = condition.add(entity::user_settings::Column::Module.eq(module));
        }
        
        if let Some(prefix) = &self.setting_key_prefix {
            condition = condition.add(
                entity::user_settings::Column::SettingKey.starts_with(prefix)
            );
        }
        
        if let Some(true) = self.only_custom {
            condition = condition.add(entity::user_settings::Column::IsDefault.eq(false));
        }
        
        condition
    }
}

/// 用户设置转换器
#[derive(Debug)]
pub struct UserSettingConverter;

impl CrudConverter<
    entity::user_settings::Entity,
    CreateUserSettingRequest,
    UpdateUserSettingRequest,
> for UserSettingConverter
{
    fn create_to_active_model(
        &self,
        data: CreateUserSettingRequest,
    ) -> MijiResult<entity::user_settings::ActiveModel> {
        // 验证数据
        data.validate()
            .map_err(AppError::from_validation_errors)?;
        
        // 使用 From 转换
        Ok(data.into())
    }

    fn update_to_active_model(
        &self,
        model: entity::user_settings::Model,
        data: UpdateUserSettingRequest,
    ) -> MijiResult<entity::user_settings::ActiveModel> {
        let mut active_model = model.into_active_model();
        let now = DateUtils::local_now();

        if let Some(value) = data.setting_value {
            active_model.setting_value = ActiveValue::Set(value);
        }
        if let Some(setting_type) = data.setting_type {
            active_model.setting_type = ActiveValue::Set(setting_type);
        }
        if let Some(description) = data.description {
            active_model.description = ActiveValue::Set(Some(description));
        }
        if let Some(is_default) = data.is_default {
            active_model.is_default = ActiveValue::Set(is_default);
        }

        active_model.updated_at = ActiveValue::Set(now.into());

        Ok(active_model)
    }

    fn primary_key_to_string(&self, model: &entity::user_settings::Model) -> String {
        model.serial_num.clone()
    }

    fn table_name(&self) -> &'static str {
        "user_settings"
    }
}

/// 用户设置服务类型定义
pub type UserSettingService = GenericCrudService<
    entity::user_settings::Entity,
    UserSettingFilter,
    CreateUserSettingRequest,
    UpdateUserSettingRequest,
    UserSettingConverter,
    UserSettingHooks,
>;

/// 用户设置钩子
#[derive(Debug, Clone)]
pub struct UserSettingHooks;

impl UserSettingHooks {
    pub fn new() -> Self {
        Self
    }
}

impl Default for UserSettingHooks {
    fn default() -> Self {
        Self::new()
    }
}

/// 用户设置扩展服务
pub struct UserSettingExtService;

impl UserSettingExtService {
    /// 脱敏用户 ID（日志用）
    fn mask_user_id(user_id: &str) -> String {
        if user_id.len() <= 8 {
            return "***".to_string();
        }
        // 只显示前4位和后4位
        format!("{}***{}", &user_id[..4], &user_id[user_id.len()-4..])
    }
    
    /// 脱敏设置值（日志用）
    fn mask_value(value: &JsonValue, setting_type: &str) -> String {
        match setting_type {
            "string" => {
                if let Some(s) = value.as_str() {
                    if s.len() <= 10 {
                        return "[masked]".to_string();
                    }
                    format!("{}***{}", &s[..3], &s[s.len()-3..])
                } else {
                    "[masked]".to_string()
                }
            },
            "number" | "boolean" => value.to_string(),
            "object" | "array" => format!("[{} with {} bytes]", setting_type, value.to_string().len()),
            _ => "[unknown type]".to_string(),
        }
    }
    
    /// 获取用户的单个设置值
    pub async fn get_setting(
        db: &DatabaseConnection,
        user_serial_num: &str,
        setting_key: &str,
    ) -> MijiResult<Option<JsonValue>> {
        let setting = entity::user_settings::Entity::find()
            .filter(entity::user_settings::Column::UserSerialNum.eq(user_serial_num))
            .filter(entity::user_settings::Column::SettingKey.eq(setting_key))
            .one(db)
            .await?;

        Ok(setting.map(|s| s.setting_value))
    }

    /// 保存或更新设置
    pub async fn save_setting(
        db: &DatabaseConnection,
        user_serial_num: &str,
        setting_key: &str,
        setting_value: JsonValue,
        setting_type: String,
        module: String,
    ) -> MijiResult<UserSettingResponse> {
        // DEBUG 级别: 显示完整信息（开发环境）
        debug!(
            "Saving setting - user: {}, key: {}, type: {}, module: {}, value: {:?}",
            user_serial_num,  // 完整用户ID
            setting_key,
            setting_type,
            module,
            setting_value  // 完整值
        );
        
        // INFO 级别: 脱敏信息（生产环境）
        info!(
            "Saving setting - user: {}, key: {}, type: {}, module: {}",
            Self::mask_user_id(user_serial_num),  // 脱敏用户ID
            setting_key,
            setting_type,
            module
        );
        
        // 查找现有设置
        let existing = entity::user_settings::Entity::find()
            .filter(entity::user_settings::Column::UserSerialNum.eq(user_serial_num))
            .filter(entity::user_settings::Column::SettingKey.eq(setting_key))
            .one(db)
            .await?;

        let now = DateUtils::local_now();

        let model = if let Some(existing_model) = existing {
            // 检查值是否真的变化了
            let value_changed = existing_model.setting_value != setting_value;
            let type_changed = existing_model.setting_type != setting_type;
            
            if !value_changed && !type_changed {
                debug!("Setting value unchanged, skipping update: {}", setting_key);
                info!("Setting unchanged: {}", setting_key);
                return Ok(UserSettingResponse::from(existing_model));
            }
            
            debug!(
                "Updating existing setting: {}, old value: {:?}, new value: {:?}, value_changed: {}, type_changed: {}",
                setting_key,
                existing_model.setting_value,
                setting_value,
                value_changed,
                type_changed
            );
            
            // 更新现有设置 - 只更新变化的字段
            let mut active_model = existing_model.into_active_model();
            
            if value_changed {
                active_model.setting_value = ActiveValue::Set(setting_value);
            }
            if type_changed {
                active_model.setting_type = ActiveValue::Set(setting_type);
            }
            
            // 无论如何都更新这些字段
            active_model.is_default = ActiveValue::Set(false);
            active_model.updated_at = ActiveValue::Set(now.into());

            let updated = active_model
                .update(db)
                .await?;
            info!("Setting updated: {} (value_changed: {}, type_changed: {})", setting_key, value_changed, type_changed);
            updated
        } else {
            debug!("Creating new setting: {}", setting_key);
            // 创建新设置 - 使用 From trait
            let request = CreateUserSettingRequest {
                user_serial_num: user_serial_num.to_string(),
                setting_key: setting_key.to_string(),
                setting_value,
                setting_type,
                module,
                description: None,
                is_default: Some(false),
            };

            let active_model: entity::user_settings::ActiveModel = request.into();

            let created = active_model
                .insert(db)
                .await?;
            info!("Setting created: {}", setting_key);
            created
        };

        debug!("Setting saved successfully: {}", setting_key);
        Ok(UserSettingResponse::from(model))
    }

    /// 获取模块的所有设置
    pub async fn get_module_settings(
        db: &DatabaseConnection,
        user_serial_num: &str,
        module: &str,
    ) -> MijiResult<HashMap<String, JsonValue>> {
        let settings = entity::user_settings::Entity::find()
            .filter(entity::user_settings::Column::UserSerialNum.eq(user_serial_num))
            .filter(entity::user_settings::Column::Module.eq(module))
            .all(db)
            .await?;

        let mut result = HashMap::new();
        for setting in settings {
            result.insert(setting.setting_key, setting.setting_value);
        }

        Ok(result)
    }

    /// 批量保存设置
    pub async fn save_settings_batch(
        db: &DatabaseConnection,
        user_serial_num: &str,
        settings: HashMap<String, (JsonValue, String, String)>, // (value, type, module)
    ) -> MijiResult<Vec<UserSettingResponse>> {
        let mut results = Vec::new();

        for (key, (value, setting_type, module)) in settings {
            let response = Self::save_setting(
                db,
                user_serial_num,
                &key,
                value,
                setting_type,
                module,
            )
            .await?;
            results.push(response);
        }

        Ok(results)
    }

    /// 删除设置
    pub async fn delete_setting(
        db: &DatabaseConnection,
        user_serial_num: &str,
        setting_key: &str,
    ) -> MijiResult<bool> {
        let result = entity::user_settings::Entity::delete_many()
            .filter(entity::user_settings::Column::UserSerialNum.eq(user_serial_num))
            .filter(entity::user_settings::Column::SettingKey.eq(setting_key))
            .exec(db)
            .await?;

        Ok(result.rows_affected > 0)
    }

    /// 重置模块所有设置（删除非默认值）
    pub async fn reset_module_settings(
        db: &DatabaseConnection,
        user_serial_num: &str,
        module: &str,
    ) -> MijiResult<u64> {
        let result = entity::user_settings::Entity::delete_many()
            .filter(entity::user_settings::Column::UserSerialNum.eq(user_serial_num))
            .filter(entity::user_settings::Column::Module.eq(module))
            .filter(entity::user_settings::Column::IsDefault.eq(false))
            .exec(db)
            .await?;

        Ok(result.rows_affected)
    }

    /// 获取用户的所有设置
    pub async fn get_all_user_settings(
        db: &DatabaseConnection,
        user_serial_num: &str,
    ) -> MijiResult<HashMap<String, JsonValue>> {
        let settings = entity::user_settings::Entity::find()
            .filter(entity::user_settings::Column::UserSerialNum.eq(user_serial_num))
            .order_by_asc(entity::user_settings::Column::Module)
            .order_by_asc(entity::user_settings::Column::SettingKey)
            .all(db)
            .await?;

        let mut result = HashMap::new();
        for setting in settings {
            result.insert(setting.setting_key, setting.setting_value);
        }

        Ok(result)
    }
}
