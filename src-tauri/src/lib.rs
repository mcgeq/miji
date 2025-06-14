#[cfg(desktop)]
mod desktops;

mod commands;
mod migrations;
#[cfg(any(target_os = "android", target_os = "ios"))]
mod mobiles;
mod plugins;

#[cfg(desktop)]
use desktops::init;
#[cfg(desktop)]
use init::MijiInit;

use commands::init_commands;
use migrations::MijiMigrations;
use plugins::generic_plugins;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let builder = tauri::Builder::default();
    let builder = generic_plugins(builder);
    #[cfg(desktop)]
    let builder = builder.init_plugin();

    let builder = builder.init_migrations();

    let builder = init_commands(builder);
    builder
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
