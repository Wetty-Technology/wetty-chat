// @generated automatically by Diesel CLI.

pub mod discuz {
    diesel::table! {
        discuz.common_member (uid) {
            uid -> Int4,
            #[max_length = 255]
            email -> Varchar,
            #[max_length = 15]
            username -> Bpchar,
            #[max_length = 32]
            password -> Bpchar,
            #[max_length = 3]
            secmobicc -> Varchar,
            #[max_length = 12]
            secmobile -> Varchar,
            status -> Int2,
            emailstatus -> Int2,
            avatarstatus -> Int2,
            secmobilestatus -> Int2,
            videophotostatus -> Int2,
            adminid -> Int2,
            groupid -> Int4,
            groupexpiry -> Int8,
            #[max_length = 20]
            extgroupids -> Bpchar,
            regdate -> Int8,
            credits -> Int4,
            notifysound -> Int2,
            #[max_length = 4]
            timeoffset -> Bpchar,
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
