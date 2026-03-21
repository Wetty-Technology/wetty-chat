use axum::extract::{MatchedPath, State};
use axum::http::{header, HeaderValue, Request, StatusCode};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use prometheus::{
    histogram_opts, opts, Encoder, Histogram, HistogramVec, IntCounter, IntCounterVec, IntGauge,
    Registry, TextEncoder,
};
use std::sync::Arc;
use std::time::Instant;

#[derive(Clone)]
pub(crate) struct Metrics {
    registry: Registry,
    http_requests_total: IntCounterVec,
    http_request_duration_seconds: HistogramVec,
    messages_total: IntCounterVec,
    push_notifications_total: IntCounterVec,
    push_notifications_suppressed_total: IntCounter,
    ws_connected_users: IntGauge,
    ws_active_connections: IntGauge,
    ws_inactive_connections: IntGauge,
    ws_connections_total: IntCounter,
    ws_connection_duration_seconds: Histogram,
    discuz_avatar_lookup_duration_seconds: Histogram,
    discuz_avatar_lookup_fs_duration_seconds: Histogram,
    discuz_avatar_lookup_users_total: IntCounter,
    ws_messages_pushed_total: IntCounterVec,
    ws_messages_dropped_total: IntCounterVec,
}

impl Metrics {
    pub(crate) fn new() -> Self {
        let registry = Registry::new();
        let http_requests_total = IntCounterVec::new(
            opts!(
                "http_requests_total",
                "Total number of HTTP requests handled by the API server"
            ),
            &["method", "route", "status"],
        )
        .expect("http_requests_total metric should be valid");
        let http_request_duration_seconds = HistogramVec::new(
            histogram_opts!(
                "http_request_duration_seconds",
                "HTTP request latency in seconds for the API server",
                vec![0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
            ),
            &["method", "route", "status"],
        )
        .expect("http_request_duration_seconds metric should be valid");
        let messages_total = IntCounterVec::new(
            opts!(
                "messages_total",
                "Total number of messages successfully persisted"
            ),
            &["chat_id"],
        )
        .expect("messages_total metric should be valid");
        let push_notifications_total = IntCounterVec::new(
            opts!(
                "push_notifications_total",
                "Total number of push notification delivery attempts"
            ),
            &["result"],
        )
        .expect("push_notifications_total metric should be valid");
        let push_notifications_suppressed_total = IntCounter::with_opts(opts!(
            "push_notifications_suppressed_total",
            "Total number of push notifications skipped because a user had active websocket presence"
        ))
        .expect("push_notifications_suppressed_total metric should be valid");
        let ws_connected_users = IntGauge::with_opts(opts!(
            "ws_connected_users",
            "Current number of users with at least one active websocket connection"
        ))
        .expect("ws_connected_users metric should be valid");
        let ws_active_connections = IntGauge::with_opts(opts!(
            "ws_active_connections",
            "Current number of websocket connections reporting active app presence"
        ))
        .expect("ws_active_connections metric should be valid");
        let ws_inactive_connections = IntGauge::with_opts(opts!(
            "ws_inactive_connections",
            "Current number of websocket connections reporting inactive app presence"
        ))
        .expect("ws_inactive_connections metric should be valid");
        let ws_connections_total = IntCounter::with_opts(opts!(
            "ws_connections_total",
            "Total number of successfully established websocket connections"
        ))
        .expect("ws_connections_total metric should be valid");
        let ws_connection_duration_seconds = Histogram::with_opts(histogram_opts!(
            "ws_connection_duration_seconds",
            "Lifetime of websocket connections in seconds",
            vec![1.0, 5.0, 15.0, 30.0, 60.0, 300.0, 900.0, 1800.0, 3600.0, 14400.0]
        ))
        .expect("ws_connection_duration_seconds metric should be valid");
        let discuz_avatar_lookup_duration_seconds = Histogram::with_opts(histogram_opts!(
            "discuz_avatar_lookup_duration_seconds",
            "Discuz avatar lookup latency in seconds",
            vec![0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
        ))
        .expect("discuz_avatar_lookup_duration_seconds metric should be valid");
        let discuz_avatar_lookup_fs_duration_seconds = Histogram::with_opts(histogram_opts!(
            "discuz_avatar_lookup_fs_duration_seconds",
            "Filesystem portion of Discuz avatar lookup latency in seconds",
            vec![0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
        ))
        .expect("discuz_avatar_lookup_fs_duration_seconds metric should be valid");
        let discuz_avatar_lookup_users_total = IntCounter::with_opts(opts!(
            "discuz_avatar_lookup_users_total",
            "Total number of requested users processed by Discuz avatar lookups"
        ))
        .expect("discuz_avatar_lookup_users_total metric should be valid");
        let ws_messages_pushed_total = IntCounterVec::new(
            opts!(
                "ws_messages_pushed_total",
                "Total number of messages successfully pushed to websocket connections"
            ),
            &["message_type"],
        )
        .expect("ws_messages_pushed_total metric should be valid");
        let ws_messages_dropped_total = IntCounterVec::new(
            opts!(
                "ws_messages_dropped_total",
                "Total number of messages dropped due to full websocket send buffer"
            ),
            &["message_type"],
        )
        .expect("ws_messages_dropped_total metric should be valid");

        registry
            .register(Box::new(http_requests_total.clone()))
            .expect("http_requests_total registration should succeed");
        registry
            .register(Box::new(http_request_duration_seconds.clone()))
            .expect("http_request_duration_seconds registration should succeed");
        registry
            .register(Box::new(messages_total.clone()))
            .expect("messages_total registration should succeed");
        registry
            .register(Box::new(push_notifications_total.clone()))
            .expect("push_notifications_total registration should succeed");
        registry
            .register(Box::new(push_notifications_suppressed_total.clone()))
            .expect("push_notifications_suppressed_total registration should succeed");
        registry
            .register(Box::new(ws_connected_users.clone()))
            .expect("ws_connected_users registration should succeed");
        registry
            .register(Box::new(ws_active_connections.clone()))
            .expect("ws_active_connections registration should succeed");
        registry
            .register(Box::new(ws_inactive_connections.clone()))
            .expect("ws_inactive_connections registration should succeed");
        registry
            .register(Box::new(ws_connections_total.clone()))
            .expect("ws_connections_total registration should succeed");
        registry
            .register(Box::new(ws_connection_duration_seconds.clone()))
            .expect("ws_connection_duration_seconds registration should succeed");
        registry
            .register(Box::new(discuz_avatar_lookup_duration_seconds.clone()))
            .expect("discuz_avatar_lookup_duration_seconds registration should succeed");
        registry
            .register(Box::new(discuz_avatar_lookup_fs_duration_seconds.clone()))
            .expect("discuz_avatar_lookup_fs_duration_seconds registration should succeed");
        registry
            .register(Box::new(discuz_avatar_lookup_users_total.clone()))
            .expect("discuz_avatar_lookup_users_total registration should succeed");
        registry
            .register(Box::new(ws_messages_pushed_total.clone()))
            .expect("ws_messages_pushed_total registration should succeed");
        registry
            .register(Box::new(ws_messages_dropped_total.clone()))
            .expect("ws_messages_dropped_total registration should succeed");

        Self {
            registry,
            http_requests_total,
            http_request_duration_seconds,
            messages_total,
            push_notifications_total,
            push_notifications_suppressed_total,
            ws_connected_users,
            ws_active_connections,
            ws_inactive_connections,
            ws_connections_total,
            ws_connection_duration_seconds,
            discuz_avatar_lookup_duration_seconds,
            discuz_avatar_lookup_fs_duration_seconds,
            discuz_avatar_lookup_users_total,
            ws_messages_pushed_total,
            ws_messages_dropped_total,
        }
    }

    pub(crate) fn record_http(
        &self,
        method: &str,
        route: &str,
        status: StatusCode,
        duration_seconds: f64,
    ) {
        let status = status.as_u16().to_string();
        self.http_requests_total
            .with_label_values(&[method, route, &status])
            .inc();
        self.http_request_duration_seconds
            .with_label_values(&[method, route, &status])
            .observe(duration_seconds);
    }

    pub(crate) fn render(&self) -> Result<String, prometheus::Error> {
        let metric_families = self.registry.gather();
        let mut output = Vec::new();
        TextEncoder::new().encode(&metric_families, &mut output)?;
        String::from_utf8(output)
            .map_err(|err| prometheus::Error::Msg(err.utf8_error().to_string()))
    }

    pub(crate) fn record_message(&self, chat_id: i64) {
        let chat_id = chat_id.to_string();
        self.messages_total.with_label_values(&[&chat_id]).inc();
    }

    pub(crate) fn record_push_notification(&self, success: bool) {
        let result = if success { "success" } else { "failure" };
        self.push_notifications_total
            .with_label_values(&[result])
            .inc();
    }

    pub(crate) fn set_ws_connected_users(&self, connected_users: usize) {
        self.ws_connected_users.set(connected_users as i64);
    }

    pub(crate) fn set_ws_connection_states(
        &self,
        active_connections: usize,
        inactive_connections: usize,
    ) {
        self.ws_active_connections.set(active_connections as i64);
        self.ws_inactive_connections
            .set(inactive_connections as i64);
    }

    pub(crate) fn record_push_suppressed(&self) {
        self.push_notifications_suppressed_total.inc();
    }

    pub(crate) fn record_ws_connection_open(&self) {
        self.ws_connections_total.inc();
    }

    pub(crate) fn record_ws_connection_duration(&self, duration_seconds: f64) {
        self.ws_connection_duration_seconds
            .observe(duration_seconds);
    }

    pub(crate) fn record_discuz_avatar_lookup(
        &self,
        requested_users: usize,
        duration_seconds: f64,
        fs_duration_seconds: f64,
    ) {
        self.discuz_avatar_lookup_duration_seconds
            .observe(duration_seconds);
        self.discuz_avatar_lookup_fs_duration_seconds
            .observe(fs_duration_seconds);
        self.discuz_avatar_lookup_users_total
            .inc_by(requested_users as u64);
    }

    pub(crate) fn record_ws_message_pushed(&self, message_type: &str) {
        self.ws_messages_pushed_total
            .with_label_values(&[message_type])
            .inc();
    }

    pub(crate) fn record_ws_message_dropped(&self, message_type: &str) {
        self.ws_messages_dropped_total
            .with_label_values(&[message_type])
            .inc();
    }
}

pub(crate) async fn track_http_metrics(
    State(metrics): State<Arc<Metrics>>,
    request: Request<axum::body::Body>,
    next: Next,
) -> Response {
    let method = request.method().as_str().to_string();
    let route = route_label(
        request
            .extensions()
            .get::<MatchedPath>()
            .map(MatchedPath::as_str),
    );
    let start = Instant::now();

    let response = next.run(request).await;
    metrics.record_http(
        &method,
        &route,
        response.status(),
        start.elapsed().as_secs_f64(),
    );

    response
}

pub(crate) async fn metrics_handler(
    State(metrics): State<Arc<Metrics>>,
) -> Result<impl IntoResponse, StatusCode> {
    let body = metrics
        .render()
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let encoder = TextEncoder::new();
    let mut response = body.into_response();
    response.headers_mut().insert(
        header::CONTENT_TYPE,
        HeaderValue::from_str(encoder.format_type()).expect("prometheus content type is valid"),
    );
    Ok(response)
}

fn route_label(matched_path: Option<&str>) -> String {
    matched_path.unwrap_or("unknown").to_string()
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request as HttpRequest;
    use axum::routing::get;
    use axum::{middleware, Router};
    use tower::ServiceExt;

    async fn ok_handler() -> &'static str {
        "ok"
    }

    async fn not_found_handler() -> StatusCode {
        StatusCode::NOT_FOUND
    }

    #[test]
    fn route_label_falls_back_to_unknown() {
        assert_eq!(route_label(None), "unknown");
    }

    #[tokio::test]
    async fn metrics_endpoint_renders_registered_collectors() {
        let metrics = Arc::new(Metrics::new());
        metrics.record_http("GET", "/seed", StatusCode::OK, 0.001);
        metrics.record_message(42);
        metrics.record_push_notification(true);
        metrics.record_push_suppressed();
        metrics.set_ws_connected_users(2);
        metrics.set_ws_connection_states(1, 1);
        metrics.record_ws_connection_open();
        metrics.record_ws_connection_duration(12.0);
        metrics.record_discuz_avatar_lookup(2, 0.003, 0.001);
        metrics.record_ws_message_pushed("message");
        metrics.record_ws_message_dropped("message");
        let app = Router::new()
            .route("/metrics", get(metrics_handler))
            .with_state(metrics);

        let response = app
            .oneshot(
                HttpRequest::builder()
                    .uri("/metrics")
                    .body(Body::empty())
                    .expect("request should build"),
            )
            .await
            .expect("metrics route should respond");

        assert_eq!(response.status(), StatusCode::OK);
        let body = axum::body::to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("body should be readable");
        let body = String::from_utf8(body.to_vec()).expect("metrics body should be utf8");
        assert!(body.contains("http_requests_total"));
        assert!(body.contains("http_request_duration_seconds"));
        assert!(body.contains("messages_total"));
        assert!(body.contains("push_notifications_total"));
        assert!(body.contains("push_notifications_suppressed_total"));
        assert!(body.contains("ws_connected_users"));
        assert!(body.contains("ws_active_connections"));
        assert!(body.contains("ws_inactive_connections"));
        assert!(body.contains("ws_connections_total"));
        assert!(body.contains("ws_connection_duration_seconds"));
        assert!(body.contains("discuz_avatar_lookup_duration_seconds"));
        assert!(body.contains("discuz_avatar_lookup_fs_duration_seconds"));
        assert!(body.contains("discuz_avatar_lookup_users_total"));
        assert!(body.contains("ws_messages_pushed_total"));
        assert!(body.contains("ws_messages_dropped_total"));
    }

    #[tokio::test]
    async fn http_metrics_count_requests_by_matched_route() {
        let metrics = Arc::new(Metrics::new());
        let app = Router::new().route("/items/{id}", get(ok_handler)).layer(
            middleware::from_fn_with_state(metrics.clone(), track_http_metrics),
        );

        let response = app
            .oneshot(
                HttpRequest::builder()
                    .method("GET")
                    .uri("/items/42")
                    .body(Body::empty())
                    .expect("request should build"),
            )
            .await
            .expect("app should respond");

        assert_eq!(response.status(), StatusCode::OK);

        let rendered = metrics.render().expect("metrics should render");
        assert!(rendered.contains("http_requests_total"));
        assert!(rendered.contains("method=\"GET\",route=\"/items/{id}\",status=\"200\""));
    }

    #[tokio::test]
    async fn http_metrics_record_unknown_for_unmatched_requests() {
        let metrics = Arc::new(Metrics::new());
        let app =
            Router::new()
                .fallback(get(not_found_handler))
                .layer(middleware::from_fn_with_state(
                    metrics.clone(),
                    track_http_metrics,
                ));

        let response = app
            .oneshot(
                HttpRequest::builder()
                    .method("GET")
                    .uri("/missing")
                    .body(Body::empty())
                    .expect("request should build"),
            )
            .await
            .expect("app should respond");

        assert_eq!(response.status(), StatusCode::NOT_FOUND);

        let rendered = metrics.render().expect("metrics should render");
        assert!(rendered.contains("method=\"GET\",route=\"unknown\",status=\"404\""));
    }

    #[test]
    fn discuz_metrics_render_expected_values() {
        let metrics = Metrics::new();
        metrics.record_message(123);
        metrics.record_push_notification(true);
        metrics.record_push_notification(false);
        metrics.record_push_suppressed();
        metrics.set_ws_connected_users(1);
        metrics.set_ws_connection_states(1, 0);
        metrics.record_ws_connection_open();
        metrics.record_ws_connection_duration(30.0);
        metrics.record_discuz_avatar_lookup(3, 0.015, 0.006);
        metrics.record_ws_message_pushed("message");
        metrics.record_ws_message_pushed("message");
        metrics.record_ws_message_dropped("message_updated");

        let rendered = metrics.render().expect("metrics should render");
        assert!(rendered.contains("messages_total{chat_id=\"123\"} 1"));
        assert!(rendered.contains("push_notifications_total{result=\"success\"} 1"));
        assert!(rendered.contains("push_notifications_total{result=\"failure\"} 1"));
        assert!(rendered.contains("push_notifications_suppressed_total 1"));
        assert!(rendered.contains("ws_connected_users 1"));
        assert!(rendered.contains("ws_active_connections 1"));
        assert!(rendered.contains("ws_inactive_connections 0"));
        assert!(rendered.contains("ws_connections_total 1"));
        assert!(rendered.contains("ws_connection_duration_seconds_sum"));
        assert!(rendered.contains("discuz_avatar_lookup_duration_seconds_sum"));
        assert!(rendered.contains("discuz_avatar_lookup_fs_duration_seconds_sum"));
        assert!(rendered.contains("discuz_avatar_lookup_users_total 3"));
        assert!(rendered.contains("ws_messages_pushed_total{message_type=\"message\"} 2"));
        assert!(rendered.contains("ws_messages_dropped_total{message_type=\"message_updated\"} 1"));
    }
}
