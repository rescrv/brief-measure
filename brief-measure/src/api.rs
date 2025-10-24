use std::sync::Arc;

use axum::extract::{Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use axum::{Json, Router};
use serde::Deserialize;

use crate::auth::VerifiedApiKey;
use crate::error::AppError;
use crate::models::{
    ApiKey, ApiKeyResponse, Observation, apply_limit, count_recent_observations, delete_api_key,
    fetch_observations, insert_observation, parse_observation, parse_uuid_v7, store_api_key,
};
use crate::state::AppState;

pub fn build_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/api/v1/keys", post(post_keys))
        .route(
            "/api/v1/observations",
            post(post_observations).get(get_observations),
        )
        .route("/api/v1/forget-me-now", post(post_forget_me_now))
        .with_state(state)
}

async fn post_keys(State(state): State<Arc<AppState>>) -> Result<impl IntoResponse, AppError> {
    let key = ApiKey::generate()?;
    store_api_key(&state.pool, &key).await?;

    let response = ApiKeyResponse {
        api_key: key.to_hex(),
    };

    Ok((StatusCode::CREATED, Json(response)))
}

async fn post_observations(
    State(state): State<Arc<AppState>>,
    VerifiedApiKey { key }: VerifiedApiKey,
    Json(payload): Json<Observation>,
) -> Result<impl IntoResponse, AppError> {
    let uuid = parse_uuid_v7(&payload.uuidv7)?;
    let observation_bytes = parse_observation(&payload.observation)?;

    let recent = count_recent_observations(&state.pool, &key, state.observation_window).await?;
    if recent >= state.observation_window_cap {
        return Err(AppError::TooManyObservations);
    }

    let observation = insert_observation(&state.pool, &key, uuid, observation_bytes).await?;
    Ok((StatusCode::CREATED, Json(observation)))
}

#[derive(Debug, Deserialize)]
struct ObservationsQuery {
    limit: Option<i64>,
}

async fn get_observations(
    State(state): State<Arc<AppState>>,
    VerifiedApiKey { key }: VerifiedApiKey,
    Query(query): Query<ObservationsQuery>,
) -> Result<impl IntoResponse, AppError> {
    let limit = apply_limit(
        query.limit,
        state.default_observation_limit,
        state.max_observation_limit,
    )?;
    let observations = fetch_observations(&state.pool, &key, limit).await?;
    Ok(Json(observations))
}

async fn post_forget_me_now(
    State(state): State<Arc<AppState>>,
    VerifiedApiKey { key }: VerifiedApiKey,
) -> Result<impl IntoResponse, AppError> {
    delete_api_key(&state.pool, &key).await?;
    Ok(StatusCode::NO_CONTENT)
}
