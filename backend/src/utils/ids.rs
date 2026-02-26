use ferroid::{
    futures::SnowflakeGeneratorAsyncTokioExt,
    generator::LockSnowflakeGenerator,
    id::SnowflakeMastodonId,
    time::{MonotonicClock, MASTODON_EPOCH},
};

pub type IdGen = LockSnowflakeGenerator<SnowflakeMastodonId, MonotonicClock>;

/// Create a shared snowflake ID generator. Node id from `FERROID_NODE_ID` env or 0.
pub fn new_generator() -> IdGen {
    let node_id: u64 = std::env::var("FERROID_NODE_ID")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);
    LockSnowflakeGenerator::new(node_id, MonotonicClock::with_epoch(MASTODON_EPOCH))
}

/// Generate next snowflake id as i64 (for gid, message id, attachment_id).
pub async fn next_id(gen: &IdGen) -> Result<i64, ferroid::generator::Error> {
    let id: SnowflakeMastodonId = gen.try_next_id_async().await?;
    Ok(id.to_raw() as i64)
}

/// Generate next gid (group/chat id).
pub async fn next_gid(gen: &IdGen) -> Result<i64, ferroid::generator::Error> {
    next_id(gen).await
}

/// Generate next message id.
pub async fn next_message_id(gen: &IdGen) -> Result<i64, ferroid::generator::Error> {
    next_id(gen).await
}

/// Generate next attachment id.
pub async fn next_attachment_id(gen: &IdGen) -> Result<i64, ferroid::generator::Error> {
    next_id(gen).await
}
