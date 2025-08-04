#[tauri::command]
pub async fn list_account() -> String {
    eprintln!("todos list");
    "list".to_string()
}

#[tauri::command]
pub async fn list_paged_account() {
    eprintln!("todos listPaged");
}

#[tauri::command]
pub async fn create_account() {
    eprintln!("todos create");
}

#[tauri::command]
pub async fn update_account() {
    eprintln!("todos update");
}

#[tauri::command]
pub async fn delete_account() {
    eprintln!("todos delete");
}

#[tauri::command]
pub async fn list_transactions() -> String {
    eprintln!("todos list");
    "list".to_string()
}

#[tauri::command]
pub async fn list_paged_transactions() {
    eprintln!("todos listPaged");
}

#[tauri::command]
pub async fn create_transaction() {
    eprintln!("todos create");
}

#[tauri::command]
pub async fn update_transaction() {
    eprintln!("todos update");
}

#[tauri::command]
pub async fn delete_transaction() {
    eprintln!("todos delete");
}



