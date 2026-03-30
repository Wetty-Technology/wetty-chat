use aws_sdk_s3::primitives::ByteStream;
use axum::{
    extract::{Json, Multipart, Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post, put},
    Json as AxumJson, Router,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

use crate::{
    models::{
        Media, MediaPurpose, NewMedia, NewSticker, NewStickerPack, Sticker, StickerPack,
        StickerPackSticker, UpdateStickerPack, UserFavoriteSticker, UserStickerPackSubscription,
    },
    schema::{
        media, sticker_pack_stickers, sticker_packs, stickers, user_favorite_stickers,
        user_sticker_pack_subscriptions,
    },
    services::{
        media::{build_public_object_url, build_storage_key, upload_public_object},
        user::lookup_user_profiles,
    },
    utils::{auth::CurrentUid, ids},
    AppState,
};

const MAX_STICKER_UPLOAD_BYTES: usize = 1024 * 1024;
const STICKER_STORAGE_PREFIX: &str = "stickers";
const MAX_STICKER_EMOJI_GRAPHEMES: usize = 4;

type DbConn = diesel::r2d2::PooledConnection<diesel::r2d2::ConnectionManager<diesel::PgConnection>>;

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateStickerPackBody {
    name: String,
    description: Option<String>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateStickerPackBody {
    name: Option<String>,
    description: Option<String>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct StickerMediaResponse {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    url: String,
    content_type: String,
    size: i64,
    width: Option<i32>,
    height: Option<i32>,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct StickerSummary {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    media: StickerMediaResponse,
    emoji: String,
    name: Option<String>,
    description: Option<String>,
    created_at: DateTime<Utc>,
    is_favorited: bool,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct StickerPackPreviewSticker {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    media: StickerMediaResponse,
    emoji: String,
}

#[derive(Debug, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
struct StickerPackSummary {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    owner_uid: i32,
    owner_name: Option<String>,
    name: String,
    description: Option<String>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    sticker_count: i64,
    is_subscribed: bool,
    preview_sticker: Option<StickerPackPreviewSticker>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StickerPackDetailResponse {
    #[serde(flatten)]
    pack: StickerPackSummary,
    stickers: Vec<StickerSummary>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StickerDetailResponse {
    #[serde(flatten)]
    sticker: StickerSummary,
    packs: Vec<StickerPackSummary>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct StickerPackListResponse {
    packs: Vec<StickerPackSummary>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct FavoriteStickerListResponse {
    stickers: Vec<StickerSummary>,
}

fn normalize_required_name(input: &str) -> Result<String, (StatusCode, &'static str)> {
    let trimmed = input.trim();
    if trimmed.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Name is required"));
    }
    Ok(trimmed.to_string())
}

fn validate_sticker_emoji(input: &str) -> Result<String, (StatusCode, &'static str)> {
    use unicode_segmentation::UnicodeSegmentation;

    if input.is_empty() {
        return Err((StatusCode::BAD_REQUEST, "Invalid emoji"));
    }

    let graphemes: Vec<&str> = input.graphemes(true).collect();

    if graphemes.len() > MAX_STICKER_EMOJI_GRAPHEMES {
        return Err((StatusCode::BAD_REQUEST, "Too many emoji"));
    }

    if !graphemes.iter().all(|g| emojis::get(g).is_some()) {
        return Err((StatusCode::BAD_REQUEST, "Invalid emoji"));
    }

    Ok(input.to_string())
}

fn is_allowed_sticker_content_type(content_type: &str) -> bool {
    content_type.starts_with("image/") || content_type == "video/webm"
}

fn media_response(state: &AppState, media_row: &Media) -> StickerMediaResponse {
    StickerMediaResponse {
        id: media_row.id,
        url: build_public_object_url(state, &media_row.storage_key),
        content_type: media_row.content_type.clone(),
        size: media_row.size,
        width: media_row.width,
        height: media_row.height,
    }
}

fn require_pack_owner(
    conn: &mut DbConn,
    pack_id: i64,
    uid: i32,
) -> Result<StickerPack, (StatusCode, &'static str)> {
    let pack: StickerPack = sticker_packs::table
        .filter(sticker_packs::id.eq(pack_id))
        .select(StickerPack::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker pack not found"))?;

    if pack.owner_uid != uid {
        return Err((StatusCode::FORBIDDEN, "Sticker pack owner required"));
    }

    Ok(pack)
}

fn load_pack_counts(conn: &mut DbConn, pack_ids: &[i64]) -> QueryResult<HashMap<i64, i64>> {
    if pack_ids.is_empty() {
        return Ok(HashMap::new());
    }

    let rows: Vec<(i64, i64)> = sticker_pack_stickers::table
        .filter(sticker_pack_stickers::pack_id.eq_any(pack_ids))
        .group_by(sticker_pack_stickers::pack_id)
        .select((sticker_pack_stickers::pack_id, diesel::dsl::count_star()))
        .load(conn)?;

    Ok(rows.into_iter().collect())
}

fn load_subscribed_pack_ids(
    conn: &mut DbConn,
    uid: i32,
    pack_ids: &[i64],
) -> QueryResult<HashSet<i64>> {
    if pack_ids.is_empty() {
        return Ok(HashSet::new());
    }

    let rows: Vec<i64> = user_sticker_pack_subscriptions::table
        .filter(user_sticker_pack_subscriptions::uid.eq(uid))
        .filter(user_sticker_pack_subscriptions::pack_id.eq_any(pack_ids))
        .select(user_sticker_pack_subscriptions::pack_id)
        .load(conn)?;

    Ok(rows.into_iter().collect())
}

fn load_favorited_sticker_ids(
    conn: &mut DbConn,
    uid: i32,
    sticker_ids: &[i64],
) -> QueryResult<HashSet<i64>> {
    if sticker_ids.is_empty() {
        return Ok(HashSet::new());
    }

    let rows: Vec<i64> = user_favorite_stickers::table
        .filter(user_favorite_stickers::uid.eq(uid))
        .filter(user_favorite_stickers::sticker_id.eq_any(sticker_ids))
        .select(user_favorite_stickers::sticker_id)
        .load(conn)?;

    Ok(rows.into_iter().collect())
}

fn load_first_stickers_for_packs(
    conn: &mut DbConn,
    state: &AppState,
    pack_ids: &[i64],
) -> QueryResult<HashMap<i64, StickerPackPreviewSticker>> {
    if pack_ids.is_empty() {
        return Ok(HashMap::new());
    }

    // For each pack, find the sticker with the earliest added_at
    // Using DISTINCT ON (PostgreSQL) to get one row per pack
    let rows: Vec<(i64, Sticker, Media)> = sticker_pack_stickers::table
        .inner_join(stickers::table.inner_join(media::table))
        .filter(sticker_pack_stickers::pack_id.eq_any(pack_ids))
        .order((
            sticker_pack_stickers::pack_id.asc(),
            sticker_pack_stickers::added_at.asc(),
        ))
        .distinct_on(sticker_pack_stickers::pack_id)
        .select((
            sticker_pack_stickers::pack_id,
            Sticker::as_select(),
            Media::as_select(),
        ))
        .load(conn)?;

    Ok(rows
        .into_iter()
        .map(|(pack_id, sticker, media_row)| {
            (
                pack_id,
                StickerPackPreviewSticker {
                    id: sticker.id,
                    media: media_response(state, &media_row),
                    emoji: sticker.emoji,
                },
            )
        })
        .collect())
}

fn build_pack_summaries(
    conn: &mut DbConn,
    state: &AppState,
    uid: i32,
    packs: Vec<StickerPack>,
) -> Result<Vec<StickerPackSummary>, (StatusCode, &'static str)> {
    let pack_ids: Vec<i64> = packs.iter().map(|pack| pack.id).collect();
    let owner_uids: Vec<i32> = packs
        .iter()
        .map(|pack| pack.owner_uid)
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();

    let counts = load_pack_counts(conn, &pack_ids).map_err(|e| {
        tracing::error!("load sticker pack counts: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to load sticker packs",
        )
    })?;
    let subscribed = load_subscribed_pack_ids(conn, uid, &pack_ids).map_err(|e| {
        tracing::error!("load sticker pack subscriptions: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to load sticker packs",
        )
    })?;
    let mut previews = load_first_stickers_for_packs(conn, state, &pack_ids).map_err(|e| {
        tracing::error!("load pack preview stickers: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to load sticker packs",
        )
    })?;
    let owner_profiles = lookup_user_profiles(conn, &owner_uids).unwrap_or_default();

    Ok(packs
        .into_iter()
        .map(|pack| {
            let preview_sticker = previews.remove(&pack.id);
            StickerPackSummary {
                id: pack.id,
                owner_uid: pack.owner_uid,
                owner_name: owner_profiles
                    .get(&pack.owner_uid)
                    .and_then(|profile| profile.username.clone()),
                name: pack.name,
                description: pack.description,
                created_at: pack.created_at,
                updated_at: pack.updated_at,
                sticker_count: *counts.get(&pack.id).unwrap_or(&0),
                is_subscribed: subscribed.contains(&pack.id),
                preview_sticker,
            }
        })
        .collect())
}

fn load_sticker_rows_for_pack(
    conn: &mut DbConn,
    pack_id: i64,
) -> Result<Vec<(Sticker, Media)>, (StatusCode, &'static str)> {
    sticker_pack_stickers::table
        .inner_join(stickers::table.inner_join(media::table))
        .filter(sticker_pack_stickers::pack_id.eq(pack_id))
        .order((
            sticker_pack_stickers::added_at.asc(),
            sticker_pack_stickers::sticker_id.asc(),
        ))
        .select((Sticker::as_select(), Media::as_select()))
        .load(conn)
        .map_err(|e| {
            tracing::error!("load pack stickers: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to load pack stickers",
            )
        })
}

fn build_sticker_summaries(
    conn: &mut DbConn,
    state: &AppState,
    uid: i32,
    rows: Vec<(Sticker, Media)>,
) -> Result<Vec<StickerSummary>, (StatusCode, &'static str)> {
    let sticker_ids: Vec<i64> = rows.iter().map(|(sticker, _)| sticker.id).collect();
    let favorites = load_favorited_sticker_ids(conn, uid, &sticker_ids).map_err(|e| {
        tracing::error!("load favorite stickers: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to load favorite stickers",
        )
    })?;

    Ok(rows
        .into_iter()
        .map(|(sticker, media_row)| StickerSummary {
            id: sticker.id,
            media: media_response(state, &media_row),
            emoji: sticker.emoji,
            name: sticker.name,
            description: sticker.description,
            created_at: sticker.created_at,
            is_favorited: favorites.contains(&sticker.id),
        })
        .collect())
}

async fn post_pack(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Json(body): Json<CreateStickerPackBody>,
) -> Result<AxumJson<StickerPackSummary>, (StatusCode, &'static str)> {
    let name = normalize_required_name(&body.name)?;
    let now = Utc::now();
    let pack_id = ids::next_id(state.id_gen.as_ref()).await.map_err(|e| {
        tracing::error!("next_id for sticker pack: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to generate ID")
    })?;
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let pack = conn
        .transaction::<StickerPack, diesel::result::Error, _>(|conn| {
            diesel::insert_into(sticker_packs::table)
                .values(&NewStickerPack {
                    id: pack_id,
                    owner_uid: uid,
                    name: name.clone(),
                    description: body.description.clone(),
                    created_at: now,
                    updated_at: now,
                })
                .execute(conn)?;

            diesel::insert_into(user_sticker_pack_subscriptions::table)
                .values(&UserStickerPackSubscription {
                    uid,
                    pack_id,
                    subscribed_at: now,
                })
                .execute(conn)?;

            sticker_packs::table
                .filter(sticker_packs::id.eq(pack_id))
                .select(StickerPack::as_select())
                .first(conn)
        })
        .map_err(|e| {
            tracing::error!("create sticker pack: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to create sticker pack",
            )
        })?;

    let summary = build_pack_summaries(conn, &state, uid, vec![pack])?
        .into_iter()
        .next()
        .unwrap();
    Ok(AxumJson(summary))
}

async fn patch_pack(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(pack_id): Path<i64>,
    Json(body): Json<UpdateStickerPackBody>,
) -> Result<AxumJson<StickerPackSummary>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let _pack = require_pack_owner(conn, pack_id, uid)?;

    let name = match body.name {
        Some(ref name) => Some(normalize_required_name(name)?),
        None => None,
    };

    diesel::update(sticker_packs::table.filter(sticker_packs::id.eq(pack_id)))
        .set(&UpdateStickerPack {
            name,
            description: body.description,
            updated_at: Utc::now(),
        })
        .execute(conn)
        .map_err(|e| {
            tracing::error!("update sticker pack: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to update sticker pack",
            )
        })?;

    let pack = sticker_packs::table
        .filter(sticker_packs::id.eq(pack_id))
        .select(StickerPack::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker pack not found"))?;
    let summary = build_pack_summaries(conn, &state, uid, vec![pack])?
        .into_iter()
        .next()
        .unwrap();
    Ok(AxumJson(summary))
}

async fn get_pack(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(pack_id): Path<i64>,
) -> Result<AxumJson<StickerPackDetailResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let pack = sticker_packs::table
        .filter(sticker_packs::id.eq(pack_id))
        .select(StickerPack::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker pack not found"))?;

    let sticker_rows = load_sticker_rows_for_pack(conn, pack_id)?;
    let stickers = build_sticker_summaries(conn, &state, uid, sticker_rows)?;
    let pack = build_pack_summaries(conn, &state, uid, vec![pack])?
        .into_iter()
        .next()
        .unwrap();

    Ok(AxumJson(StickerPackDetailResponse { pack, stickers }))
}

async fn get_my_subscribed_packs(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<AxumJson<StickerPackListResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let packs: Vec<StickerPack> = user_sticker_pack_subscriptions::table
        .inner_join(sticker_packs::table)
        .filter(user_sticker_pack_subscriptions::uid.eq(uid))
        .order(user_sticker_pack_subscriptions::subscribed_at.desc())
        .select(StickerPack::as_select())
        .load(conn)
        .map_err(|e| {
            tracing::error!("load subscribed sticker packs: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to load sticker packs",
            )
        })?;

    Ok(AxumJson(StickerPackListResponse {
        packs: build_pack_summaries(conn, &state, uid, packs)?,
    }))
}

async fn get_my_owned_packs(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<AxumJson<StickerPackListResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let packs: Vec<StickerPack> = sticker_packs::table
        .filter(sticker_packs::owner_uid.eq(uid))
        .order(sticker_packs::created_at.desc())
        .select(StickerPack::as_select())
        .load(conn)
        .map_err(|e| {
            tracing::error!("load owned sticker packs: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to load sticker packs",
            )
        })?;

    Ok(AxumJson(StickerPackListResponse {
        packs: build_pack_summaries(conn, &state, uid, packs)?,
    }))
}

async fn put_subscription(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(pack_id): Path<i64>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let _pack: StickerPack = sticker_packs::table
        .filter(sticker_packs::id.eq(pack_id))
        .select(StickerPack::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker pack not found"))?;

    diesel::insert_into(user_sticker_pack_subscriptions::table)
        .values(&UserStickerPackSubscription {
            uid,
            pack_id,
            subscribed_at: Utc::now(),
        })
        .on_conflict_do_nothing()
        .execute(conn)
        .map_err(|e| {
            tracing::error!("subscribe sticker pack: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to subscribe sticker pack",
            )
        })?;

    Ok(StatusCode::NO_CONTENT)
}

async fn delete_subscription(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(pack_id): Path<i64>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let pack: StickerPack = sticker_packs::table
        .filter(sticker_packs::id.eq(pack_id))
        .select(StickerPack::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker pack not found"))?;

    if pack.owner_uid == uid {
        return Err((StatusCode::BAD_REQUEST, "Pack owner cannot unsubscribe"));
    }

    diesel::delete(
        user_sticker_pack_subscriptions::table
            .filter(user_sticker_pack_subscriptions::uid.eq(uid))
            .filter(user_sticker_pack_subscriptions::pack_id.eq(pack_id)),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("unsubscribe sticker pack: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to unsubscribe sticker pack",
        )
    })?;

    Ok(StatusCode::NO_CONTENT)
}

async fn post_pack_sticker(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(pack_id): Path<i64>,
    mut multipart: Multipart,
) -> Result<impl IntoResponse, (StatusCode, &'static str)> {
    let _pack = {
        let conn = &mut state.db.get().map_err(|_| {
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Database connection failed",
            )
        })?;
        require_pack_owner(conn, pack_id, uid)?
    };

    let mut emoji = None;
    let mut name = None;
    let mut description = None;
    let mut file_bytes = None;
    let mut file_name = None;
    let mut content_type = None;

    while let Some(field) = multipart.next_field().await.map_err(|e| {
        tracing::error!("read sticker multipart field: {:?}", e);
        (StatusCode::BAD_REQUEST, "Invalid multipart request")
    })? {
        let field_name = field.name().unwrap_or_default().to_string();
        match field_name.as_str() {
            "emoji" => {
                emoji = Some(
                    field
                        .text()
                        .await
                        .map_err(|_| (StatusCode::BAD_REQUEST, "Invalid emoji"))?,
                );
            }
            "name" => {
                name = Some(
                    field
                        .text()
                        .await
                        .map_err(|_| (StatusCode::BAD_REQUEST, "Invalid name"))?,
                );
            }
            "description" => {
                description = Some(
                    field
                        .text()
                        .await
                        .map_err(|_| (StatusCode::BAD_REQUEST, "Invalid description"))?,
                );
            }
            "file" => {
                content_type = field.content_type().map(ToString::to_string);
                file_name = field.file_name().map(ToString::to_string);
                let bytes = field.bytes().await.map_err(|e| {
                    tracing::error!("read sticker file bytes: {:?}", e);
                    (StatusCode::BAD_REQUEST, "Invalid sticker file")
                })?;
                if bytes.len() > MAX_STICKER_UPLOAD_BYTES {
                    return Err((StatusCode::BAD_REQUEST, "Sticker file too large"));
                }
                file_bytes = Some(bytes);
            }
            _ => {}
        }
    }

    let emoji = validate_sticker_emoji(
        emoji
            .as_deref()
            .ok_or((StatusCode::BAD_REQUEST, "Missing emoji"))?,
    )?;
    let content_type =
        content_type.ok_or((StatusCode::BAD_REQUEST, "Missing sticker file content type"))?;
    if !is_allowed_sticker_content_type(&content_type) {
        return Err((StatusCode::BAD_REQUEST, "Unsupported sticker content type"));
    }
    let file_bytes = file_bytes.ok_or((StatusCode::BAD_REQUEST, "Missing sticker file"))?;
    let file_name = file_name.unwrap_or_else(|| "sticker.bin".to_string());
    let sticker_name = name.and_then(|value| {
        let trimmed = value.trim().to_string();
        (!trimmed.is_empty()).then_some(trimmed)
    });
    let sticker_description = description.and_then(|value| {
        let trimmed = value.trim().to_string();
        (!trimmed.is_empty()).then_some(trimmed)
    });

    // TODO: Convert or normalize uploads to webp/webm if we later need stronger
    // client compatibility and file-size guarantees.
    let media_id = ids::next_id(state.id_gen.as_ref()).await.map_err(|e| {
        tracing::error!("next_id for sticker media: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to generate ID")
    })?;
    let sticker_id = ids::next_id(state.id_gen.as_ref()).await.map_err(|e| {
        tracing::error!("next_id for sticker: {:?}", e);
        (StatusCode::INTERNAL_SERVER_ERROR, "Failed to generate ID")
    })?;
    let storage_object_id = uuid::Uuid::new_v4().to_string();
    let storage_key = build_storage_key(STICKER_STORAGE_PREFIX, &file_name, &storage_object_id);

    upload_public_object(
        &state.s3_client,
        &state.s3_bucket_name,
        &storage_key,
        &content_type,
        ByteStream::from(file_bytes.clone()),
    )
    .await?;

    let now = Utc::now();
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    let create_result = conn.transaction::<(Sticker, Media), diesel::result::Error, _>(|conn| {
        diesel::insert_into(media::table)
            .values(&NewMedia {
                id: media_id,
                content_type: content_type.clone(),
                storage_key: storage_key.clone(),
                size: file_bytes.len() as i64,
                created_at: now,
                deleted_at: None,
                file_name: file_name.clone(),
                width: None,
                height: None,
                purpose: MediaPurpose::Sticker,
                reference: None,
            })
            .execute(conn)?;

        diesel::insert_into(stickers::table)
            .values(&NewSticker {
                id: sticker_id,
                media_id,
                emoji: emoji.clone(),
                name: sticker_name.clone(),
                description: sticker_description.clone(),
                created_at: now,
            })
            .execute(conn)?;

        diesel::insert_into(sticker_pack_stickers::table)
            .values(&StickerPackSticker {
                pack_id,
                sticker_id,
                added_at: now,
            })
            .execute(conn)?;

        let sticker = stickers::table
            .filter(stickers::id.eq(sticker_id))
            .select(Sticker::as_select())
            .first(conn)?;
        let media_row = media::table
            .filter(media::id.eq(media_id))
            .select(Media::as_select())
            .first(conn)?;
        Ok((sticker, media_row))
    });

    let (sticker, media_row) = match create_result {
        Ok(value) => value,
        Err(e) => {
            tracing::error!("create sticker: {:?}", e);
            let _ = state
                .s3_client
                .delete_object()
                .bucket(&state.s3_bucket_name)
                .key(&storage_key)
                .send()
                .await;
            return Err((
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to create sticker",
            ));
        }
    };

    let summary = StickerSummary {
        id: sticker.id,
        media: media_response(&state, &media_row),
        emoji: sticker.emoji,
        name: sticker.name,
        description: sticker.description,
        created_at: sticker.created_at,
        is_favorited: false,
    };

    Ok((StatusCode::CREATED, AxumJson(summary)))
}

async fn put_pack_sticker(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path((pack_id, sticker_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let _pack = require_pack_owner(conn, pack_id, uid)?;
    let _sticker: Sticker = stickers::table
        .filter(stickers::id.eq(sticker_id))
        .select(Sticker::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker not found"))?;

    diesel::insert_into(sticker_pack_stickers::table)
        .values(&StickerPackSticker {
            pack_id,
            sticker_id,
            added_at: Utc::now(),
        })
        .on_conflict_do_nothing()
        .execute(conn)
        .map_err(|e| {
            tracing::error!("attach sticker to pack: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to attach sticker to pack",
            )
        })?;

    Ok(StatusCode::NO_CONTENT)
}

async fn delete_pack_sticker(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path((pack_id, sticker_id)): Path<(i64, i64)>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let _pack = require_pack_owner(conn, pack_id, uid)?;

    diesel::delete(
        sticker_pack_stickers::table
            .filter(sticker_pack_stickers::pack_id.eq(pack_id))
            .filter(sticker_pack_stickers::sticker_id.eq(sticker_id)),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("detach sticker from pack: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to detach sticker from pack",
        )
    })?;

    Ok(StatusCode::NO_CONTENT)
}

async fn get_sticker(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(sticker_id): Path<i64>,
) -> Result<AxumJson<StickerDetailResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let (sticker, media_row): (Sticker, Media) = stickers::table
        .inner_join(media::table)
        .filter(stickers::id.eq(sticker_id))
        .select((Sticker::as_select(), Media::as_select()))
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker not found"))?;

    let sticker_summary = build_sticker_summaries(conn, &state, uid, vec![(sticker, media_row)])?
        .into_iter()
        .next()
        .unwrap();

    let packs: Vec<StickerPack> = sticker_pack_stickers::table
        .inner_join(sticker_packs::table)
        .filter(sticker_pack_stickers::sticker_id.eq(sticker_id))
        .order((
            sticker_pack_stickers::added_at.asc(),
            sticker_packs::id.asc(),
        ))
        .select(StickerPack::as_select())
        .load(conn)
        .map_err(|e| {
            tracing::error!("load sticker packs: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to load sticker packs",
            )
        })?;

    Ok(AxumJson(StickerDetailResponse {
        sticker: sticker_summary,
        packs: build_pack_summaries(conn, &state, uid, packs)?,
    }))
}

async fn put_favorite(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(sticker_id): Path<i64>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let _sticker: Sticker = stickers::table
        .filter(stickers::id.eq(sticker_id))
        .select(Sticker::as_select())
        .first(conn)
        .map_err(|_| (StatusCode::NOT_FOUND, "Sticker not found"))?;

    diesel::insert_into(user_favorite_stickers::table)
        .values(&UserFavoriteSticker {
            uid,
            sticker_id,
            created_at: Utc::now(),
        })
        .on_conflict_do_nothing()
        .execute(conn)
        .map_err(|e| {
            tracing::error!("favorite sticker: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to favorite sticker",
            )
        })?;

    Ok(StatusCode::NO_CONTENT)
}

async fn delete_favorite(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    Path(sticker_id): Path<i64>,
) -> Result<StatusCode, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;

    diesel::delete(
        user_favorite_stickers::table
            .filter(user_favorite_stickers::uid.eq(uid))
            .filter(user_favorite_stickers::sticker_id.eq(sticker_id)),
    )
    .execute(conn)
    .map_err(|e| {
        tracing::error!("unfavorite sticker: {:?}", e);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to unfavorite sticker",
        )
    })?;

    Ok(StatusCode::NO_CONTENT)
}

async fn get_my_favorites(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
) -> Result<AxumJson<FavoriteStickerListResponse>, (StatusCode, &'static str)> {
    let conn = &mut state.db.get().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Database connection failed",
        )
    })?;
    let rows: Vec<(Sticker, Media)> = user_favorite_stickers::table
        .inner_join(stickers::table.inner_join(media::table))
        .filter(user_favorite_stickers::uid.eq(uid))
        .order(user_favorite_stickers::created_at.desc())
        .select((Sticker::as_select(), Media::as_select()))
        .load(conn)
        .map_err(|e| {
            tracing::error!("load favorite stickers: {:?}", e);
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Failed to load favorite stickers",
            )
        })?;

    Ok(AxumJson(FavoriteStickerListResponse {
        stickers: build_sticker_summaries(conn, &state, uid, rows)?,
    }))
}

pub fn router() -> Router<crate::AppState> {
    Router::new()
        .route("/packs", post(post_pack))
        .route("/packs/mine/subscribed", get(get_my_subscribed_packs))
        .route("/packs/mine/owned", get(get_my_owned_packs))
        .route("/mine/favorites", get(get_my_favorites))
        .route("/packs/{pack_id}", get(get_pack).patch(patch_pack))
        .route(
            "/packs/{pack_id}/subscription",
            put(put_subscription).delete(delete_subscription),
        )
        .route("/packs/{pack_id}/stickers", post(post_pack_sticker))
        .route(
            "/packs/{pack_id}/stickers/{sticker_id}",
            put(put_pack_sticker).delete(delete_pack_sticker),
        )
        .route("/{sticker_id}", get(get_sticker))
        .route(
            "/{sticker_id}/favorite",
            put(put_favorite).delete(delete_favorite),
        )
}
