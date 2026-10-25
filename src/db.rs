use std::time::Duration;

use diesel::r2d2::{ConnectionManager, Pool};
use diesel::sqlite::SqliteConnection;
use diesel_migrations::{EmbeddedMigrations, MigrationHarness, embed_migrations};

use crate::ticket::errors::AppError;

pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("migrations");

#[derive(Clone)]
pub struct Db {
    pool: Pool<ConnectionManager<SqliteConnection>>,
}

impl Db {
    pub fn connect(database_url: &str) -> Result<Self, AppError> {
        let manager = ConnectionManager::<SqliteConnection>::new(database_url);

        let pool = Pool::builder()
            .max_size(8)
            .connection_timeout(Duration::from_secs(5))
            .build(manager)?;

        Ok(Self { pool })
    }

    pub async fn run<T, F>(&self, operation: F) -> Result<T, AppError>
    where
        T: Send + 'static,
        F: FnOnce(&mut SqliteConnection) -> Result<T, AppError> + Send + 'static,
    {
        let pool = self.pool.clone();

        tokio::task::spawn_blocking(move || {
            let mut connection = pool.get()?;
            operation(&mut connection)
        })
        .await?
    }

    pub fn run_migrations(&self) -> Result<(), AppError> {
        let mut connection = self.pool.get()?;

        connection
            .run_pending_migrations(MIGRATIONS)
            .map_err(|error| AppError::Migration(error.to_string()))?;

        Ok(())
    }
}
