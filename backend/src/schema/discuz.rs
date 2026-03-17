// @generated automatically by Diesel CLI.

pub mod discuz {
    diesel::table! {
        discuz.common_member (uid) {
            uid -> Int4,
            email -> Text,
            username -> Text,
            password -> Text,
            secmobicc -> Text,
            secmobile -> Text,
            status -> Int2,
            emailstatus -> Int2,
            avatarstatus -> Int2,
            secmobilestatus -> Int2,
            videophotostatus -> Int2,
            adminid -> Int2,
            groupid -> Int4,
            groupexpiry -> Int8,
            extgroupids -> Text,
            regdate -> Int8,
            credits -> Int4,
            notifysound -> Int2,
            timeoffset -> Text,
            newpm -> Int4,
            newprompt -> Int4,
            accessmasks -> Int2,
            allowadmincp -> Int2,
            onlyacceptfriendpm -> Int2,
            conisbind -> Int2,
            freeze -> Int2,
        }
    }
}
