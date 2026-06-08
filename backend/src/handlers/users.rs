use axum::{
    extract::{Path, Query, State},
    http::HeaderMap,
    Json,
};
use serde::Deserialize;
use utoipa::ToSchema;
use utoipa_axum::router::OpenApiRouter;
use utoipa_axum::routes;

use crate::dto::users::{
    AuthTokenResponse, DeveloperStatusResponse, MeResponse, MemberSummary, SearchUsersResponse,
    SetDeveloperRequest, StickerPackOrderItem,
};
use crate::dto::ws::{ServerWsMessage, StickerPackOrderUpdatePayload};
use crate::errors::AppError;
use crate::extractors::DbConn;
use crate::models::{NewPolicyAssignment, NewUserExtra, PolicySubjectType, UserExtra};
use crate::schema::discuz::discuz::common_member;
use crate::schema::{
    group_membership, policy_assignments, sticker_packs, user_extra, user_sticker_pack_subscriptions,
};
use crate::services::authz::{Action as AuthzAction, Resource as AuthzResource};
use crate::services::user::{
    lookup_user_avatars, lookup_user_profiles, search_user_uids_by_prefix,
};
use crate::utils::auth::{
    encode_auth_token, extract_auth_context, required_client_id, AuthClaims, AuthSource, CurrentUid,
};
use crate::AppState;
use diesel::prelude::*;
use std::collections::{HashMap, HashSet};
use std::sync::Arc;

const DEFAULT_USER_SEARCH_LIMIT: i64 = 20;
const MAX_USER_SEARCH_LIMIT: i64 = 50;
const DEVELOPER_POLICY_ID: i64 = 2;

#[derive(serde::Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStickerPackOrderItem {
    pub sticker_pack_id: String,
    pub last_used_on: i64,
    pub is_auto_sort: Option<bool>,
}

#[derive(serde::Deserialize, ToSchema)]
#[serde(rename_all = "camelCase")]
pub struct UpdateStickerPackOrderRequest {
    pub order: Vec<UpdateStickerPackOrderItem>,
}

#[utoipa::path(
    put,
    path = "/me/stickerpack-order",
    tag = "users",
    request_body = UpdateStickerPackOrderRequest,
    responses(
        (status = 200, description = "Order updated successfully")
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn put_stickerpack_order(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(req): Json<UpdateStickerPackOrderRequest>,
) -> Result<Json<()>, AppError> {
    let conn = &mut *conn;
    let requested_order = req.order;

    let requested_pack_ids: Vec<i64> = requested_order
        .iter()
        .filter_map(|item| item.sticker_pack_id.parse::<i64>().ok())
        .collect();
    let accessible_pack_ids = load_accessible_sticker_pack_ids(conn, uid, &requested_pack_ids)?;

    let extra = user_extra::table
        .filter(user_extra::uid.eq(uid))
        .first::<UserExtra>(conn)
        .optional()?;

    let mut current_order = extra
        .and_then(|e| {
            serde_json::from_value::<Vec<StickerPackOrderItem>>(e.sticker_pack_order).ok()
        })
        .unwrap_or_default();

    // Sort descending by last_used_on to safely determine position
    let mut sorted_order = current_order.clone();
    sorted_order.sort_by_key(|o| -o.last_used_on);

    use crate::MAX_AUTO_SORT_LIMIT;
    let auto_sort_limit = MAX_AUTO_SORT_LIMIT;

    for inc in requested_order {
        let Ok(pack_id) = inc.sticker_pack_id.parse::<i64>() else {
            continue;
        };

        if !accessible_pack_ids.contains(&pack_id) {
            continue;
        }

        if inc.is_auto_sort.unwrap_or(false) {
            let current_pos = sorted_order
                .iter()
                .position(|o| o.sticker_pack_id == inc.sticker_pack_id);
            let Some(pos) = current_pos else {
                continue;
            };
            if pos >= auto_sort_limit {
                continue;
            }
        }

        if let Some(existing) = current_order
            .iter_mut()
            .find(|o| o.sticker_pack_id == inc.sticker_pack_id)
        {
            existing.last_used_on = inc.last_used_on;
        } else {
            current_order.push(StickerPackOrderItem {
                sticker_pack_id: inc.sticker_pack_id,
                last_used_on: inc.last_used_on,
            });
        }

        sorted_order = current_order.clone();
        sorted_order.sort_by_key(|item| -item.last_used_on);
    }

    let order_json = serde_json::to_value(&current_order).unwrap_or(serde_json::json!([]));

    let affected = diesel::update(user_extra::table.filter(user_extra::uid.eq(uid)))
        .set(user_extra::sticker_pack_order.eq(&order_json))
        .execute(conn)?;

    if affected == 0 {
        let now = chrono::Utc::now().naive_utc();
        diesel::insert_into(user_extra::table)
            .values(NewUserExtra {
                uid,
                first_seen_at: now,
                last_seen_at: now,
                sticker_pack_order: order_json.clone(),
            })
            .execute(conn)?;
    }

    let msg = Arc::new(ServerWsMessage::StickerPackOrderUpdated(
        StickerPackOrderUpdatePayload {
            order: current_order,
        },
    ));
    state.ws_registry.broadcast_to_uids(&[uid], msg);

    Ok(Json(()))
}

#[derive(Debug, Deserialize, ToSchema, utoipa::IntoParams)]
#[serde(rename_all = "camelCase")]
pub struct SearchUsersQuery {
    q: Option<String>,
    limit: Option<i64>,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    #[schema(value_type = Option<String>)]
    exclude_member_of: Option<i64>,
}

fn normalize_user_search_limit(limit: Option<i64>) -> i64 {
    limit
        .unwrap_or(DEFAULT_USER_SEARCH_LIMIT)
        .clamp(1, MAX_USER_SEARCH_LIMIT)
}

fn lookup_member_summary(
    conn: &mut PgConnection,
    state: &AppState,
    uid: i32,
) -> Result<Option<MemberSummary>, AppError> {
    let mut profiles = lookup_user_profiles(conn, &[uid])?;
    let Some(profile) = profiles.remove(&uid) else {
        return Ok(None);
    };

    let mut avatars = lookup_user_avatars(state, &[uid]);
    Ok(Some(MemberSummary {
        uid,
        username: profile.username,
        avatar_url: avatars.remove(&uid).flatten(),
        gender: profile.gender,
        user_group: profile.user_group,
    }))
}

fn build_member_summary_map(
    conn: &mut PgConnection,
    state: &AppState,
    uids: &[i32],
) -> Result<HashMap<i32, MemberSummary>, AppError> {
    let profiles = lookup_user_profiles(conn, uids)?;
    let mut avatars = lookup_user_avatars(state, uids);

    Ok(uids
        .iter()
        .filter_map(|uid| {
            profiles.get(uid).map(|profile| {
                (
                    *uid,
                    MemberSummary {
                        uid: *uid,
                        username: profile.username.clone(),
                        avatar_url: avatars.remove(uid).flatten(),
                        gender: profile.gender,
                        user_group: profile.user_group.clone(),
                    },
                )
            })
        })
        .collect())
}

fn can_exclude_members_of_chat(
    conn: &mut PgConnection,
    requester_uid: i32,
    chat_id: i64,
) -> Result<bool, AppError> {
    use crate::schema::group_membership::dsl as gm_dsl;

    let count = group_membership::table
        .filter(
            gm_dsl::chat_id
                .eq(chat_id)
                .and(gm_dsl::uid.eq(requester_uid)),
        )
        .count()
        .get_result::<i64>(conn)?;

    Ok(count > 0)
}

fn split_excluded_member_summaries(
    summaries: Vec<MemberSummary>,
    member_uid_set: &HashSet<i32>,
) -> (Vec<MemberSummary>, Vec<MemberSummary>) {
    let mut members = Vec::new();
    let mut excluded = Vec::new();
    for summary in summaries {
        if member_uid_set.contains(&summary.uid) {
            excluded.push(summary);
        } else {
            members.push(summary);
        }
    }

    (members, excluded)
}

fn load_excluded_member_uids(
    conn: &mut PgConnection,
    chat_id: i64,
    uids: &[i32],
) -> Result<HashSet<i32>, AppError> {
    if uids.is_empty() {
        return Ok(HashSet::new());
    }

    use crate::schema::group_membership::dsl as gm_dsl;

    Ok(group_membership::table
        .filter(gm_dsl::chat_id.eq(chat_id).and(gm_dsl::uid.eq_any(uids)))
        .select(gm_dsl::uid)
        .load::<i32>(conn)?
        .into_iter()
        .collect())
}

fn ensure_user_exists(conn: &mut PgConnection, uid: i32) -> Result<(), AppError> {
    use crate::schema::discuz::discuz::common_member::dsl as cm_dsl;

    let exists = common_member::table
        .filter(cm_dsl::uid.eq(uid))
        .select(cm_dsl::uid)
        .first::<i32>(conn)
        .optional()?
        .is_some();

    if exists {
        Ok(())
    } else {
        Err(AppError::NotFound("User not found"))
    }
}

fn is_user_developer(conn: &mut PgConnection, uid: i32) -> Result<bool, AppError> {
    use crate::schema::policy_assignments::dsl as pa_dsl;

    let count = policy_assignments::table
        .filter(
            pa_dsl::subject_type
                .eq(PolicySubjectType::User)
                .and(pa_dsl::subject_id.eq(i64::from(uid)))
                .and(pa_dsl::policy_id.eq(DEVELOPER_POLICY_ID)),
        )
        .count()
        .get_result::<i64>(conn)?;
    Ok(count > 0)
}

fn should_update_developer_assignment(currently_developer: bool, requested_developer: bool) -> bool {
    currently_developer != requested_developer
}

/// GET /users/me — Get the current logged in user's information
#[utoipa::path(
    get,
    path = "/me",
    tag = "users",
    responses(
        (status = 200, description = "Current user info", body = MeResponse)
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn get_me(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
) -> Result<Json<MeResponse>, AppError> {
    let conn = &mut *conn;

    let profiles = lookup_user_profiles(conn, &[uid])?;
    let profile = profiles.get(&uid);
    let username = profile
        .and_then(|profile| profile.username.clone())
        .unwrap_or_else(|| "Unknown".to_string());

    let mut avatars = lookup_user_avatars(&state, &[uid]);
    let avatar_url = avatars.remove(&uid).flatten();

    let extra = user_extra::table
        .filter(user_extra::uid.eq(uid))
        .select(UserExtra::as_select())
        .first::<UserExtra>(conn)
        .optional()?;

    let sticker_pack_order = extra
        .and_then(|e| {
            serde_json::from_value::<Vec<StickerPackOrderItem>>(e.sticker_pack_order).ok()
        })
        .unwrap_or_default();
    let permissions = state.authz_service.list_permissions(
        conn,
        uid,
        crate::services::authz::Resource::Global,
    )?;

    Ok(Json(MeResponse {
        uid,
        username,
        avatar_url,
        gender: profile.map(|profile| profile.gender).unwrap_or(0),
        sticker_pack_order,
        permissions,
    }))
}

#[utoipa::path(
    get,
    path = "/{uid}/developer",
    tag = "users",
    params(
        ("uid" = i32, Path, description = "Target user ID")
    ),
    responses(
        (status = 200, description = "Developer status", body = DeveloperStatusResponse)
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn get_user_developer(
    CurrentUid(requester_uid): CurrentUid,
    Path(target_uid): Path<i32>,
    State(state): State<AppState>,
    mut conn: DbConn,
) -> Result<Json<DeveloperStatusResponse>, AppError> {
    let conn = &mut *conn;
    state.authz_service.require_permission(
        conn,
        requester_uid,
        AuthzAction::PermissionAll,
        AuthzResource::Global,
    )?;
    ensure_user_exists(conn, target_uid)?;

    Ok(Json(DeveloperStatusResponse {
        is_developer: is_user_developer(conn, target_uid)?,
    }))
}

#[utoipa::path(
    put,
    path = "/{uid}/developer",
    tag = "users",
    params(
        ("uid" = i32, Path, description = "Target user ID")
    ),
    request_body = SetDeveloperRequest,
    responses(
        (status = 200, description = "Developer status updated", body = DeveloperStatusResponse)
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn put_user_developer(
    CurrentUid(requester_uid): CurrentUid,
    Path(target_uid): Path<i32>,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(req): Json<SetDeveloperRequest>,
) -> Result<Json<DeveloperStatusResponse>, AppError> {
    let conn = &mut *conn;
    state.authz_service.require_permission(
        conn,
        requester_uid,
        AuthzAction::PermissionAll,
        AuthzResource::Global,
    )?;
    ensure_user_exists(conn, target_uid)?;

    let currently_developer = is_user_developer(conn, target_uid)?;
    if req.is_developer && should_update_developer_assignment(currently_developer, req.is_developer) {
        let id = crate::utils::ids::next_id(state.id_gen.as_ref())
            .await
            .map_err(|e| {
                tracing::error!("next_id for developer assignment: {:?}", e);
                AppError::Internal("ID generation failed")
            })?;
        let now = chrono::Utc::now();
        diesel::insert_into(policy_assignments::table)
            .values(NewPolicyAssignment {
                id,
                subject_type: PolicySubjectType::User,
                subject_id: i64::from(target_uid),
                policy_id: DEVELOPER_POLICY_ID,
                created_at: now,
                updated_at: now,
            })
            .execute(conn)?;
        state.authz_service.invalidate_user(target_uid);
    } else if !req.is_developer
        && should_update_developer_assignment(currently_developer, req.is_developer)
    {
        use crate::schema::policy_assignments::dsl as pa_dsl;
        diesel::delete(
            policy_assignments::table.filter(
                pa_dsl::subject_type
                    .eq(PolicySubjectType::User)
                    .and(pa_dsl::subject_id.eq(i64::from(target_uid)))
                    .and(pa_dsl::policy_id.eq(DEVELOPER_POLICY_ID)),
            ),
        )
        .execute(conn)?;
        state.authz_service.invalidate_user(target_uid);
    }

    Ok(Json(DeveloperStatusResponse {
        is_developer: req.is_developer,
    }))
}

/// GET /users/search — Search global users for targeted invites.
#[utoipa::path(
    get,
    path = "/search",
    tag = "users",
    params(SearchUsersQuery),
    responses(
        (status = 200, description = "User search results", body = SearchUsersResponse)
    ),
    security(("uid_header" = []), ("bearer_jwt" = []))
)]
async fn get_user_search(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Query(query): Query<SearchUsersQuery>,
) -> Result<Json<SearchUsersResponse>, AppError> {
    let conn = &mut *conn;
    let q = query.q.as_deref().map(str::trim).unwrap_or("");
    let limit = normalize_user_search_limit(query.limit);

    let mut merged_uids = Vec::new();
    let mut seen_uids = HashSet::new();

    if let Ok(exact_uid) = q.parse::<i32>() {
        if let Some(summary) = lookup_member_summary(conn, &state, exact_uid)? {
            seen_uids.insert(summary.uid);
            merged_uids.push(summary.uid);
        }
    }

    if !q.is_empty()
        && state.authz_service.has_permission(
            conn,
            uid,
            AuthzAction::MemberViewAll,
            AuthzResource::Global,
        )?
    {
        for found_uid in search_user_uids_by_prefix(conn, q, limit)? {
            if seen_uids.insert(found_uid) {
                merged_uids.push(found_uid);
            }
        }
    }

    let summaries_by_uid = build_member_summary_map(conn, &state, &merged_uids)?;
    let summaries: Vec<MemberSummary> = merged_uids
        .into_iter()
        .filter_map(|member_uid| summaries_by_uid.get(&member_uid).cloned())
        .collect();

    let exclude_member_of = match query.exclude_member_of {
        Some(chat_id) if can_exclude_members_of_chat(conn, uid, chat_id)? => Some(chat_id),
        _ => None,
    };
    let excluded_uids = match exclude_member_of {
        Some(chat_id) => {
            let summary_uids: Vec<i32> = summaries.iter().map(|summary| summary.uid).collect();
            load_excluded_member_uids(conn, chat_id, &summary_uids)?
        }
        None => HashSet::new(),
    };
    let (members, excluded) = split_excluded_member_summaries(summaries, &excluded_uids);

    Ok(Json(SearchUsersResponse { members, excluded }))
}

#[utoipa::path(
    get,
    path = "/auth-token",
    tag = "users",
    responses(
        (status = 200, description = "Auth token", body = AuthTokenResponse)
    )
)]
async fn get_auth_token(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<AuthTokenResponse>, AppError> {
    let auth = extract_auth_context(&headers, &state)?;
    let client_id = match auth.client_id {
        Some(client_id) => client_id,
        None if auth.source == AuthSource::Legacy => required_client_id(&headers)?,
        None => return Err(AppError::BadRequest("Missing X-Client-Id header")),
    };

    let token = encode_auth_token(
        &AuthClaims {
            uid: auth.uid,
            cid: client_id,
            gen: 0,
        },
        &state.jwt_signing_key,
    )?;

    Ok(Json(AuthTokenResponse { token }))
}

pub fn router() -> OpenApiRouter<crate::AppState> {
    OpenApiRouter::new()
        .routes(routes!(get_me))
        .routes(routes!(get_user_developer, put_user_developer))
        .routes(routes!(get_user_search))
        .routes(routes!(get_auth_token))
        .routes(routes!(put_stickerpack_order))
}

fn load_accessible_sticker_pack_ids(
    conn: &mut PgConnection,
    uid: i32,
    pack_ids: &[i64],
) -> Result<HashSet<i64>, AppError> {
    if pack_ids.is_empty() {
        return Ok(HashSet::new());
    }

    let owned_pack_ids: Vec<i64> = sticker_packs::table
        .filter(sticker_packs::owner_uid.eq(uid))
        .filter(sticker_packs::id.eq_any(pack_ids))
        .select(sticker_packs::id)
        .load(conn)?;

    let subscribed_pack_ids: Vec<i64> = user_sticker_pack_subscriptions::table
        .filter(user_sticker_pack_subscriptions::uid.eq(uid))
        .filter(user_sticker_pack_subscriptions::pack_id.eq_any(pack_ids))
        .select(user_sticker_pack_subscriptions::pack_id)
        .load(conn)?;

    Ok(owned_pack_ids
        .into_iter()
        .chain(subscribed_pack_ids)
        .collect())
}

#[cfg(test)]
mod tests {
    use super::{
        normalize_user_search_limit, should_update_developer_assignment,
        split_excluded_member_summaries, MemberSummary,
    };
    use std::collections::HashSet;
    use std::path::PathBuf;

    fn make_summary(uid: i32) -> MemberSummary {
        MemberSummary {
            uid,
            username: Some(format!("user{uid}")),
            avatar_url: None,
            gender: 0,
            user_group: None,
        }
    }

    #[test]
    fn normalize_user_search_limit_clamps_to_max() {
        assert_eq!(normalize_user_search_limit(None), 20);
        assert_eq!(normalize_user_search_limit(Some(999)), 50);
        assert_eq!(normalize_user_search_limit(Some(5)), 5);
        assert_eq!(normalize_user_search_limit(Some(0)), 1);
    }

    #[test]
    fn split_excluded_uses_membership_set() {
        let summaries = vec![make_summary(1), make_summary(2), make_summary(3)];
        let excluded_uids = HashSet::from([2, 3]);
        let result = split_excluded_member_summaries(summaries, &excluded_uids);

        assert_eq!(
            result
                .0
                .iter()
                .map(|summary| summary.uid)
                .collect::<Vec<_>>(),
            vec![1]
        );
        assert_eq!(
            result
                .1
                .iter()
                .map(|summary| summary.uid)
                .collect::<Vec<_>>(),
            vec![2, 3]
        );
    }

    #[test]
    fn developer_assignment_update_is_idempotent() {
        assert!(!should_update_developer_assignment(false, false));
        assert!(!should_update_developer_assignment(true, true));
        assert!(should_update_developer_assignment(false, true));
        assert!(should_update_developer_assignment(true, false));
    }

    #[test]
    fn migration_seeds_developer_access_policy() {
        let migration_up = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("migrations")
            .join("2026-06-08-043855-0000_add_developer_policy")
            .join("up.sql");
        let sql = std::fs::read_to_string(migration_up).expect("must read developer migration up.sql");

        assert!(sql.contains("'developer.access'"));
        assert!(sql.contains("INSERT INTO policies"));
    }
}
