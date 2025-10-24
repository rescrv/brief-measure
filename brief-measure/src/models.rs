use std::fs::File;
use std::io::Read;
use std::time::Duration;

use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::error::AppError;

pub const API_KEY_LENGTH: usize = 32;
pub const OBSERVATION_LENGTH: usize = 10;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ApiKey {
    pub bytes: [u8; API_KEY_LENGTH],
}

impl ApiKey {
    pub fn generate() -> Result<ApiKey, AppError> {
        let mut file = File::open("/dev/urandom")?;
        let mut bytes = [0u8; API_KEY_LENGTH];
        file.read_exact(&mut bytes)?;
        Ok(ApiKey { bytes })
    }

    pub fn from_hex(value: &str) -> Result<ApiKey, AppError> {
        let value = value.trim();
        if value.len() != API_KEY_LENGTH * 2 {
            return Err(AppError::Unauthorized);
        }

        let mut bytes = [0u8; API_KEY_LENGTH];
        hex::decode_to_slice(value, &mut bytes).map_err(|_| AppError::Unauthorized)?;
        Ok(ApiKey { bytes })
    }

    pub fn to_hex(&self) -> String {
        hex::encode(self.bytes)
    }
}

#[derive(Debug, Serialize)]
pub struct ApiKeyResponse {
    pub api_key: String,
}

#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Observation {
    pub uuidv7: String,
    pub observation: String,
}

pub async fn store_api_key(pool: &PgPool, key: &ApiKey) -> Result<(), AppError> {
    sqlx::query("INSERT INTO api_keys (key) VALUES ($1) ON CONFLICT DO NOTHING")
        .bind(&key.bytes[..])
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn delete_api_key(pool: &PgPool, key: &ApiKey) -> Result<(), AppError> {
    sqlx::query("DELETE FROM api_keys WHERE key = $1")
        .bind(&key.bytes[..])
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn ensure_api_key_exists(pool: &PgPool, key: &ApiKey) -> Result<(), AppError> {
    let exists = sqlx::query("SELECT 1 FROM api_keys WHERE key = $1")
        .bind(&key.bytes[..])
        .fetch_optional(pool)
        .await?;

    if exists.is_some() {
        Ok(())
    } else {
        Err(AppError::Unauthorized)
    }
}

pub async fn count_recent_observations(
    pool: &PgPool,
    key: &ApiKey,
    window: Duration,
) -> Result<i64, AppError> {
    let seconds = i64::try_from(window.as_secs()).unwrap_or(i64::MAX);
    let count: i64 = sqlx::query(
        "SELECT COUNT(*) AS count FROM observations \
         WHERE key = $1 AND created_at >= NOW() - ($2 * INTERVAL '1 second')",
    )
    .bind(&key.bytes[..])
    .bind(seconds)
    .fetch_one(pool)
    .await?
    .try_get("count")?;

    Ok(count)
}

pub async fn insert_observation(
    pool: &PgPool,
    key: &ApiKey,
    uuid: Uuid,
    observation: [u8; OBSERVATION_LENGTH],
) -> Result<Observation, AppError> {
    sqlx::query("INSERT INTO observations (id, key, obs) VALUES ($1, $2, $3)")
        .bind(uuid)
        .bind(&key.bytes[..])
        .bind(&observation[..])
        .execute(pool)
        .await?;

    let observation_string =
        String::from_utf8(observation.to_vec()).map_err(|_| AppError::InvalidObservation)?;

    Ok(Observation {
        uuidv7: uuid.to_string(),
        observation: observation_string,
    })
}

pub async fn fetch_observations(
    pool: &PgPool,
    key: &ApiKey,
    limit: i64,
) -> Result<Vec<Observation>, AppError> {
    let rows = sqlx::query(
        "SELECT id, obs FROM observations \
         WHERE key = $1 ORDER BY id DESC LIMIT $2",
    )
    .bind(&key.bytes[..])
    .bind(limit)
    .fetch_all(pool)
    .await?;

    let mut observations = Vec::with_capacity(rows.len());
    for row in rows {
        let id: Uuid = row.try_get("id")?;
        let obs: Vec<u8> = row.try_get("obs")?;

        let observation = String::from_utf8(obs).map_err(|_| AppError::InvalidObservation)?;

        observations.push(Observation {
            uuidv7: id.to_string(),
            observation,
        });
    }

    Ok(observations)
}

pub fn parse_observation(input: &str) -> Result<[u8; OBSERVATION_LENGTH], AppError> {
    if input.len() != OBSERVATION_LENGTH {
        return Err(AppError::InvalidObservation);
    }

    let mut buffer = [0u8; OBSERVATION_LENGTH];
    if !input.chars().enumerate().all(|(idx, ch)| {
        if matches!(ch, '1' | '2' | '3' | '4') {
            buffer[idx] = ch as u8;
            true
        } else {
            false
        }
    }) {
        return Err(AppError::InvalidObservation);
    }

    Ok(buffer)
}

pub fn parse_uuid_v7(value: &str) -> Result<Uuid, AppError> {
    let uuid = Uuid::parse_str(value).map_err(|_| AppError::InvalidUuid)?;
    if uuid.get_version_num() != 7 {
        return Err(AppError::InvalidUuid);
    }
    Ok(uuid)
}

pub fn apply_limit(
    limit: Option<i64>,
    default_limit: i64,
    max_limit: i64,
) -> Result<i64, AppError> {
    match limit {
        Some(value) if value <= 0 => Err(AppError::InvalidLimit),
        Some(value) if value > max_limit => Err(AppError::InvalidLimit),
        Some(value) => Ok(value),
        None => Ok(default_limit),
    }
}
