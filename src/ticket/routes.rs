use axum::Json;
use axum::Router;
use axum::extract::{Path, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::routing::{get, post, put};
use serde_json::json;

use crate::state::AppState;
use crate::ticket::dto::{TicketData, TicketRequest, TicketResponse};
use crate::ticket::errors::AppError;
use crate::ticket::extractors::ApiJson;
use crate::ticket::service;

pub fn router(state: AppState) -> Router {
    Router::new()
        .route("/api/tickets/all", get(find_all))
        .route("/api/tickets/open", get(find_open))
        .route("/api/tickets/{ticket_id}", get(find_by_id))
        .route("/api/tickets/create", post(create))
        .route("/api/tickets/{ticket_id}/update", put(update))
        .route("/api/tickets/{ticket_id}/finish", put(finish))
        .fallback(not_found)
        .with_state(state)
}

async fn find_all(State(state): State<AppState>) -> Result<Json<Vec<TicketResponse>>, AppError> {
    let tickets = state.db.run(service::find_all).await?;

    Ok(Json(tickets))
}

async fn find_open(State(state): State<AppState>) -> Result<Json<Vec<TicketResponse>>, AppError> {
    let tickets = state.db.run(service::find_open).await?;

    Ok(Json(tickets))
}

async fn find_by_id(
    State(state): State<AppState>,
    Path(ticket_id): Path<i32>,
) -> Result<Json<TicketResponse>, AppError> {
    let ticket = state
        .db
        .run(move |connection| service::find_by_id(connection, ticket_id))
        .await?;

    Ok(Json(ticket))
}

async fn create(
    State(state): State<AppState>,
    ApiJson(payload): ApiJson<TicketRequest>,
) -> Result<(StatusCode, Json<TicketResponse>), AppError> {
    let data = TicketData::try_from(payload)?;
    let ticket = state
        .db
        .run(move |connection| service::create(connection, data))
        .await?;

    Ok((StatusCode::CREATED, Json(ticket)))
}

async fn update(
    State(state): State<AppState>,
    Path(ticket_id): Path<i32>,
    ApiJson(payload): ApiJson<TicketRequest>,
) -> Result<Json<TicketResponse>, AppError> {
    let data = TicketData::try_from(payload)?;
    let ticket = state
        .db
        .run(move |connection| service::update(connection, ticket_id, data))
        .await?;

    Ok(Json(ticket))
}

async fn finish(
    State(state): State<AppState>,
    Path(ticket_id): Path<i32>,
) -> Result<Json<TicketResponse>, AppError> {
    let ticket = state
        .db
        .run(move |connection| service::finish(connection, ticket_id))
        .await?;

    Ok(Json(ticket))
}

async fn not_found() -> impl IntoResponse {
    (
        StatusCode::NOT_FOUND,
        Json(json!({
            "code": "RESOURCE_NOT_FOUND",
            "message": "Recurso não encontrado.",
        })),
    )
}
