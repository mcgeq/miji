use tauri_plugin_sql::Migration;

pub trait MijiMigrationTrait {
    fn up() -> Migration;
    fn down() -> Migration;
}
