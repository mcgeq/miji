use common::{
    AppState,
    error::{MijiErrorDto, to_dto},
};
use tauri::State;

use crate::{
    dto::UserDto,
    handler::{RegisterPayload, register_handler},
};

#[tauri::command]
pub async fn register(
    payload: RegisterPayload,
    state: State<'_, AppState>,
) -> Result<UserDto, MijiErrorDto> {
    register_handler(&state.db, payload)
        .await
        .map(UserDto::from)
        .map_err(to_dto)
}
