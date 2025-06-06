use common::{AppState, db::get_database_version};
use log::{error, info};
use tauri::{Builder, State, Wry};

#[tauri::command]
async fn greet(name: String, state: State<'_, AppState>) -> Result<String, String> {
    let db = state.db.clone();
    match get_database_version(&db).await {
        Ok(version) => {
            info!("Database Version: {version}");
        }
        Err(e) => error!("Failed to get database version: {e}"),
    }
    info!("Greet {name}");
    Ok(format!("Hello, {name}! You've been greeted from Rust!"))
}

pub fn init_commands(builder: Builder<Wry>) -> Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![
        greet,
        auth::commands::register,
        auth::commands::login,
        todos::commands::todo_command::list_todo,
        todos::commands::todo_command::create_todo,
        todos::commands::todo_command::update_todo,
        todos::commands::todo_command::delete_todo,
        todos::commands::tag_command::list_tag,
        todos::commands::tag_command::create_tag,
        todos::commands::tag_command::update_tag,
        todos::commands::tag_command::delete_tag,
        todos::commands::project_command::list_project,
        todos::commands::project_command::create_project,
        todos::commands::project_command::update_project,
        todos::commands::project_command::delete_project,
    ])
}
