use std::sync::Arc;

use axum::async_trait;
use axum::extract::{FromRef, FromRequestParts};
use axum::http::{header, request::Parts};

use crate::error::AppError;
use crate::models::{ApiKey, ensure_api_key_exists};
use crate::state::AppState;

pub struct VerifiedApiKey {
    pub key: ApiKey,
}

#[async_trait]
impl<S> FromRequestParts<S> for VerifiedApiKey
where
    Arc<AppState>: FromRef<S>,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let state = Arc::<AppState>::from_ref(state);
        let header_value = parts
            .headers
            .get(header::AUTHORIZATION)
            .ok_or(AppError::Unauthorized)?;

        let header_str = header_value.to_str().map_err(|_| AppError::Unauthorized)?;
        let prefix = "Bearer ";

        if !header_str.starts_with(prefix) {
            return Err(AppError::Unauthorized);
        }

        let token = header_str[prefix.len()..].trim();
        let key = ApiKey::from_hex(token)?;

        ensure_api_key_exists(&state.pool, &key).await?;

        Ok(VerifiedApiKey { key })
    }
}
