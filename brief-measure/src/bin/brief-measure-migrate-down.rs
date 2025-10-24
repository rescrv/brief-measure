use brief_measure::config::env_required;
use brief_measure::{AppError, create_pool, migrate_down};

#[tokio::main]
async fn main() {
    if let Err(err) = run().await {
        eprintln!("migration down failed: {err}");
        std::process::exit(1);
    }
}

async fn run() -> Result<(), AppError> {
    let database_url = env_required("DATABASE_URL")?;
    let pool = create_pool(&database_url).await?;
    migrate_down(&pool).await?;
    println!("rolled back one migration");
    Ok(())
}
