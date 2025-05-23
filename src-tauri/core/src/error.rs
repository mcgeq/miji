use snafu::Snafu;

#[derive(Debug, Snafu)]
pub enum MijiError {
    #[snafu(display("Auth module error: {}", source))]
    Auth { source: auth::error::AuthError },

    #[snafu(display("User module error: {}", source))]
    User { source: auth::error::UserError },

    #[snafu(display("Permission error: {}", source))]
    Permission {
        source: crate::permissions::PermissionError,
    },

    #[snafu(display("Health module error: {}", source))]
    Health { source: health::error::HealthError },

    #[snafu(display("Checklists module error: {}", source))]
    Checklists {
        source: checklists::error::ChecklistsError,
    },

    #[snafu(display("Notes module error: {}", source))]
    Notes { source: notes::error::NotesError },

    #[snafu(display("Todos module error: {}", source))]
    Todos { source: todos::error::TodosError },

    #[snafu(display("Profile module error: {}", source))]
    Profile {
        source: profile::error::ProfileError,
    },

    #[snafu(display("Settings module error: {}", source))]
    Settings {
        source: settings::error::SettingsError,
    },

    #[snafu(display("Services module error: {}", source))]
    Services {
        source: services::error::ServicesError,
    },

    #[snafu(display("Other error: {}", message))]
    Other { message: String },
}
