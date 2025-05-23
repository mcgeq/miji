pub use sea_orm_migration::prelude::*;

mod m20250420_060452_create_todos;
mod m20250420_060909_create_todos_tags;
mod m20250420_061310_create_todotags;
mod m20250420_061334_create_todo_taskdependency;
mod m20250420_061351_create_todo_attachment;
mod m20250420_061400_create_todo_reminder;
mod m20250420_064505_create_user;
mod m20250420_072036_create_project;
mod m20250426_071106_create_todo_project;
pub mod schema;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20250420_064505_create_user::Migration),
            Box::new(m20250420_072036_create_project::Migration),
            Box::new(m20250420_060452_create_todos::Migration),
            Box::new(m20250420_060909_create_todos_tags::Migration),
            Box::new(m20250420_061310_create_todotags::Migration),
            Box::new(m20250420_061334_create_todo_taskdependency::Migration),
            Box::new(m20250420_061351_create_todo_attachment::Migration),
            Box::new(m20250420_061400_create_todo_reminder::Migration),
            Box::new(m20250426_071106_create_todo_project::Migration),
        ]
    }
}
