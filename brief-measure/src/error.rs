use std::fmt::{self, Display, Formatter};

use axum::Json;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde::Serialize;

#[derive(Debug)]
pub enum AppError {
    Database(sqlx::Error),
    Io(std::io::Error),
    InvalidObservation,
    InvalidUuid,
    Unauthorized,
    TooManyObservations,
    InvalidLimit,
    MissingConfig(String),
    InvalidConfig(String),
    Join(tokio::task::JoinError),
    Server(String),
    Migration(sqlx::migrate::MigrateError),
}

#[derive(Serialize)]
struct ErrorBody {
    error: String,
}

impl AppError {
    fn message(&self) -> String {
        match self {
            AppError::Database(_) => "database error".to_string(),
            AppError::Io(err) => format!("io error: {err}"),
            AppError::InvalidObservation => "invalid observation".to_string(),
            AppError::InvalidUuid => "invalid uuid".to_string(),
            AppError::Unauthorized => "unauthorized".to_string(),
            AppError::TooManyObservations => "observation limit reached".to_string(),
            AppError::InvalidLimit => "invalid limit".to_string(),
            AppError::MissingConfig(key) => format!("missing configuration: {key}"),
            AppError::InvalidConfig(key) => format!("invalid configuration: {key}"),
            AppError::Join(err) => format!("task join error: {err}"),
            AppError::Server(err) => format!("server error: {err}"),
            AppError::Migration(err) => format!("migration error: {err}"),
        }
    }

    fn status_code(&self) -> StatusCode {
        match self {
            AppError::InvalidObservation | AppError::InvalidUuid | AppError::InvalidLimit => {
                StatusCode::BAD_REQUEST
            }
            AppError::Unauthorized => StatusCode::UNAUTHORIZED,
            AppError::TooManyObservations => StatusCode::TOO_MANY_REQUESTS,
            AppError::MissingConfig(_) | AppError::InvalidConfig(_) => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
            AppError::Database(_) | AppError::Io(_) | AppError::Join(_) | AppError::Server(_)
            | AppError::Migration(_) => {
                StatusCode::INTERNAL_SERVER_ERROR
            }
        }
    }
}

impl Display for AppError {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.message())
    }
}

impl std::error::Error for AppError {}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let status = self.status_code();
        let body = Json(ErrorBody {
            error: self.message(),
        });
        (status, body).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        AppError::Database(err)
    }
}

impl From<std::io::Error> for AppError {
    fn from(err: std::io::Error) -> Self {
        AppError::Io(err)
    }
}

impl From<tokio::task::JoinError> for AppError {
    fn from(err: tokio::task::JoinError) -> Self {
        AppError::Join(err)
    }
}

impl From<sqlx::migrate::MigrateError> for AppError {
    fn from(err: sqlx::migrate::MigrateError) -> Self {
        AppError::Migration(err)
    }
}
