use std::collections::BTreeMap;

use chrono::{DateTime, NaiveDateTime, SecondsFormat, Utc};
use serde::{Deserialize, Serialize};

use crate::ticket::errors::AppError;
use crate::ticket::models::Ticket;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum TicketStatus {
    Open,
    InProgress,
    Closed,
}

impl TicketStatus {
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Open => "open",
            Self::InProgress => "in_progress",
            Self::Closed => "closed",
        }
    }

    pub fn parse(value: &str) -> Option<Self> {
        match value.to_ascii_lowercase().as_str() {
            "open" => Some(Self::Open),
            "in_progress" => Some(Self::InProgress),
            "closed" => Some(Self::Closed),
            _ => None,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct TicketRequest {
    #[serde(default)]
    pub title: Option<String>,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub sector: Option<String>,
    #[serde(default)]
    pub status: Option<String>,
}

#[derive(Debug)]
pub struct TicketData {
    pub title: String,
    pub description: String,
    pub sector: String,
    pub status: TicketStatus,
}

impl TryFrom<TicketRequest> for TicketData {
    type Error = AppError;

    fn try_from(request: TicketRequest) -> Result<Self, Self::Error> {
        let mut errors = BTreeMap::new();

        let title = validate_text(
            &mut errors,
            "title",
            request.title,
            "O título é obrigatório.",
            Some(255),
            "O título deve ter no máximo 255 caracteres.",
        );
        let description = validate_text(
            &mut errors,
            "description",
            request.description,
            "A descrição é obrigatória.",
            None,
            "",
        );
        let sector = validate_text(
            &mut errors,
            "sector",
            request.sector,
            "O setor é obrigatório.",
            Some(255),
            "O setor deve ter no máximo 255 caracteres.",
        );

        let status = match request.status {
            None => TicketStatus::Open,
            Some(value) => match TicketStatus::parse(&value) {
                Some(status) => status,
                None => {
                    errors
                        .entry("status".to_string())
                        .or_default()
                        .push("O status deve ser open, in_progress ou closed.".to_string());
                    TicketStatus::Open
                }
            },
        };

        if !errors.is_empty() {
            return Err(AppError::Validation(errors));
        }

        Ok(Self {
            title,
            description,
            sector,
            status,
        })
    }
}

#[derive(Debug, Serialize)]
pub struct TicketResponse {
    pub id: i32,
    pub title: String,
    pub description: String,
    pub sector: String,
    pub status: TicketStatus,
    pub finished_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

impl From<Ticket> for TicketResponse {
    fn from(ticket: Ticket) -> Self {
        Self {
            id: ticket.id,
            title: ticket.title,
            description: ticket.description,
            sector: ticket.sector,
            status: TicketStatus::parse(&ticket.status).unwrap_or(TicketStatus::Open),
            finished_at: ticket.finished_at.map(format_timestamp),
            created_at: format_timestamp(ticket.created_at),
            updated_at: format_timestamp(ticket.updated_at),
        }
    }
}

fn validate_text(
    errors: &mut BTreeMap<String, Vec<String>>,
    field: &str,
    value: Option<String>,
    required_message: &str,
    max_length: Option<usize>,
    max_message: &str,
) -> String {
    let Some(value) = value else {
        errors
            .entry(field.to_string())
            .or_default()
            .push(required_message.to_string());

        return String::new();
    };

    if value.trim().is_empty() {
        errors
            .entry(field.to_string())
            .or_default()
            .push(required_message.to_string());
    } else if max_length.is_some_and(|max_length| value.chars().count() > max_length) {
        errors
            .entry(field.to_string())
            .or_default()
            .push(max_message.to_string());
    }

    value
}

fn format_timestamp(value: NaiveDateTime) -> String {
    DateTime::<Utc>::from_naive_utc_and_offset(value, Utc)
        .to_rfc3339_opts(SecondsFormat::Micros, true)
}
