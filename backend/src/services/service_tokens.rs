use chrono::{Duration, Utc};
use constant_time_eq::constant_time_eq;
use diesel::prelude::*;
use diesel::PgConnection;
use hmac::{Hmac, Mac};
use rand::{rngs::OsRng, RngCore};
use sha2::Sha256;

use crate::errors::AppError;
use crate::models::ServiceToken;
use crate::schema::service_tokens;

type HmacSha256 = Hmac<Sha256>;

pub const TOKEN_PREFIX: &str = "svc_";
const TOKEN_BYTES: usize = 16;
const SECRET_BYTES: usize = 32;
#[allow(dead_code)]
const LAST_USED_WRITE_INTERVAL_MINUTES: i64 = 5;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ParsedCredential<'a> {
    pub token: &'a str,
    pub secret: &'a str,
}

#[derive(Debug, Clone)]
pub struct GeneratedCredential {
    pub token: String,
    pub credential: String,
    pub secret_hash: String,
}

#[allow(dead_code)]
#[derive(Debug, Clone)]
pub struct AuthenticatedServiceToken {
    pub id: i64,
}

pub fn generate_credential(hash_key: &[u8]) -> Result<GeneratedCredential, AppError> {
    let token = random_hex(TOKEN_BYTES);
    let secret = generate_secret();
    let credential = format!("{TOKEN_PREFIX}{token}_{secret}");
    let secret_hash = hash_secret(hash_key, &token, &secret)?;

    Ok(GeneratedCredential {
        token,
        credential,
        secret_hash,
    })
}

pub fn generate_secret() -> String {
    random_hex(SECRET_BYTES)
}

pub fn parse_credential(credential: &str) -> Option<ParsedCredential<'_>> {
    let rest = credential.strip_prefix(TOKEN_PREFIX)?;
    let (token, secret) = rest.split_once('_')?;

    if token.len() != TOKEN_BYTES * 2 || secret.len() != SECRET_BYTES * 2 {
        return None;
    }
    if !is_hex(token) || !is_hex(secret) {
        return None;
    }

    Some(ParsedCredential { token, secret })
}

#[allow(dead_code)]
pub fn authenticate(
    conn: &mut PgConnection,
    hash_key: &[u8],
    credential: &str,
) -> Result<AuthenticatedServiceToken, AppError> {
    let parsed =
        parse_credential(credential).ok_or(AppError::Unauthorized("Invalid service token"))?;

    let row = service_tokens::table
        .filter(service_tokens::token.eq(parsed.token))
        .select(ServiceToken::as_select())
        .first::<ServiceToken>(conn)
        .optional()?
        .ok_or(AppError::Unauthorized("Invalid service token"))?;

    if row.revoked_at.is_some() {
        return Err(AppError::Unauthorized("Service token revoked"));
    }

    if !verify_secret_hash(hash_key, parsed.token, parsed.secret, &row.secret_hash)? {
        return Err(AppError::Unauthorized("Invalid service token"));
    }

    maybe_touch_last_used_at(conn, &row)?;

    Ok(AuthenticatedServiceToken { id: row.id })
}

pub fn hash_secret(hash_key: &[u8], token: &str, secret: &str) -> Result<String, AppError> {
    let mut mac = HmacSha256::new_from_slice(hash_key)
        .map_err(|_| AppError::Internal("Failed to hash service token"))?;
    mac.update(b"wetty-chat-service-token:v1:");
    mac.update(token.as_bytes());
    mac.update(b":");
    mac.update(secret.as_bytes());
    Ok(hex::encode(mac.finalize().into_bytes()))
}

fn verify_secret_hash(
    hash_key: &[u8],
    token: &str,
    secret: &str,
    expected_hash: &str,
) -> Result<bool, AppError> {
    let actual_hash = hash_secret(hash_key, token, secret)?;
    Ok(constant_time_eq(
        actual_hash.as_bytes(),
        expected_hash.as_bytes(),
    ))
}

#[allow(dead_code)]
fn maybe_touch_last_used_at(conn: &mut PgConnection, row: &ServiceToken) -> Result<(), AppError> {
    let now = Utc::now();
    let should_touch = row
        .last_used_at
        .map(|last_used_at| {
            now - last_used_at >= Duration::minutes(LAST_USED_WRITE_INTERVAL_MINUTES)
        })
        .unwrap_or(true);

    if should_touch {
        diesel::update(service_tokens::table.filter(service_tokens::id.eq(row.id)))
            .set(service_tokens::last_used_at.eq(now))
            .execute(conn)?;
    }

    Ok(())
}

fn random_hex(byte_len: usize) -> String {
    let mut bytes = vec![0_u8; byte_len];
    OsRng.fill_bytes(&mut bytes);
    hex::encode(bytes)
}

fn is_hex(value: &str) -> bool {
    value.bytes().all(|byte| byte.is_ascii_hexdigit())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_expected_credential_shape() {
        let credential = concat!(
            "svc_",
            "00112233445566778899aabbccddeeff",
            "_",
            "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
        );

        let parsed = parse_credential(credential).unwrap();

        assert_eq!(parsed.token, "00112233445566778899aabbccddeeff");
        assert_eq!(
            parsed.secret,
            "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
        );
    }

    #[test]
    fn rejects_wrong_prefix() {
        assert!(parse_credential("wsvc_token_secret").is_none());
    }

    #[test]
    fn hash_verification_matches_only_original_secret() {
        let token = "00112233445566778899aabbccddeeff";
        let secret = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff";
        let hash = hash_secret(b"test-key", token, secret).unwrap();

        assert!(verify_secret_hash(b"test-key", token, secret, &hash).unwrap());
        assert!(!verify_secret_hash(b"test-key", token, &secret[2..], &hash).unwrap());
    }
}
