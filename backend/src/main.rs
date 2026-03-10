use axum::body::Body;
use axum::http::Request;
use axum::{
    extract::State,
    routing::{delete, get, post},
    Router,
};
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
use tracing::{info, Level};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

mod db_tracing;
mod handlers;
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
        s3_config_builder = s3_config_builder.endpoint_url(endpoint);
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

    let mut discuz_db = None;
    let mut discuz_cookie_prefix = String::new();
    let mut discuz_authkey = String::new();

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
    }

    let mut ws_secret = [0u8; 32];
    let u1 = uuid::Uuid::new_v4();
    let u2 = uuid::Uuid::new_v4();
    ws_secret[0..16].copy_from_slice(u1.as_bytes());
    ws_secret[16..32].copy_from_slice(u2.as_bytes());

    let state = AppState {
        db: pool.clone(),
        id_gen: Arc::new(utils::ids::new_generator()),
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

    // /chats — chat listing, details, messages, and members
    let chats_routes = Router::new()
        .route("/", get(handlers::chats::get_chats))
        .route(
            "/{chat_id}",
            get(handlers::chats::get_chat).patch(handlers::chats::patch_chat),
        )
        .route(
            "/{chat_id}/messages",
            get(handlers::messages::get_messages).post(handlers::messages::post_message),
        )
        .route(
            "/{chat_id}/messages/{message_id}",
            get(handlers::messages::get_message)
                .patch(handlers::messages::patch_message)
                .delete(handlers::messages::delete_message),
        )
        .route(
            "/{chat_id}/threads/{thread_id}/messages",
            post(handlers::messages::post_thread_message),
        );

    // /group — group lifecycle (create, get info)
    let group_routes = Router::new()
        .route("/", post(handlers::chats::post_chats))
        .route("/{chat_id}", get(handlers::chats::get_chat))
        .route(
            "/{chat_id}/members",
            get(handlers::members::get_members).post(handlers::members::post_add_member),
        )
        .route(
            "/{chat_id}/members/{uid}",
            delete(handlers::members::delete_remove_member).patch(handlers::members::patch_member),
        );

    // /api/push — push notifications
    let push_routes = Router::new()
        .route(
            "/vapid-public-key",
            get(handlers::push::get_vapid_public_key),
        )
        .route("/subscribe", post(handlers::push::post_subscribe))
        .route("/unsubscribe", post(handlers::push::post_unsubscribe));

    // /api/users — user info
    let users_routes = Router::new().route("/me", get(handlers::users::get_me));

    let attachments_routes =
        Router::new().route("/upload-url", post(handlers::attachments::post_upload_url));

    let trace_layer = TraceLayer::new_for_http()
        .make_span_with(|request: &Request<Body>| {
            let request_id = request
                .extensions()
                .get::<RequestId>()
                .map(|id| id.header_value().to_str().unwrap_or("").to_string())
                .unwrap_or_else(|| "".to_string());
            tracing::info_span!(
                "request",
                method = %request.method(),
                uri = %request.uri(),
                request_id = %request_id,
            )
        })
        .on_request(DefaultOnRequest::new().level(Level::INFO))
        .on_response(
            DefaultOnResponse::new()
                .level(Level::INFO)
                .latency_unit(LatencyUnit::Micros),
        );

    let ws_routes = Router::new()
        .route("/", get(handlers::ws::ws_handler))
        .route("/ticket", get(handlers::ws::get_ws_ticket));

    let app = Router::new()
        .route("/health", get(health))
        .nest("/ws", ws_routes)
        .nest("/chats", chats_routes)
        .nest("/group", group_routes)
        .nest("/push", push_routes)
        .nest("/users", users_routes)
        .nest("/attachments", attachments_routes)
        .layer(RequestBodyLimitLayer::new(256 * 1024))
        .layer(
            ServiceBuilder::new()
                .set_x_request_id(RequestIdMaker)
                .propagate_x_request_id()
                .layer(trace_layer),
        )
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], 3000));
    info!("Starting server listening on {:?}", addr);
    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health(State(_state): State<AppState>) -> &'static str {
    "ok"
}
