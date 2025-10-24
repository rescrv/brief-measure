use std::net::SocketAddr;
use std::sync::Arc;

use axum::Router;
use brief_measure::{AppError, AppState, build_router};
use tokio::net::TcpListener;

#[tokio::main]
async fn main() {
    if let Err(err) = run().await {
        eprintln!("error: {err}");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), AppError> {
    let state: Arc<AppState> = AppState::initialize().await?;
    let router: Router = build_router(Arc::clone(&state));

    let bind_addr = std::env::var("BIND_ADDR").unwrap_or_else(|_| "127.0.0.1:3000".to_string());
    let addr: SocketAddr = bind_addr
        .parse()
        .map_err(|_| AppError::InvalidConfig("BIND_ADDR".to_string()))?;

    let listener = TcpListener::bind(addr).await?;
    axum::serve(listener, router.into_make_service())
        .await
        .map_err(|err| AppError::Server(err.to_string()))?;

    Ok(())
}
