use std::collections::BTreeMap;

use axum::Json;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde_json::json;
use thiserror::Error;

#[derive(Debug, Error)]
pub enum AppError {
    #[error("Chamado não encontrado")]
    TicketNotFound,
    #[error("Chamado já em aberto")]
    TicketAlreadyExists,
    #[error("Os dados informados são inválidos.")]
    Validation(BTreeMap<String, Vec<String>>),
    #[error("Erro de banco de dados")]
    Database(#[from] diesel::result::Error),
    #[error("Erro no pool de conexões")]
    Pool(#[from] r2d2::Error),
    #[error("Erro ao executar tarefa em segundo plano")]
    Join(#[from] tokio::task::JoinError),
    #[error("Erro ao executar migrations: {0}")]
    Migration(String),
}

impl AppError {
    pub fn validation(field: &str, message: impl Into<String>) -> Self {
        let mut errors = BTreeMap::new();
        errors.insert(field.to_string(), vec![message.into()]);
        Self::Validation(errors)
    }
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        match self {
            Self::TicketNotFound => error_response(
                StatusCode::NOT_FOUND,
                "TICKET_NOT_FOUND",
                "Chamado não encontrado",
            ),
            Self::TicketAlreadyExists => error_response(
                StatusCode::CONFLICT,
                "TICKET_ALREADY_EXISTS",
                "Chamado já em aberto",
            ),
            Self::Validation(errors) => (
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({
                    "code": "VALIDATION_ERROR",
                    "message": "Os dados informados são inválidos.",
                    "errors": errors,
                })),
            )
                .into_response(),
            error => {
                tracing::error!(error = %error, "erro interno");

                error_response(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "INTERNAL_ERROR",
                    "Erro interno do servidor.",
                )
            }
        }
    }
}

fn error_response(status: StatusCode, code: &'static str, message: &'static str) -> Response {
    (
        status,
        Json(json!({
            "code": code,
            "message": message,
        })),
    )
        .into_response()
}
