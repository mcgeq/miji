#[tauri::command]
pub async fn list() -> String {
    eprintln!("todos list");
    "list".to_string()
}

#[tauri::command]
pub async fn list_paged() {
    eprintln!("todos listPaged");
}

#[tauri::command]
pub async fn create() {
    eprintln!("todos create");
}

#[tauri::command]
pub async fn update() {
    eprintln!("todos update");
}

#[tauri::command]
pub async fn delete() {
    eprintln!("todos delete");
}


