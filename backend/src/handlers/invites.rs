use axum::{
    extract::{Json, Path, Query, State},
    http::StatusCode,
};
use chrono::{DateTime, Utc};
use diesel::prelude::*;
use serde::{Deserialize, Serialize};
use serde_json::json;
use uuid::Uuid;

use diesel::PgConnection;

use crate::errors::AppError;
use crate::extractors::DbConn;
use crate::handlers::chats::{send_prepared_message, MessageResponse, PreparedMessageSend};
use crate::handlers::groups::{load_group_info, GroupInfoResponse};
use crate::handlers::members::{check_membership, require_admin_role};
use crate::models::{
    GroupJoinReason, GroupRole, Invite, InviteType, MessageType, NewGroupMembership, NewInvite,
};
use crate::schema::{group_membership, invites};
use crate::utils::auth::CurrentUid;
use crate::utils::ids;
use crate::AppState;

const DEFAULT_INVITES_LIMIT: i64 = 100;
const MAX_INVITES_LIMIT: i64 = 100;
const INVITE_CODE_LEN: usize = 10;
const INVITE_CODE_ALPHABET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
const INVALID_INVITE_CODE_MESSAGE: &str = "Invalid invite code";
const INVALID_INVITE_MESSAGE: &str = "Invalid invite";

#[derive(Deserialize)]
struct InviteIdPath {
    invite_id: i64,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct CreateInviteBody {
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    chat_id: i64,
    invite_type: InviteType,
    target_uid: Option<i32>,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    required_chat_id: Option<i64>,
    expires_at: Option<DateTime<Utc>>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct ListInvitesQuery {
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    group_id: Option<i64>,
    limit: Option<i64>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct GetInviteByCodeQuery {
    invite_code: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct PatchInviteBody {
    #[serde(default, deserialize_with = "double_opt_datetime::deserialize")]
    expires_at: Option<Option<DateTime<Utc>>>,
}

#[derive(Deserialize)]
struct RedeemInviteBody {
    code: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SendInviteMessageBody {
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    source_chat_id: i64,
    #[serde(deserialize_with = "crate::serde_i64_string::deserialize")]
    destination_chat_id: i64,
    #[serde(
        default,
        deserialize_with = "crate::serde_i64_string::opt::deserialize"
    )]
    invite_id: Option<i64>,
    expires_at: Option<DateTime<Utc>>,
    client_generated_id: String,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct InviteResponse {
    #[serde(with = "crate::serde_i64_string")]
    id: i64,
    code: String,
    #[serde(with = "crate::serde_i64_string")]
    chat_id: i64,
    invite_type: InviteType,
    creator_uid: Option<i32>,
    target_uid: Option<i32>,
    #[serde(with = "crate::serde_i64_string::opt")]
    required_chat_id: Option<i64>,
    created_at: DateTime<Utc>,
    expires_at: Option<DateTime<Utc>>,
    revoked_at: Option<DateTime<Utc>>,
    used_at: Option<DateTime<Utc>>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct ListInvitesResponse {
    invites: Vec<InviteResponse>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct InvitePreviewResponse {
    invite: InviteResponse,
    chat: GroupInfoResponse,
    already_member: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct RedeemInviteResponse {
    chat: GroupInfoResponse,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct SendInviteMessageResponse {
    invite: InviteResponse,
    message: MessageResponse,
}

enum RedeemInviteError {
    InvalidCode,
    Db(diesel::result::Error),
}

enum PreviewInviteError {
    InvalidCode,
    Forbidden,
    Db(diesel::result::Error),
}

enum PreviewEligibility {
    Eligible,
    AlreadyMember,
}

enum RedeemInviteOutcome {
    Joined(i64),
    AlreadyMember,
}

impl From<diesel::result::Error> for RedeemInviteError {
    fn from(error: diesel::result::Error) -> Self {
        Self::Db(error)
    }
}

impl From<diesel::result::Error> for PreviewInviteError {
    fn from(error: diesel::result::Error) -> Self {
        Self::Db(error)
    }
}

mod double_opt_datetime {
    use chrono::{DateTime, Utc};
    use serde::{Deserialize, Deserializer};

    pub fn deserialize<'de, D>(deserializer: D) -> Result<Option<Option<DateTime<Utc>>>, D::Error>
    where
        D: Deserializer<'de>,
    {
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum DateTimeOrNull {
            DateTime(DateTime<Utc>),
            Null,
        }

        let v = Option::<DateTimeOrNull>::deserialize(deserializer)?;
        match v {
            None => Ok(None),
            Some(DateTimeOrNull::Null) => Ok(Some(None)),
            Some(DateTimeOrNull::DateTime(value)) => Ok(Some(Some(value))),
        }
    }
}

fn invite_to_response(invite: Invite) -> InviteResponse {
    InviteResponse {
        id: invite.id,
        code: invite.code,
        chat_id: invite.chat_id,
        invite_type: invite.invite_type,
        creator_uid: invite.creator_uid,
        target_uid: invite.target_uid,
        required_chat_id: invite.required_chat_id,
        created_at: invite.created_at,
        expires_at: invite.expires_at,
        revoked_at: invite.revoked_at,
        used_at: invite.used_at,
    }
}

fn invite_limit(limit: Option<i64>) -> i64 {
    limit
        .unwrap_or(DEFAULT_INVITES_LIMIT)
        .clamp(1, MAX_INVITES_LIMIT)
}

fn generate_invite_code() -> String {
    let mut code = String::with_capacity(INVITE_CODE_LEN);

    while code.len() < INVITE_CODE_LEN {
        for byte in Uuid::new_v4().into_bytes() {
            let idx = (byte as usize) % INVITE_CODE_ALPHABET.len();
            code.push(INVITE_CODE_ALPHABET[idx] as char);
            if code.len() == INVITE_CODE_LEN {
                break;
            }
        }
    }

    code
}

fn validate_create_body(body: &CreateInviteBody) -> Result<(), AppError> {
    match body.invite_type {
        InviteType::Generic => {
            if body.target_uid.is_some() || body.required_chat_id.is_some() {
                return Err(AppError::BadRequest(
                    "Generic invites cannot have target_uid or required_chat_id",
                ));
            }
        }
        InviteType::Targeted => {
            if body.target_uid.is_none() || body.required_chat_id.is_some() {
                return Err(AppError::BadRequest(
                    "Targeted invites require target_uid and cannot have required_chat_id",
                ));
            }
        }
        InviteType::Membership => {
            if body.target_uid.is_some() || body.required_chat_id.is_none() {
                return Err(AppError::BadRequest(
                    "Membership invites require required_chat_id and cannot have target_uid",
                ));
            }
        }
    }

    Ok(())
}

fn is_unique_violation(error: &diesel::result::Error) -> bool {
    matches!(
        error,
        diesel::result::Error::DatabaseError(diesel::result::DatabaseErrorKind::UniqueViolation, _)
    )
}

fn load_invite_by_id(conn: &mut PgConnection, invite_id: i64) -> Result<Invite, AppError> {
    invites::table
        .filter(invites::id.eq(invite_id))
        .select(Invite::as_select())
        .first::<Invite>(conn)
        .optional()?
        .ok_or(AppError::BadRequest(INVALID_INVITE_MESSAGE))
}

fn validate_invite_is_active(invite: &Invite, now: DateTime<Utc>) -> bool {
    invite.revoked_at.is_none() && invite.expires_at.is_none_or(|expires_at| expires_at > now)
}

async fn create_generic_invite(
    conn: &mut PgConnection,
    state: &AppState,
    chat_id: i64,
    uid: i32,
    expires_at: Option<DateTime<Utc>>,
) -> Result<Invite, AppError> {
    let id = ids::next_id(state.id_gen.as_ref()).await.map_err(|e| {
        tracing::error!("next_id for invite: {:?}", e);
        AppError::Internal("ID generation failed")
    })?;

    let now = Utc::now();
    let mut inserted = None;

    for _ in 0..8 {
        let new_invite = NewInvite {
            id,
            code: generate_invite_code(),
            chat_id,
            invite_type: InviteType::Generic,
            creator_uid: Some(uid),
            target_uid: None,
            required_chat_id: None,
            created_at: now,
            expires_at,
            revoked_at: None,
            used_at: None,
        };

        match diesel::insert_into(invites::table)
            .values(&new_invite)
            .returning(Invite::as_returning())
            .get_result::<Invite>(conn)
        {
            Ok(invite) => {
                inserted = Some(invite);
                break;
            }
            Err(error) if is_unique_violation(&error) => continue,
            Err(error) => {
                tracing::error!("insert invite: {:?}", error);
                return Err(AppError::Internal("Failed to create invite"));
            }
        }
    }

    inserted.ok_or_else(|| {
        tracing::error!("failed to generate unique invite code after retries");
        AppError::Internal("Failed to create invite")
    })
}

async fn create_invite_from_body(
    conn: &mut PgConnection,
    state: &AppState,
    uid: i32,
    body: &CreateInviteBody,
) -> Result<Invite, AppError> {
    let id = ids::next_id(state.id_gen.as_ref()).await.map_err(|e| {
        tracing::error!("next_id for invite: {:?}", e);
        AppError::Internal("ID generation failed")
    })?;

    let now = Utc::now();
    let mut inserted = None;

    for _ in 0..8 {
        let new_invite = NewInvite {
            id,
            code: generate_invite_code(),
            chat_id: body.chat_id,
            invite_type: body.invite_type.clone(),
            creator_uid: Some(uid),
            target_uid: body.target_uid,
            required_chat_id: body.required_chat_id,
            created_at: now,
            expires_at: body.expires_at,
            revoked_at: None,
            used_at: None,
        };

        match diesel::insert_into(invites::table)
            .values(&new_invite)
            .returning(Invite::as_returning())
            .get_result::<Invite>(conn)
        {
            Ok(invite) => {
                inserted = Some(invite);
                break;
            }
            Err(error) if is_unique_violation(&error) => continue,
            Err(error) => {
                tracing::error!("insert invite: {:?}", error);
                return Err(AppError::Internal("Failed to create invite"));
            }
        }
    }

    inserted.ok_or_else(|| {
        tracing::error!("failed to generate unique invite code after retries");
        AppError::Internal("Failed to create invite")
    })
}

fn preview_eligibility(
    conn: &mut PgConnection,
    invite: &Invite,
    uid: i32,
) -> Result<PreviewEligibility, PreviewInviteError> {
    let already_member = group_membership::table
        .filter(
            group_membership::chat_id
                .eq(invite.chat_id)
                .and(group_membership::uid.eq(uid)),
        )
        .count()
        .get_result::<i64>(conn)?;

    if already_member > 0 {
        return Ok(PreviewEligibility::AlreadyMember);
    }

    match invite.invite_type {
        InviteType::Generic => Ok(PreviewEligibility::Eligible),
        InviteType::Targeted => {
            if invite.target_uid == Some(uid) && invite.used_at.is_none() {
                Ok(PreviewEligibility::Eligible)
            } else {
                Err(PreviewInviteError::Forbidden)
            }
        }
        InviteType::Membership => {
            let required_chat_id = invite
                .required_chat_id
                .ok_or(PreviewInviteError::InvalidCode)?;
            let has_required_membership = group_membership::table
                .filter(
                    group_membership::chat_id
                        .eq(required_chat_id)
                        .and(group_membership::uid.eq(uid)),
                )
                .count()
                .get_result::<i64>(conn)?;

            if has_required_membership > 0 {
                Ok(PreviewEligibility::Eligible)
            } else {
                Err(PreviewInviteError::Forbidden)
            }
        }
    }
}

async fn post_invite(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(body): Json<CreateInviteBody>,
) -> Result<(StatusCode, Json<InviteResponse>), AppError> {
    let conn = &mut *conn;

    validate_create_body(&body)?;

    require_admin_role(conn, body.chat_id, uid)?;
    let invite = create_invite_from_body(conn, &state, uid, &body).await?;

    Ok((StatusCode::CREATED, Json(invite_to_response(invite))))
}

async fn post_send_invite_message(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(body): Json<SendInviteMessageBody>,
) -> Result<(StatusCode, Json<SendInviteMessageResponse>), AppError> {
    let conn = &mut *conn;

    require_admin_role(conn, body.source_chat_id, uid)?;
    check_membership(conn, body.destination_chat_id, uid)?;

    let now = Utc::now();
    let invite = if let Some(invite_id) = body.invite_id {
        let invite = load_invite_by_id(conn, invite_id)?;
        require_admin_role(conn, invite.chat_id, uid)?;
        if invite.chat_id != body.source_chat_id {
            return Err(AppError::BadRequest(
                "Invite does not belong to source chat",
            ));
        }
        if !validate_invite_is_active(&invite, now) {
            return Err(AppError::BadRequest("Invite is no longer active"));
        }
        invite
    } else {
        create_generic_invite(conn, &state, body.source_chat_id, uid, body.expires_at).await?
    };

    let send_result = send_prepared_message(
        conn,
        &state,
        PreparedMessageSend {
            chat_id: body.destination_chat_id,
            sender_uid: uid,
            message: Some(invite.code.clone()),
            message_type: MessageType::Invite,
            sticker_id: None,
            reply_to_id: None,
            reply_root_id: None,
            client_generated_id: body.client_generated_id,
            attachment_ids: vec![],
            update_group_last_message: true,
            push_preview_override: Some("sent an invite".to_string()),
        },
    )
    .await?;

    Ok((
        StatusCode::CREATED,
        Json(SendInviteMessageResponse {
            invite: invite_to_response(invite),
            message: send_result.response,
        }),
    ))
}

async fn get_invites(
    CurrentUid(uid): CurrentUid,
    mut conn: DbConn,
    Query(query): Query<ListInvitesQuery>,
) -> Result<Json<ListInvitesResponse>, AppError> {
    let conn = &mut *conn;

    let mut base_query = invites::table
        .into_boxed()
        .order((invites::created_at.desc(), invites::id.desc()))
        .limit(invite_limit(query.limit));

    if let Some(group_id) = query.group_id {
        require_admin_role(conn, group_id, uid)?;
        base_query = base_query.filter(invites::chat_id.eq(group_id));
    } else {
        base_query = base_query.filter(invites::creator_uid.eq(Some(uid)));
    }

    let rows = base_query
        .select(Invite::as_select())
        .load::<Invite>(conn)?;

    Ok(Json(ListInvitesResponse {
        invites: rows.into_iter().map(invite_to_response).collect(),
    }))
}

async fn get_invite(
    CurrentUid(uid): CurrentUid,
    Path(InviteIdPath { invite_id }): Path<InviteIdPath>,
    mut conn: DbConn,
) -> Result<Json<InviteResponse>, AppError> {
    let conn = &mut *conn;

    let invite = load_invite_by_id(conn, invite_id)?;
    require_admin_role(conn, invite.chat_id, uid)?;

    Ok(Json(invite_to_response(invite)))
}

async fn get_invite_by_code(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Query(query): Query<GetInviteByCodeQuery>,
) -> Result<Json<InvitePreviewResponse>, AppError> {
    let conn = &mut *conn;

    let invite_code = query.invite_code.trim();
    if invite_code.is_empty() {
        return Err(AppError::BadRequest(INVALID_INVITE_CODE_MESSAGE));
    }

    let invite = invites::table
        .filter(invites::code.eq(invite_code))
        .select(Invite::as_select())
        .first::<Invite>(conn)
        .optional()?
        .ok_or(AppError::BadRequest(INVALID_INVITE_CODE_MESSAGE))?;

    if !validate_invite_is_active(&invite, Utc::now()) {
        return Err(AppError::BadRequest(INVALID_INVITE_CODE_MESSAGE));
    }

    let eligibility = preview_eligibility(conn, &invite, uid).map_err(|error| match error {
        PreviewInviteError::InvalidCode => AppError::BadRequest(INVALID_INVITE_CODE_MESSAGE),
        PreviewInviteError::Forbidden => AppError::Forbidden("Not eligible for this invite"),
        PreviewInviteError::Db(other) => {
            tracing::error!("preview invite eligibility: {:?}", other);
            AppError::Internal("Failed to load invite")
        }
    })?;

    let chat = load_group_info(conn, &state, invite.chat_id, uid)?;

    Ok(Json(InvitePreviewResponse {
        invite: invite_to_response(invite),
        chat,
        already_member: matches!(eligibility, PreviewEligibility::AlreadyMember),
    }))
}

async fn patch_invite(
    CurrentUid(uid): CurrentUid,
    Path(InviteIdPath { invite_id }): Path<InviteIdPath>,
    mut conn: DbConn,
    Json(body): Json<PatchInviteBody>,
) -> Result<Json<InviteResponse>, AppError> {
    let conn = &mut *conn;

    let invite = load_invite_by_id(conn, invite_id)?;
    require_admin_role(conn, invite.chat_id, uid)?;

    let next_expires_at = body
        .expires_at
        .ok_or(AppError::BadRequest("expires_at is required"))?;

    let updated = diesel::update(invites::table.filter(invites::id.eq(invite_id)))
        .set(invites::expires_at.eq(next_expires_at))
        .returning(Invite::as_returning())
        .get_result::<Invite>(conn)?;

    Ok(Json(invite_to_response(updated)))
}

async fn delete_invite(
    CurrentUid(uid): CurrentUid,
    Path(InviteIdPath { invite_id }): Path<InviteIdPath>,
    mut conn: DbConn,
) -> Result<StatusCode, AppError> {
    let conn = &mut *conn;

    let invite = load_invite_by_id(conn, invite_id)?;
    require_admin_role(conn, invite.chat_id, uid)?;

    diesel::update(invites::table.filter(invites::id.eq(invite_id)))
        .set(invites::revoked_at.eq(Utc::now()))
        .execute(conn)?;

    Ok(StatusCode::NO_CONTENT)
}

async fn post_redeem_invite(
    CurrentUid(uid): CurrentUid,
    State(state): State<AppState>,
    mut conn: DbConn,
    Json(body): Json<RedeemInviteBody>,
) -> Result<Json<RedeemInviteResponse>, AppError> {
    let conn = &mut *conn;

    let code = body.code.trim();
    if code.is_empty() {
        return Err(AppError::BadRequest(INVALID_INVITE_CODE_MESSAGE));
    }

    let outcome = conn
        .transaction::<RedeemInviteOutcome, RedeemInviteError, _>(|conn| {
            let invite = invites::table
                .filter(invites::code.eq(code))
                .select(Invite::as_select())
                .first::<Invite>(conn)
                .optional()?
                .ok_or(RedeemInviteError::InvalidCode)?;

            let now = Utc::now();
            if !validate_invite_is_active(&invite, now) {
                return Err(RedeemInviteError::InvalidCode);
            }

            let already_member = group_membership::table
                .filter(
                    group_membership::chat_id
                        .eq(invite.chat_id)
                        .and(group_membership::uid.eq(uid)),
                )
                .count()
                .get_result::<i64>(conn)?;

            if already_member > 0 {
                return Ok(RedeemInviteOutcome::AlreadyMember);
            }

            match invite.invite_type {
                InviteType::Generic => {}
                InviteType::Targeted => {
                    if invite.target_uid != Some(uid) || invite.used_at.is_some() {
                        return Err(RedeemInviteError::InvalidCode);
                    }
                }
                InviteType::Membership => {
                    let required_chat_id = invite
                        .required_chat_id
                        .ok_or(RedeemInviteError::InvalidCode)?;
                    let has_required_membership = group_membership::table
                        .filter(
                            group_membership::chat_id
                                .eq(required_chat_id)
                                .and(group_membership::uid.eq(uid)),
                        )
                        .count()
                        .get_result::<i64>(conn)?;

                    if has_required_membership == 0 {
                        return Err(RedeemInviteError::InvalidCode);
                    }
                }
            }

            match diesel::insert_into(group_membership::table)
                .values(&NewGroupMembership {
                    chat_id: invite.chat_id,
                    uid,
                    role: GroupRole::Member,
                    joined_at: now,
                    join_reason: GroupJoinReason::InviteCode,
                    join_reason_extra: Some(json!({
                        "invite_id": invite.id.to_string(),
                        "code": invite.code,
                        "creator_uid": invite.creator_uid,
                    })),
                })
                .execute(conn)
            {
                Ok(_) => {}
                Err(diesel::result::Error::DatabaseError(
                    diesel::result::DatabaseErrorKind::UniqueViolation,
                    _,
                )) => {
                    return Ok(RedeemInviteOutcome::AlreadyMember);
                }
                Err(other) => return Err(RedeemInviteError::Db(other)),
            }

            if invite.invite_type == InviteType::Targeted {
                let updated = diesel::update(
                    invites::table
                        .filter(invites::id.eq(invite.id).and(invites::used_at.is_null())),
                )
                .set(invites::used_at.eq(now))
                .execute(conn)?;

                if updated != 1 {
                    return Err(RedeemInviteError::InvalidCode);
                }
            }

            Ok(RedeemInviteOutcome::Joined(invite.chat_id))
        })
        .map_err(|error| match error {
            RedeemInviteError::InvalidCode => AppError::BadRequest(INVALID_INVITE_CODE_MESSAGE),
            RedeemInviteError::Db(other) => {
                tracing::error!("redeem invite: {:?}", other);
                AppError::Internal("Failed to redeem invite")
            }
        })?;

    let chat_id = match outcome {
        RedeemInviteOutcome::Joined(chat_id) => chat_id,
        RedeemInviteOutcome::AlreadyMember => {
            return Err(AppError::Conflict("Already a member of this chat"));
        }
    };

    let chat = load_group_info(conn, &state, chat_id, uid)?;
    Ok(Json(RedeemInviteResponse { chat }))
}

pub fn router() -> axum::Router<crate::AppState> {
    axum::Router::new()
        .route("/", axum::routing::post(post_invite).get(get_invites))
        .route("/send", axum::routing::post(post_send_invite_message))
        .route("/redeem", axum::routing::post(post_redeem_invite))
        .route("/invite", axum::routing::get(get_invite_by_code))
        .route(
            "/invite/{invite_id}",
            axum::routing::get(get_invite)
                .patch(patch_invite)
                .delete(delete_invite),
        )
}
