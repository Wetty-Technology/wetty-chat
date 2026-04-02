use axum::extract::FromRequestParts;
use diesel::r2d2::{ConnectionManager, PooledConnection};
use diesel::PgConnection;
use std::ops::{Deref, DerefMut};

use crate::errors::AppError;
use crate::AppState;

/// Axum extractor that acquires a pooled database connection from `AppState.db`.
///
/// Usage in handler functions:
/// ```ignore
/// async fn my_handler(
///     mut conn: DbConn,
///     // ...
/// ) -> Result<..., AppError> {
///     some_query.load(&mut *conn)?;
/// }
/// ```
///
/// Implements `Deref`/`DerefMut` to `PgConnection` so it can be passed directly
/// to Diesel query methods.
pub struct DbConn(pub PooledConnection<ConnectionManager<PgConnection>>);

impl Deref for DbConn {
    type Target = PgConnection;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl DerefMut for DbConn {
    fn deref_mut(&mut self) -> &mut Self::Target {
        &mut self.0
    }
}

impl FromRequestParts<AppState> for DbConn {
    type Rejection = AppError;

    async fn from_request_parts(
        _parts: &mut axum::http::request::Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        let conn = state.db.get()?;
        Ok(DbConn(conn))
    }
}
