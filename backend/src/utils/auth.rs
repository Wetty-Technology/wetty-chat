use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
};
use std::fmt;

const X_USER_ID: &str = "x-user-id";

/// Placeholder auth: trusted user id from `X-User-Id` header. Returns 401 if missing or invalid.
#[derive(Clone, Copy, Debug)]
pub struct CurrentUid(pub i32);

impl fmt::Display for CurrentUid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

impl<S> FromRequestParts<S> for CurrentUid
where
    S: Send + Sync,
{
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        let value = parts
            .headers
            .get(X_USER_ID)
            .and_then(|v| v.to_str().ok())
            .ok_or((StatusCode::UNAUTHORIZED, "Missing or invalid X-User-Id header"))?;
        let uid = value
            .trim()
            .parse::<i32>()
            .map_err(|_| (StatusCode::UNAUTHORIZED, "X-User-Id must be a valid i32"))?;
        Ok(CurrentUid(uid))
    }
}
