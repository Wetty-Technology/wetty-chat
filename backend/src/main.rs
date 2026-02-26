use axum::body::Body;
use axum::http::Request;
use axum::{extract::State, routing::{delete, get, patch}, Router};
use diesel::r2d2::{ConnectionManager, Pool};
use diesel::PgConnection;
use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};
use std::net::SocketAddr;
use std::sync::Arc;
use tower::ServiceBuilder;
use tower_http::request_id::{MakeRequestId, RequestId};
use tower_http::trace::{DefaultOnRequest, DefaultOnResponse, TraceLayer};
use tower_http::LatencyUnit;
use tower_http::ServiceBuilderExt;
use tracing::{info, Level};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

mod handlers;
mod models;
mod schema;
mod serde_i64_string;
mod utils;
mod ws_registry;

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

#[derive(Clone)]
pub(crate) struct AppState {
    db: Pool<ConnectionManager<PgConnection>>,
    id_gen: Arc<utils::ids::IdGen>,
    ws_registry: Arc<ws_registry::ConnectionRegistry>,
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

    let state = AppState {
        db: pool,
        id_gen: Arc::new(utils::ids::new_generator()),
        ws_registry: Arc::new(ws_registry::ConnectionRegistry::new()),
    };

    let registry = state.ws_registry.clone();
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
        loop {
            interval.tick().await;
            registry.prune_stale(300);
        }
    });

    let chat_routes = Router::new()
        .route(
            "/",
            get(handlers::chats::get_chats).post(handlers::chats::post_chats),
        )
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
            patch(handlers::messages::patch_message).delete(handlers::messages::delete_message),
        )
        .route(
            "/{chat_id}/members",
            get(handlers::members::get_members).post(handlers::members::post_member),
        )
        .route(
            "/{chat_id}/members/{uid}",
            delete(handlers::members::delete_member).patch(handlers::members::patch_member),
        );

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

    let app = Router::new()
        .route("/health", get(health))
        .route("/ws", get(handlers::ws::ws_handler))
        .nest("/chats", chat_routes)
        .layer(
            ServiceBuilder::new()
                .layer(trace_layer)
                .set_x_request_id(RequestIdMaker)
                .propagate_x_request_id(),
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
