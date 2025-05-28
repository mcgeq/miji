use common::{
    AppState,
    error::{MijiErrorDto, to_dto},
};
use tauri::State;

use crate::{
    dto::{LoginPayload, LoginResponseDto, RegisterPayload},
    handler::{login_handler, register_handler},
};

#[tauri::command]
pub async fn register(
    payload: RegisterPayload,
    state: State<'_, AppState>,
) -> Result<LoginResponseDto, MijiErrorDto> {
    register_handler(&state, payload)
        .await
        .map(LoginResponseDto::from)
        .map_err(to_dto)
}

#[tauri::command]
pub async fn login(
    payload: LoginPayload,
    state: State<'_, AppState>,
) -> Result<LoginResponseDto, MijiErrorDto> {
    login_handler(&state, payload)
        .await
        .map(LoginResponseDto::from)
        .map_err(to_dto)
}
