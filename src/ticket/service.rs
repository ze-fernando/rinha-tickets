use chrono::Utc;
use diesel::prelude::*;
use diesel::result::{DatabaseErrorKind, Error as DieselError};
use diesel::sqlite::SqliteConnection;

use crate::schema::tickets;
use crate::ticket::dto::{TicketData, TicketResponse, TicketStatus};
use crate::ticket::errors::AppError;
use crate::ticket::models::{NewTicket, Ticket};

pub fn find_all(connection: &mut SqliteConnection) -> Result<Vec<TicketResponse>, AppError> {
    let tickets = tickets::table
        .order(tickets::created_at.desc())
        .load::<Ticket>(connection)?;

    Ok(tickets.into_iter().map(TicketResponse::from).collect())
}

pub fn find_open(connection: &mut SqliteConnection) -> Result<Vec<TicketResponse>, AppError> {
    let tickets = tickets::table
        .filter(tickets::status.eq(TicketStatus::Open.as_str()))
        .order(tickets::created_at.desc())
        .load::<Ticket>(connection)?;

    Ok(tickets.into_iter().map(TicketResponse::from).collect())
}

pub fn find_by_id(
    connection: &mut SqliteConnection,
    ticket_id: i32,
) -> Result<TicketResponse, AppError> {
    let ticket = find_model(connection, ticket_id)?;

    Ok(TicketResponse::from(ticket))
}

pub fn create(
    connection: &mut SqliteConnection,
    data: TicketData,
) -> Result<TicketResponse, AppError> {
    connection.transaction::<TicketResponse, AppError, _>(|connection| {
        ensure_title_is_available(connection, &data.title, None)?;

        let now = Utc::now().naive_utc();
        let new_ticket = NewTicket {
            title: &data.title,
            description: &data.description,
            sector: &data.sector,
            status: data.status.as_str(),
            finished_at: None,
            created_at: now,
            updated_at: now,
        };

        match diesel::insert_into(tickets::table)
            .values(&new_ticket)
            .returning(Ticket::as_returning())
            .get_result::<Ticket>(connection)
        {
            Ok(ticket) => Ok(TicketResponse::from(ticket)),
            Err(DieselError::DatabaseError(DatabaseErrorKind::UniqueViolation, _)) => {
                Err(AppError::TicketAlreadyExists)
            }
            Err(error) => Err(AppError::Database(error)),
        }
    })
}

pub fn update(
    connection: &mut SqliteConnection,
    ticket_id: i32,
    data: TicketData,
) -> Result<TicketResponse, AppError> {
    connection.transaction::<TicketResponse, AppError, _>(|connection| {
        let ticket = find_model(connection, ticket_id)?;

        ensure_title_is_available(connection, &data.title, Some(ticket_id))?;

        let now = Utc::now().naive_utc();
        let finished_at = if data.status == TicketStatus::Closed {
            ticket.finished_at.or(Some(now))
        } else {
            None
        };

        let result = diesel::update(tickets::table.find(ticket_id))
            .set((
                tickets::title.eq(&data.title),
                tickets::description.eq(&data.description),
                tickets::sector.eq(&data.sector),
                tickets::status.eq(data.status.as_str()),
                tickets::finished_at.eq(finished_at),
                tickets::updated_at.eq(now),
            ))
            .returning(Ticket::as_returning())
            .get_result::<Ticket>(connection);

        match result {
            Ok(ticket) => Ok(TicketResponse::from(ticket)),
            Err(DieselError::DatabaseError(DatabaseErrorKind::UniqueViolation, _)) => {
                Err(AppError::TicketAlreadyExists)
            }
            Err(error) => Err(AppError::Database(error)),
        }
    })
}

pub fn finish(
    connection: &mut SqliteConnection,
    ticket_id: i32,
) -> Result<TicketResponse, AppError> {
    connection.transaction::<TicketResponse, AppError, _>(|connection| {
        find_model(connection, ticket_id)?;

        let now = Utc::now().naive_utc();
        let result = diesel::update(tickets::table.find(ticket_id))
            .set((
                tickets::status.eq(TicketStatus::Closed.as_str()),
                tickets::finished_at.eq(Some(now)),
                tickets::updated_at.eq(now),
            ))
            .returning(Ticket::as_returning())
            .get_result::<Ticket>(connection);

        match result {
            Ok(ticket) => Ok(TicketResponse::from(ticket)),
            Err(DieselError::DatabaseError(DatabaseErrorKind::UniqueViolation, _)) => {
                Err(AppError::TicketAlreadyExists)
            }
            Err(error) => Err(AppError::Database(error)),
        }
    })
}

fn find_model(connection: &mut SqliteConnection, ticket_id: i32) -> Result<Ticket, AppError> {
    tickets::table
        .find(ticket_id)
        .first::<Ticket>(connection)
        .optional()?
        .ok_or(AppError::TicketNotFound)
}

fn ensure_title_is_available(
    connection: &mut SqliteConnection,
    title: &str,
    ignore_ticket_id: Option<i32>,
) -> Result<(), AppError> {
    let existing_id = match ignore_ticket_id {
        Some(ticket_id) => tickets::table
            .filter(tickets::title.eq(title))
            .filter(tickets::id.ne(ticket_id))
            .select(tickets::id)
            .first::<i32>(connection)
            .optional()?,
        None => tickets::table
            .filter(tickets::title.eq(title))
            .select(tickets::id)
            .first::<i32>(connection)
            .optional()?,
    };

    if existing_id.is_some() {
        return Err(AppError::TicketAlreadyExists);
    }

    Ok(())
}
