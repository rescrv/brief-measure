use std::sync::Arc;
use std::time::Duration;

use axum::extract::FromRef;
use sqlx::PgPool;

use crate::config::{env_or_default, env_required};
use crate::error::AppError;

pub struct AppState {
    pub pool: PgPool,
    pub observation_window: Duration,
    pub observation_window_cap: i64,
    pub default_observation_limit: i64,
    pub max_observation_limit: i64,
}

impl FromRef<Arc<AppState>> for Arc<AppState> {
    fn from_ref(state: &Arc<AppState>) -> Arc<AppState> {
        Arc::clone(state)
    }
}

impl AppState {
    pub async fn initialize() -> Result<Arc<AppState>, AppError> {
        let database_url = env_required("DATABASE_URL")?;
        let pool = crate::db::create_pool(&database_url).await?;

        let observation_window_secs: u64 = env_or_default("OBSERVATION_WINDOW_SECS", 86_400)?;
        let observation_window_cap: i64 = env_or_default("OBSERVATION_WINDOW_CAP", 2)?;
        let default_observation_limit: i64 = env_or_default("OBSERVATION_DEFAULT_LIMIT", 90)?;
        let max_observation_limit: i64 = env_or_default("OBSERVATION_MAX_LIMIT", 90)?;

        Ok(Arc::new(AppState {
            pool,
            observation_window: Duration::from_secs(observation_window_secs),
            observation_window_cap: observation_window_cap,
            default_observation_limit,
            max_observation_limit,
        }))
    }
}
