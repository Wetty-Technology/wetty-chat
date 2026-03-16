use axum::extract::{MatchedPath, State};
use axum::http::{header, HeaderValue, Request, StatusCode};
use axum::middleware::Next;
use axum::response::{IntoResponse, Response};
use prometheus::{
    histogram_opts, opts, Encoder, Histogram, HistogramVec, IntCounter, IntCounterVec, Registry,
    TextEncoder,
};
use std::sync::Arc;
use std::time::Instant;

#[derive(Clone)]
pub(crate) struct Metrics {
    registry: Registry,
    http_requests_total: IntCounterVec,
    http_request_duration_seconds: HistogramVec,
    messages_total: IntCounterVec,
    discuz_username_lookup_duration_seconds: Histogram,
    discuz_username_lookup_users_total: IntCounter,
    discuz_avatar_lookup_duration_seconds: Histogram,
    discuz_avatar_lookup_fs_duration_seconds: Histogram,
    discuz_avatar_lookup_users_total: IntCounter,
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
        let discuz_username_lookup_duration_seconds = Histogram::with_opts(histogram_opts!(
            "discuz_username_lookup_duration_seconds",
            "Discuz username lookup latency in seconds",
            vec![0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0]
        ))
        .expect("discuz_username_lookup_duration_seconds metric should be valid");
        let discuz_username_lookup_users_total = IntCounter::with_opts(opts!(
            "discuz_username_lookup_users_total",
            "Total number of requested users processed by Discuz username lookups"
        ))
        .expect("discuz_username_lookup_users_total metric should be valid");
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
            .register(Box::new(discuz_username_lookup_duration_seconds.clone()))
            .expect("discuz_username_lookup_duration_seconds registration should succeed");
        registry
            .register(Box::new(discuz_username_lookup_users_total.clone()))
            .expect("discuz_username_lookup_users_total registration should succeed");
        registry
            .register(Box::new(discuz_avatar_lookup_duration_seconds.clone()))
            .expect("discuz_avatar_lookup_duration_seconds registration should succeed");
        registry
            .register(Box::new(discuz_avatar_lookup_fs_duration_seconds.clone()))
            .expect("discuz_avatar_lookup_fs_duration_seconds registration should succeed");
        registry
            .register(Box::new(discuz_avatar_lookup_users_total.clone()))
            .expect("discuz_avatar_lookup_users_total registration should succeed");

        Self {
            registry,
            http_requests_total,
            http_request_duration_seconds,
            messages_total,
            discuz_username_lookup_duration_seconds,
            discuz_username_lookup_users_total,
            discuz_avatar_lookup_duration_seconds,
            discuz_avatar_lookup_fs_duration_seconds,
            discuz_avatar_lookup_users_total,
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

    pub(crate) fn record_discuz_username_lookup(
        &self,
        requested_users: usize,
        duration_seconds: f64,
    ) {
        self.discuz_username_lookup_duration_seconds
            .observe(duration_seconds);
        self.discuz_username_lookup_users_total
            .inc_by(requested_users as u64);
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
}

pub(crate) async fn track_http_metrics(
    State(metrics): State<Arc<Metrics>>,
    request: Request<axum::body::Body>,
    next: Next,
) -> Response {
    let method = request.method().as_str().to_string();
    let route = route_label(request.extensions().get::<MatchedPath>().map(MatchedPath::as_str));
    let start = Instant::now();

    let response = next.run(request).await;
    metrics.record_http(&method, &route, response.status(), start.elapsed().as_secs_f64());

    response
}

pub(crate) async fn metrics_handler(
    State(metrics): State<Arc<Metrics>>,
) -> Result<impl IntoResponse, StatusCode> {
    let body = metrics.render().map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
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
        metrics.record_discuz_username_lookup(2, 0.002);
        metrics.record_discuz_avatar_lookup(2, 0.003, 0.001);
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
        assert!(body.contains("discuz_username_lookup_duration_seconds"));
        assert!(body.contains("discuz_username_lookup_users_total"));
        assert!(body.contains("discuz_avatar_lookup_duration_seconds"));
        assert!(body.contains("discuz_avatar_lookup_fs_duration_seconds"));
        assert!(body.contains("discuz_avatar_lookup_users_total"));
    }

    #[tokio::test]
    async fn http_metrics_count_requests_by_matched_route() {
        let metrics = Arc::new(Metrics::new());
        let app = Router::new()
            .route("/items/{id}", get(ok_handler))
            .layer(middleware::from_fn_with_state(
                metrics.clone(),
                track_http_metrics,
            ));

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
        let app = Router::new()
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
        metrics.record_discuz_username_lookup(3, 0.012);
        metrics.record_discuz_avatar_lookup(3, 0.015, 0.006);

        let rendered = metrics.render().expect("metrics should render");
        assert!(rendered.contains("messages_total{chat_id=\"123\"} 1"));
        assert!(rendered.contains("discuz_username_lookup_duration_seconds_sum"));
        assert!(rendered.contains("discuz_username_lookup_users_total 3"));
        assert!(rendered.contains("discuz_avatar_lookup_duration_seconds_sum"));
        assert!(rendered.contains("discuz_avatar_lookup_fs_duration_seconds_sum"));
        assert!(rendered.contains("discuz_avatar_lookup_users_total 3"));
    }
}
