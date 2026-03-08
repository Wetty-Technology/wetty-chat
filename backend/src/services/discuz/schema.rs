// @generated automatically by Diesel CLI.

diesel::table! {
    use diesel::sql_types::*;

    common_member (uid) {
        uid -> Unsigned<Integer>,
        #[max_length = 255]
        email -> Varchar,
        #[max_length = 15]
        username -> Char,
        #[max_length = 32]
        password -> Char,
        #[max_length = 3]
        secmobicc -> Varchar,
        #[max_length = 12]
        secmobile -> Varchar,
        status -> Bool,
        emailstatus -> Bool,
        avatarstatus -> Bool,
        secmobilestatus -> Bool,
        videophotostatus -> Bool,
        adminid -> Bool,
        groupid -> Unsigned<Smallint>,
        groupexpiry -> Unsigned<Integer>,
        #[max_length = 20]
        extgroupids -> Char,
        regdate -> Unsigned<Integer>,
        credits -> Integer,
        notifysound -> Bool,
        #[max_length = 4]
        timeoffset -> Char,
        newpm -> Unsigned<Smallint>,
        newprompt -> Unsigned<Smallint>,
        accessmasks -> Bool,
        allowadmincp -> Bool,
        onlyacceptfriendpm -> Bool,
        conisbind -> Bool,
        freeze -> Bool,
    }
}
