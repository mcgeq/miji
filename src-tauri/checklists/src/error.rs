use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum ChecklistsError {
    #[snafu(display("Checklist item not found: {}", id))]
    NotFound { id: u32 },
}
