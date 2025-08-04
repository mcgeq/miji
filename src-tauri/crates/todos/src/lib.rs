use tauri::Wry;

use crate::command::{create,list,list_paged,update,delete};

pub mod command;

pub fn register(builder: tauri::Builder<Wry>) -> tauri::Builder<Wry> {
    builder.invoke_handler(tauri::generate_handler![create, list, list_paged, update, delete])
}
