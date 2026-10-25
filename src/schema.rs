diesel::table! {
    tickets (id) {
        id -> Integer,
        title -> Text,
        description -> Text,
        sector -> Text,
        status -> Text,
        finished_at -> Nullable<Timestamp>,
        created_at -> Timestamp,
        updated_at -> Timestamp,
    }
}
