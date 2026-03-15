use axum::body::Body;
use axum::http::Request;
use axum::{middleware, routing::get, Router};
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::{MysqlConnection, PgConnection};
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};
use serde::Deserialize;
use std::net::SocketAddr;
use std::sync::Arc;
use tower::ServiceBuilder;
use tower_http::limit::RequestBodyLimitLayer;
use tower_http::request_id::{MakeRequestId, RequestId};
use tower_http::trace::{DefaultOnRequest, DefaultOnResponse, TraceLayer};
use tower_http::LatencyUnit;
use tower_http::ServiceBuilderExt;
use tracing::{debug_span, info, Level};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

mod db_tracing;
mod handlers;
mod metrics;
mod models;
mod schema;
mod serde_i64_string;
mod services;
mod utils;

const MIGRATIONS: EmbeddedMigrations = embed_migrations!("migrations");

/// Produces a request ID from the `X-Request-ID` header or generates a new UUID.
#[derive(Clone, Default)]
struct RequestIdMaker;

impl MakeRequestId for RequestIdMaker {
    fn make_request_id<B>(&mut self, _request: &Request<B>) -> Option<RequestId> {
        let id = uuid::Uuid::new_v4().to_string();
        let hv = axum::http::HeaderValue::try_from(id.as_str())
            .unwrap_or_else(|_| axum::http::HeaderValue::from_static("unknown"));
        Some(RequestId::new(hv))
    }
}

pub(crate) const MAX_CHATS_LIMIT: i64 = 100;
pub(crate) const MAX_MESSAGES_LIMIT: i64 = 100;

#[derive(Clone, Deserialize, Default)]
pub(crate) enum AuthMethod {
    #[default]
    UIDHeader,
    Discuz,
}

#[derive(Clone)]
pub(crate) struct AppState {
    db: Pool<ConnectionManager<PgConnection>>,
    id_gen: Arc<utils::ids::IdGen>,
    metrics: Arc<metrics::Metrics>,
    ws_registry: Arc<services::ws_registry::ConnectionRegistry>,
    push_service: Arc<services::push::PushService>,
    s3_client: aws_sdk_s3::Client,
    s3_bucket_name: String,
    s3_attachment_prefix: String,
    s3_base_url: Option<String>,
    pub auth_method: AuthMethod,
    pub discuz_db: Option<Pool<ConnectionManager<MysqlConnection>>>,
    pub discuz_cookie_prefix: String,
    pub discuz_authkey: String,
    pub discuz_avatar_public_url: Option<String>,
    pub discuz_avatar_path: Option<String>,
    pub ws_secret: [u8; 32],
}

#[tokio::main]
async fn main() {
    // Tracing: RUST_LOG controls level (e.g. RUST_LOG=info, or
    // RUST_LOG=wetty_chat_backend=debug,tower_http=debug for request-level logs).
    // Responses include X-Request-ID for correlation with clients or proxies.
    tracing_subscriber::registry()
        .with(EnvFilter::from_default_env())
        .with(tracing_subscriber::fmt::layer().with_target(true))
        .init();

    db_tracing::install();

    dotenvy::dotenv().ok();
    let database_url = std::env::var("DATABASE_URL").expect("DATABASE_URL must be set");
    let manager = ConnectionManager::<PgConnection>::new(&database_url);

    // TODO: consider deadpool for pool
    let pool = Pool::builder()
        .build(manager)
        .expect("Failed to create pool");

    {
        let mut conn = pool.get().expect("Failed to get connection for migrations");
        conn.run_pending_migrations(MIGRATIONS)
            .expect("Failed to run database migrations");
    }

    let ws_registry = Arc::new(services::ws_registry::ConnectionRegistry::new());

    let aws_config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
    let mut s3_config_builder = aws_sdk_s3::config::Builder::from(&aws_config);

    if let Ok(endpoint) = std::env::var("S3_ENDPOINT_URL") {
        s3_config_builder = s3_config_builder
            .endpoint_url(endpoint)
            .force_path_style(true);
    }

    let s3_client = aws_sdk_s3::Client::from_conf(s3_config_builder.build());
    let s3_bucket_name = std::env::var("S3_BUCKET_NAME").expect("S3_BUCKET_NAME must be set");
    let s3_attachment_prefix =
        std::env::var("ATTACHMENTS_PREFIX").unwrap_or_else(|_| "attachments".to_string());
    let s3_base_url = std::env::var("S3_BASE_URL").ok();

    let auth_method_str = std::env::var("AUTH_METHOD").unwrap_or_else(|_| "UIDHeader".to_string());
    let auth_method = match auth_method_str.as_str() {
        "Discuz" => AuthMethod::Discuz,
        _ => AuthMethod::UIDHeader,
    };
    let app_addr = read_socket_addr("APP_ADDR", SocketAddr::from(([0, 0, 0, 0], 3000)));
    let metrics_addr =
        read_socket_addr("METRICS_ADDR", SocketAddr::from(([0, 0, 0, 0], 3001)));

    let mut discuz_db = None;
    let mut discuz_cookie_prefix = String::new();
    let mut discuz_authkey = String::new();
    let mut discuz_avatar_public_url = None;
    let mut discuz_avatar_path = None;

    if let AuthMethod::Discuz = auth_method {
        let discuz_db_url = std::env::var("DISCUZ_DB_URL").expect("DISCUZ_DB_URL must be set");
        let mysql_manager = ConnectionManager::<MysqlConnection>::new(&discuz_db_url);
        discuz_db = Some(
            Pool::builder()
                .build(mysql_manager)
                .expect("Failed to create Discuz pool"),
        );
        discuz_cookie_prefix =
            std::env::var("DISCUZ_COOKIE_PREFIX").expect("DISCUZ_COOKIE_PREFIX must be set");
        discuz_authkey = std::env::var("DISCUZ_AUTHKEY").expect("DISCUZ_AUTHKEY must be set");
        discuz_avatar_public_url = std::env::var("DISCUZ_AVATAR_PUBLIC_URL").ok();
        discuz_avatar_path = std::env::var("DISCUZ_AVATAR_PATH").ok();
    }

    let mut ws_secret = [0u8; 32];
    let u1 = uuid::Uuid::new_v4();
    let u2 = uuid::Uuid::new_v4();
    ws_secret[0..16].copy_from_slice(u1.as_bytes());
    ws_secret[16..32].copy_from_slice(u2.as_bytes());

    let state = AppState {
        db: pool.clone(),
        id_gen: Arc::new(utils::ids::new_generator()),
        metrics: Arc::new(metrics::Metrics::new()),
        ws_registry: ws_registry.clone(),
        push_service: services::push::PushService::start(pool, ws_registry.clone()),
        s3_client,
        s3_bucket_name,
        s3_attachment_prefix,
        s3_base_url,
        auth_method,
        discuz_db,
        discuz_cookie_prefix,
        discuz_authkey,
        discuz_avatar_public_url,
        discuz_avatar_path,
        ws_secret,
    };

    let registry = state.ws_registry.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
        loop {
            interval.tick().await;
            registry.prune_stale(300);
        }
    });

    // --- Sub-routers ---
    // Sub-routers are mounted via handlers::api_router()

    let trace_layer = TraceLayer::new_for_http()
        .make_span_with(|request: &Request<Body>| {
            let request_id = request
                .extensions()
                .get::<RequestId>()
                .map(|id| id.header_value().to_str().unwrap_or("").to_string())
                .unwrap_or_else(|| "".to_string());
            debug_span!(
                "request",
                method = %request.method(),
                uri = %request.uri(),
                request_id = %request_id,
            )
        })
        .on_request(DefaultOnRequest::new().level(Level::DEBUG))
        .on_response(
            DefaultOnResponse::new()
                .level(Level::DEBUG)
                .latency_unit(LatencyUnit::Micros),
        );

    let metrics_registry = state.metrics.clone();
    let app = Router::new()
        .merge(handlers::api_router())
        .layer(RequestBodyLimitLayer::new(256 * 1024))
        .layer(
            ServiceBuilder::new()
                .set_x_request_id(RequestIdMaker)
                .propagate_x_request_id()
                .layer(trace_layer),
        )
        .layer(middleware::from_fn_with_state(
            metrics_registry.clone(),
            metrics::track_http_metrics,
        ))
        .with_state(state);

    let metrics_app = Router::new()
        .route("/metrics", get(metrics::metrics_handler))
        .with_state(metrics_registry);

    info!("Starting API server listening on {:?}", app_addr);
    let app_listener = tokio::net::TcpListener::bind(app_addr).await.unwrap();

    info!("Starting metrics server listening on {:?}", metrics_addr);
    let metrics_listener = tokio::net::TcpListener::bind(metrics_addr).await.unwrap();

    let api_server = axum::serve(app_listener, app);
    let metrics_server = axum::serve(metrics_listener, metrics_app);

    tokio::select! {
        result = api_server => {
            result.unwrap();
        }
        result = metrics_server => {
            result.unwrap();
        }
    }
}

fn read_socket_addr(var_name: &str, default: SocketAddr) -> SocketAddr {
    std::env::var(var_name)
        .ok()
        .map(|value| {
            value
                .parse()
                .unwrap_or_else(|_| panic!("{var_name} must be a valid socket address"))
        })
        .unwrap_or(default)
}
