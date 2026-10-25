use chrono::NaiveDateTime;
use diesel::prelude::*;

use crate::schema::tickets;

#[derive(Debug, Clone, Queryable, Selectable)]
#[diesel(table_name = tickets)]
#[diesel(check_for_backend(diesel::sqlite::Sqlite))]
pub struct Ticket {
    pub id: i32,
    pub title: String,
    pub description: String,
    pub sector: String,
    pub status: String,
    pub finished_at: Option<NaiveDateTime>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

#[derive(Debug, Insertable)]
#[diesel(table_name = tickets)]
pub struct NewTicket<'a> {
    pub title: &'a str,
    pub description: &'a str,
    pub sector: &'a str,
    pub status: &'a str,
    pub finished_at: Option<NaiveDateTime>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}
