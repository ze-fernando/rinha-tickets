use tickets::db::Db;
use tickets::state::AppState;
use tickets::ticket::routes::router;
use tracing_subscriber::EnvFilter;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    let database_url =
        std::env::var("DATABASE_URL").unwrap_or_else(|_| "database.sqlite".to_string());
    let port = std::env::var("PORT").unwrap_or_else(|_| "8000".to_string());

    let db = Db::connect(&database_url)?;
    db.run_migrations()?;

    let app = router(AppState { db });
    let listener = tokio::net::TcpListener::bind(format!("0.0.0.0:{port}")).await?;

    tracing::info!("Servidor rodando em http://0.0.0.0:{port}");

    axum::serve(listener, app).await?;

    Ok(())
}
