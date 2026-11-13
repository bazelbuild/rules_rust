use axum::Router;
use color_eyre::eyre::Result;
use eyre::{bail, Context};
use std::{net::SocketAddr, path::Path};
use tower_http::{services::ServeDir, trace::TraceLayer};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[tokio::main]
async fn main() -> Result<()> {
    color_eyre::install()?;

    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                format!("{}=info,tower_http=debug", env!("CARGO_CRATE_NAME")).into()
            }),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    if std::env::var_os("HTTP_ROOT").is_none() {
        bail!("Please set the HTTP_ROOT env variable to the directory of static files you want to serve")
    }

    let http_root = std::env::var("HTTP_ROOT").context("while reading HTTP_ROOT env variable")?;
    let http_root = Path::new(&http_root);

    if !http_root.is_dir() {
        bail!("HTTP_ROOT={http_root:?} is not a directory")
    }

    serve(&http_root, 3001).await
}

async fn serve(http_root: &Path, port: u16) -> Result<()> {
    let files = ServeDir::new(http_root);
    let app = Router::new().fallback_service(files);

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    let listener = tokio::net::TcpListener::bind(addr)
        .await
        .with_context(|| format!("while trying to bind socket to 127.0.0.1:{port}"))?;
    tracing::info!(
        "Serving {:?} on http://{}",
        http_root,
        listener.local_addr()?
    );
    axum::serve(listener, app.layer(TraceLayer::new_for_http()))
        .await
        .context("while serving")
}
