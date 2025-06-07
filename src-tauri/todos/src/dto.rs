// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           dto.rs
// Description:    About Dto
// Create   Date:  2025-06-04 22:02:09
// Last Modified:  2025-06-07 13:01:10
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

use std::ops::Deref;

use chrono::NaiveDateTime;
use common::entity::{
    attachment, project, reminder,
    sea_orm_active_enums::{Priority, ReminderType, Status},
    tag, todo,
};
use sea_orm::prelude::DateTimeWithTimeZone;
use serde::{Deserialize, Deserializer, Serialize, Serializer};
use validator::{Validate, ValidationError};

use crate::helper::{format_naive_datetime, format_opt_naive_datetime};

pub trait FromModel<M> {
    fn from_model(model: M) -> Self;
}

pub trait IntoResponse<R> {
    fn into_response(self) -> R;
}

impl<M, R> IntoResponse<R> for M
where
    R: FromModel<M>,
{
    fn into_response(self) -> R {
        R::from_model(self)
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TodoFilter {
    ALL,
    TODAY,
    YESTERDAY,
    TOMORROW,
}

fn serialize_filter<S>(filter: &TodoFilter, serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let value = match filter {
        TodoFilter::ALL => 0,
        TodoFilter::TODAY => 1,
        TodoFilter::YESTERDAY => 2,
        TodoFilter::TOMORROW => 3,
    };

    serializer.serialize_u8(value)
}

fn deserialize_filter<'de, D>(deserializer: D) -> Result<TodoFilter, D::Error>
where
    D: Deserializer<'de>,
{
    let value = u8::deserialize(deserializer)?;
    match value {
        0 => Ok(TodoFilter::ALL),
        1 => Ok(TodoFilter::TODAY),
        2 => Ok(TodoFilter::YESTERDAY),
        3 => Ok(TodoFilter::TOMORROW),
        _ => Err(serde::de::Error::custom("Invalid filter value")),
    }
}

impl Serialize for TodoFilter {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serialize_filter(self, serializer)
    }
}

impl<'de> Deserialize<'de> for TodoFilter {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        deserialize_filter(deserializer)
    }
}

fn validate_filter(filter: &TodoFilter) -> Result<(), ValidationError> {
    match filter {
        TodoFilter::ALL | TodoFilter::TODAY | TodoFilter::YESTERDAY | TodoFilter::TOMORROW => {
            Ok(())
        }
    }
}
pub struct TodoResponseBundle {
    pub todo: todo::Model,
    pub project: Vec<project::Model>,
    pub reminders: Vec<reminder::Model>,
    pub attachments: Vec<attachment::Model>,
    pub tags: Vec<tag::Model>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct TodoId {
    #[validate(length(
        min = 32,
        max = 38,
        message = "serial_num must be between 32 and 38 characters"
    ))]
    pub serial_num: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct PaginationParams {
    #[validate(
        required(message = "page is required"),
        range(min = 1, message = "page must be greater than or equal to 1")
    )]
    pub page: Option<u64>,
    #[validate(
        required(message = "page_size is required"),
        range(min = 1, message = "page_size must be greater than or equal to 1")
    )]
    pub page_size: Option<u64>,
    #[validate(
        required(message = "filter is required"),
        custom(
            function = "validate_filter",
            message = "filter must be between 0 and 3"
        )
    )]
    pub filter: Option<TodoFilter>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct TodoInput {
    #[validate(length(
        min = 1,
        max = 1000,
        message = "title must be between 1 and 1000 characters"
    ))]
    pub title: Option<String>,
    #[validate(length(max = 1000, message = "description must be at most 1000 characters"))]
    pub description: Option<String>,
    #[serde(
        default,
        deserialize_with = "deserialize_naive_datetime",
        serialize_with = "serialize_naive_datetime"
    )]
    pub due_at: Option<NaiveDateTime>,
    pub priority: Option<Priority>,
    pub status: Option<Status>,
    pub tags: Option<Vec<CreateOrUpdateForm>>,
    pub repeat: Option<String>,
    #[validate(range(min = 0, max = 100, message = "progress must be between 0 and 100"))]
    pub progress: Option<i8>,
    pub assignee_id: Option<String>,
    pub projects: Option<Vec<CreateOrUpdateForm>>,
    pub location: Option<String>,
    pub owner_id: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct CreateOrUpdateForm {
    #[validate(length(
        min = 32,
        max = 38,
        message = "serial_num must be between 32 and 38 characters"
    ))]
    pub serial_num: Option<String>,
    #[validate(length(min = 0, max = 100, message = "name must be between 0 and 100"))]
    pub name: Option<String>,
    #[validate(length(max = 1000, message = "description must be at most 1000 characters"))]
    pub description: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct TodoListResult {
    pub total_items: u64,
    pub total_pages: u64,
    pub items: Vec<TodoResponse>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct TodoResponse {
    pub serial_num: String,
    pub title: String,
    pub description: Option<String>,
    pub created_at: String,
    pub updated_at: Option<String>,
    pub due_at: String,
    pub priority: i8,
    pub status: i8,
    pub repeat: Option<String>,
    pub completed_at: Option<String>,
    pub assignee_id: Option<String>,
    pub progress: i8,
    pub location: Option<String>,
    pub owner_id: Option<String>,
    pub projects: Vec<ProjectInfo>,
    pub tags: Vec<TagInfo>,
    pub reminders: Vec<ReminderInfo>,
    pub attachments: Vec<AttachmentInfo>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct ProjectCore {
    pub serial_num: String,
    pub name: String,
    pub description: Option<String>,
}

// Re-use or define these structs if they don't exist elsewhere
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct ProjectInfo {
    #[serde(flatten)]
    pub core: ProjectCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct ProjectResponse {
    #[serde(flatten)]
    pub core: ProjectCore,
    pub create_at: String,
    pub update_at: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct TagCore {
    pub serial_num: String,
    pub name: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct TagInfo {
    #[serde(flatten)]
    pub core: TagCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct TagResponse {
    #[serde(flatten)]
    pub core: TagCore,
    pub description: Option<String>,
    pub create_at: String,
    pub update_at: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct ReminderInfo {
    pub serial_num: String,
    pub remind_at: String, // Store as string for JSON
}

// New DTOs for Reminder
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, Validate)]
pub struct ReminderCore {
    pub todo_serial_num: String,
    pub remind_at: DateTimeWithTimeZone,
    pub r#type: Option<ReminderType>,
    pub is_sent: bool,
}

#[derive(Debug, Serialize, Validate)]
pub struct ReminderDto {
    #[serde(flatten)]
    pub core: ReminderCore,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize, Validate)]
pub struct ReminderResDto {
    pub serial_num: String,
    #[serde(flatten)]
    pub core: ReminderCore,
    pub created_at: DateTimeWithTimeZone,
    pub updated_at: Option<DateTimeWithTimeZone>,
}

impl From<reminder::Model> for ReminderResDto {
    fn from(value: reminder::Model) -> Self {
        Self {
            serial_num: value.serial_num,
            core: ReminderCore {
                todo_serial_num: value.todo_serial_num,
                remind_at: value.remind_at,
                r#type: value.r#type,
                is_sent: value.is_sent,
            },
            created_at: value.created_at,
            updated_at: value.updated_at,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct AttachmentInfo {
    pub serial_num: String,
    pub file_path: Option<String>,
    pub url: Option<String>,
}

impl FromModel<tag::Model> for TagResponse {
    fn from_model(tag: tag::Model) -> Self {
        TagResponse {
            core: TagCore {
                serial_num: tag.serial_num,
                name: tag.name,
            },
            description: Some(tag.description.unwrap_or_default()),
            create_at: tag.created_at.to_string(),
            update_at: tag.updated_at.map_or("".to_string(), |dt| dt.to_string()),
        }
    }
}

impl FromModel<project::Model> for ProjectResponse {
    fn from_model(project: project::Model) -> Self {
        ProjectResponse {
            core: ProjectCore {
                serial_num: project.serial_num,
                name: project.name,
                description: project.description,
            },
            create_at: project.created_at.to_string(),
            update_at: project
                .updated_at
                .map_or("".to_string(), |dt| dt.to_string()),
        }
    }
}

impl FromModel<TodoResponseBundle> for TodoResponse {
    fn from_model(models: TodoResponseBundle) -> Self {
        let model = models.todo;
        let project = models.project;
        let tags = models.tags;
        let reminders = models.reminders;
        let attachments = models.attachments;

        TodoResponse {
            serial_num: model.serial_num,
            title: model.title,
            description: model.description,
            created_at: format_naive_datetime(model.created_at),
            updated_at: format_opt_naive_datetime(model.updated_at),
            due_at: format_naive_datetime(model.due_at),
            priority: model.priority,
            status: model.status,
            repeat: model.repeat,
            completed_at: format_opt_naive_datetime(model.completed_at),
            assignee_id: model.assignee_id,
            progress: model.progress,
            location: model.location,
            owner_id: model.owner_id, // If user model loaded, map details here

            projects: project
                .into_iter()
                .map(|p| ProjectInfo {
                    core: ProjectCore {
                        serial_num: p.serial_num,
                        name: p.name,
                        description: Some(p.description.unwrap_or("".to_string())),
                    },
                })
                .collect(),
            tags: tags
                .into_iter()
                .map(|t| TagInfo {
                    core: TagCore {
                        serial_num: t.serial_num,
                        name: t.name,
                    },
                })
                .collect(),
            reminders: reminders
                .into_iter()
                .map(|r| ReminderInfo {
                    serial_num: r.serial_num,
                    remind_at: format_naive_datetime(r.remind_at),
                })
                .collect(),
            attachments: attachments
                .into_iter()
                .map(|a| AttachmentInfo {
                    serial_num: a.serial_num,
                    file_path: a.file_path,
                    url: a.url,
                })
                .collect(),
        }
    }
}

impl Deref for ProjectInfo {
    type Target = ProjectCore;
    fn deref(&self) -> &Self::Target {
        &self.core
    }
}

impl Deref for ProjectResponse {
    type Target = ProjectCore;
    fn deref(&self) -> &Self::Target {
        &self.core
    }
}

fn deserialize_naive_datetime<'de, D>(deserializer: D) -> Result<Option<NaiveDateTime>, D::Error>
where
    D: Deserializer<'de>,
{
    let s: Option<String> = Option::deserialize(deserializer)?;
    match s {
        Some(s) => NaiveDateTime::parse_from_str(&s, "%Y-%m-%d %H:%M:%S")
            .map(Some)
            .map_err(serde::de::Error::custom),
        None => Ok(None),
    }
}
fn serialize_naive_datetime<S>(
    date: &Option<NaiveDateTime>,
    serializer: S,
) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    match date {
        Some(date) => {
            // Serialize to "2025-04-12T20:25:23"
            let s = date.format("%Y-%m-%dT%H:%M:%S").to_string();
            serializer.serialize_str(&s)
        }
        None => serializer.serialize_none(),
    }
}
