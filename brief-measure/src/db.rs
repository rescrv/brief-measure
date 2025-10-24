use std::time::Duration;

use sqlx::postgres::PgPoolOptions;
use sqlx::PgPool;

use crate::config::env_or_default;
use crate::error::AppError;

static MIGRATOR: sqlx::migrate::Migrator = sqlx::migrate!("./migrations");

pub async fn create_pool(database_url: &str) -> Result<PgPool, AppError> {
    let max_connections: u32 = env_or_default("DATABASE_MAX_CONNECTIONS", 5)?;
    let connect_timeout_secs: u64 = env_or_default("DATABASE_CONNECT_TIMEOUT_SECS", 30)?;

    let pool = PgPoolOptions::new()
        .max_connections(max_connections)
        .acquire_timeout(Duration::from_secs(connect_timeout_secs))
        .connect(database_url)
        .await?;

    Ok(pool)
}

pub async fn migrate_up(pool: &PgPool) -> Result<(), AppError> {
    MIGRATOR.run(pool).await?;
    Ok(())
}

pub async fn migrate_down(pool: &PgPool) -> Result<(), AppError> {
    let mut conn = pool.acquire().await?;

    let last_version = sqlx::query_scalar::<_, i64>(
        "SELECT version FROM _sqlx_migrations ORDER BY version DESC LIMIT 1",
    )
    .fetch_optional(&mut *conn)
    .await?;

    let Some(version) = last_version else {
        return Ok(());
    };

    let target = version - 1;
    MIGRATOR.undo(conn.as_mut(), target).await?;
    Ok(())
}
