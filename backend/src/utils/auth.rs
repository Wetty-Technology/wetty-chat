use axum::{
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
};
use base64::{
    engine::{DecodePaddingMode, GeneralPurposeConfig},
    Engine,
};
use rc4::{consts::U64, Key, KeyInit, Rc4, StreamCipher};
use std::fmt;

const X_USER_ID: &str = "x-user-id";

#[derive(Clone, Copy, Debug)]
pub struct CurrentUid(pub i32);

impl fmt::Display for CurrentUid {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        self.0.fmt(f)
    }
}

const BASE64_ENGINE: base64::engine::GeneralPurpose = base64::engine::GeneralPurpose::new(
    &base64::alphabet::STANDARD,
    GeneralPurposeConfig::new().with_decode_padding_mode(DecodePaddingMode::Indifferent),
);

#[derive(Debug, Clone, Copy)]
enum DiscuzCipherError {
    InvalidAuthFormat,
    AuthDecodeError,
    DecryptionError,
    InvalidAuth,
    InvalidUid,
}

/// Implements the Discuz Cookie Decoding.
/// TODO the first part of the key is not yet verified.
/// Note: it is not constant time.
fn decode(auth: &str, salt_key: &str, config_authkey: &str) -> Result<i32, DiscuzCipherError> {
    let auth_key = format!(
        "{:x}",
        md5::compute(format!("{}{}", config_authkey, salt_key))
    );
    let md5_authkey = format!("{:x}", md5::compute(&auth_key));
    let keya = format!("{:x}", md5::compute(&md5_authkey[0..16]));

    if auth.len() < 4 {
        return Err(DiscuzCipherError::InvalidAuthFormat);
    }

    let cryptkey = format!(
        "{}{}",
        keya,
        format!("{:x}", md5::compute(format!("{}{}", keya, &auth[0..4])))
    );
    debug_assert_eq!(cryptkey.len(), 64, "Invalid cryptkey len");

    let mut cipher_buffer = BASE64_ENGINE
        .decode(&auth[4..])
        .map_err(|_| DiscuzCipherError::AuthDecodeError)?;
    let key = Key::<U64>::from_slice(cryptkey.as_bytes());
    let mut rc4 = Rc4::new(key);
    rc4.apply_keystream(&mut cipher_buffer);

    let result_str =
        String::from_utf8(cipher_buffer).map_err(|_| DiscuzCipherError::DecryptionError)?;

    let parts: Vec<&str> = result_str.split('\t').collect();
    if parts.len() != 2 {
        return Err(DiscuzCipherError::InvalidAuth);
    }

    let uid = parts[1]
        .parse::<i32>()
        .map_err(|_| DiscuzCipherError::InvalidUid)?;

    Ok(uid)
}

impl FromRequestParts<crate::AppState> for CurrentUid {
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(
        parts: &mut Parts,
        state: &crate::AppState,
    ) -> Result<Self, Self::Rejection> {
        match state.auth_method {
            crate::AuthMethod::UIDHeader => {
                let value = parts
                    .headers
                    .get(X_USER_ID)
                    .and_then(|v| v.to_str().ok())
                    .ok_or((
                        StatusCode::UNAUTHORIZED,
                        "Missing or invalid X-User-Id header",
                    ))?;
                let uid = value
                    .trim()
                    .parse::<i32>()
                    .map_err(|_| (StatusCode::UNAUTHORIZED, "X-User-Id must be a valid i32"))?;
                Ok(CurrentUid(uid))
            }
            crate::AuthMethod::Discuz => {
                let cookies_str = parts
                    .headers
                    .get("cookie")
                    .and_then(|v| v.to_str().ok())
                    .unwrap_or("");

                let mut auth_cookie = None;
                let mut saltkey_cookie = None;
                let auth_cookie_name = format!("{}_auth=", state.discuz_cookie_prefix);
                let saltkey_cookie_name = format!("{}_saltkey=", state.discuz_cookie_prefix);

                for cookie in cookies_str.split(';') {
                    let cookie = cookie.trim();
                    if let Some(stripped) = cookie.strip_prefix(&auth_cookie_name) {
                        let decoded = urlencoding::decode(stripped)
                            .map_err(|_| (StatusCode::UNAUTHORIZED, "InvalidDiscuz auth cookie"))?
                            .to_string();
                        auth_cookie = Some(decoded);
                    } else if let Some(stripped) = cookie.strip_prefix(&saltkey_cookie_name) {
                        saltkey_cookie = Some(stripped);
                    }
                }

                let auth = auth_cookie.ok_or((StatusCode::UNAUTHORIZED, "Missing auth cookie"))?;
                let saltkey =
                    saltkey_cookie.ok_or((StatusCode::UNAUTHORIZED, "Missing saltkey cookie"))?;

                let uid = decode(&auth, saltkey, &state.discuz_authkey).map_err(|err| {
                    tracing::warn!("Discuz decode error: {:?}", err);
                    (StatusCode::UNAUTHORIZED, "Invalid Discuz auth cookie")
                })?;

                // At this step, we could optionally cross-check with state.discuz_db
                // to make sure the user is still valid, but the plan focused on decode.
                // For now we accept the decoded UID.

                Ok(CurrentUid(uid))
            }
        }
    }
}
