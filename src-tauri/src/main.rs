// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    dotenvy::dotenv().expect("The .env file failed to be read ");
    miji_lib::run()
}
