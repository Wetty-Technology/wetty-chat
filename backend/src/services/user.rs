use crate::{AppState, AuthMethod};
use diesel::prelude::*;
use std::collections::HashMap;

/// Look up usernames for a list of target UIDs depending on the authentication method.
pub async fn lookup_users(state: &AppState, uids: &[i32]) -> HashMap<i32, Option<String>> {
    let mut names = HashMap::with_capacity(uids.len());

    if uids.is_empty() {
        return names;
    }

    match state.auth_method {
        AuthMethod::Discuz => {
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
