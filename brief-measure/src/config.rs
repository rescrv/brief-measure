use std::str::FromStr;

use crate::error::AppError;

pub fn env_required(key: &str) -> Result<String, AppError> {
    match std::env::var(key) {
        Ok(value) => Ok(value),
        Err(std::env::VarError::NotPresent) => Err(AppError::MissingConfig(key.to_string())),
        Err(std::env::VarError::NotUnicode(_)) => Err(AppError::InvalidConfig(key.to_string())),
    }
}

pub fn env_or_default<T>(key: &str, default: T) -> Result<T, AppError>
where
    T: FromStr,
{
    match std::env::var(key) {
        Ok(value) => value
            .parse::<T>()
            .map_err(|_| AppError::InvalidConfig(key.to_string())),
        Err(std::env::VarError::NotPresent) => Ok(default),
        Err(std::env::VarError::NotUnicode(_)) => Err(AppError::InvalidConfig(key.to_string())),
    }
}
