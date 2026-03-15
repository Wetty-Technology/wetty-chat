use crate::{AppState, AuthMethod};
use diesel::prelude::*;
use std::collections::HashMap;
use std::time::Instant;
use std::time::UNIX_EPOCH;

pub fn lookup_user_avatars(state: &AppState, uids: &[i32]) -> HashMap<i32, Option<String>> {
    let (public_url, avatar_path) = match (
        &state.auth_method,
        &state.discuz_avatar_public_url,
        &state.discuz_avatar_path,
    ) {
        (AuthMethod::Discuz, Some(url), Some(path)) => (url, path),
        _ => return HashMap::new(),
    };

    let start = Instant::now();
    let mut fs_duration_seconds = 0.0;
    let mut map = HashMap::with_capacity(uids.len());
    for &uid in uids {
        let uid1 = format!("{:0>9}", uid);
        let dir1 = &uid1[0..3];
        let dir2 = &uid1[3..5];
        let dir3 = &uid1[5..7];
        let stem = &uid1[7..9];
        let rel = format!("{}/{}/{}/{}_avatar_middle.jpg", dir1, dir2, dir3, stem);
        let full_path = format!("{}/{}", avatar_path, rel);
        let fs_start = Instant::now();
        let entry = std::fs::metadata(&full_path)
            .ok()
            .and_then(|m| m.modified().ok())
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| format!("{}/{}?ts={}", public_url, rel, d.as_secs()))
            .unwrap_or_else(|| format!("{}/noavatar.svg", public_url));
        fs_duration_seconds += fs_start.elapsed().as_secs_f64();
        map.insert(uid, Some(entry));
    }
    state.metrics.record_discuz_avatar_lookup(
        uids.len(),
        start.elapsed().as_secs_f64(),
        fs_duration_seconds,
    );
    map
}

/// Look up usernames for a list of target UIDs depending on the authentication method.
pub async fn lookup_users(state: &AppState, uids: &[i32]) -> HashMap<i32, Option<String>> {
    let mut names = HashMap::with_capacity(uids.len());

    if uids.is_empty() {
        return names;
    }

    match state.auth_method {
        AuthMethod::Discuz => {
            let start = Instant::now();
            if let Some(ref pool) = state.discuz_db {
                if let Ok(mut conn) = pool.get() {
                    use crate::services::discuz::schema::common_member::dsl::*;
                    let uids_u32: Vec<u32> = uids.iter().map(|&id| id as u32).collect();

                    let records = common_member
                        .filter(uid.eq_any(&uids_u32))
                        .select((uid, username))
                        .load::<(u32, String)>(&mut conn);

                    if let Ok(results) = records {
                        for (found_uid, name) in results {
                            names.insert(found_uid as i32, Some(name));
                        }
                    }
                }
            }
            state
                .metrics
                .record_discuz_username_lookup(uids.len(), start.elapsed().as_secs_f64());
        }
        AuthMethod::UIDHeader => {
            if let Ok(mut conn) = state.db.get() {
                use crate::schema::users::dsl::*;
                let records = users
                    .filter(uid.eq_any(uids))
                    .select((uid, username))
                    .load::<(i32, String)>(&mut conn);

                if let Ok(results) = records {
                    for (found_uid, name) in results {
                        names.insert(found_uid, Some(name));
                    }
                }
            }
        }
    }

    // Fill in missing with None
    for &id in uids {
        names.entry(id).or_insert(None);
    }

    names
}
