from datetime import UTC, datetime

from sqlalchemy import select

from app.infra.database import Session
from app.ticket.errors import TicketAlreadyExists, TicketNotFound
from app.ticket.models import Status, Ticket
from app.ticket.schemas import NewTicket, TicketList, TicketResponse


async def get_all(db: Session) -> TicketList:
    tickets = await db.scalars(select(Ticket))

    return TicketList(data=[TicketResponse.model_validate(t) for t in tickets])


async def get_open(db: Session) -> TicketList:
    tickets = await db.scalars(select(Ticket).where(Ticket.status == Status.OPEN))

    return TicketList(data=[TicketResponse.model_validate(t) for t in tickets])


async def get_by_id(db: Session, ticket_id: int) -> TicketResponse:
    ticket = await db.scalar(select(Ticket).where(Ticket.id == ticket_id))

    if not ticket:
        raise TicketNotFound()

    return TicketResponse.model_validate(ticket)


async def create(db: Session, ticket: NewTicket) -> TicketResponse:
    ticket_db = await db.scalar(select(Ticket).where(Ticket.title == ticket.title))
    if ticket_db:
        raise TicketAlreadyExists()

    ticket_db = Ticket(**ticket.model_dump())
    db.add(ticket_db)

    await db.commit()
    await db.refresh(ticket_db)

    return TicketResponse.model_validate(ticket_db)


async def update(db: Session, ticket_id: int, ticket: NewTicket) -> TicketResponse:
    ticket_db = await db.scalar(select(Ticket).where(Ticket.id == ticket_id))

    if not ticket_db:
        raise TicketNotFound()

    ticket_db.title = ticket.title
    ticket_db.description = ticket.description
    ticket_db.sector = ticket.sector
    ticket_db.status = ticket.status
    if ticket.status == Status.CLOSED:
        ticket_db.finished_at = ticket_db.finished_at or datetime.now(UTC)
    else:
        ticket_db.finished_at = None

    await db.commit()
    await db.refresh(ticket_db)

    return TicketResponse.model_validate(ticket_db)


async def finish(db: Session, ticket_id: int) -> TicketResponse:
    ticket = await db.scalar(select(Ticket).where(Ticket.id == ticket_id))

    if not ticket:
        raise TicketNotFound()

    ticket.status = Status.CLOSED
    ticket.finished_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(ticket)

    return TicketResponse.model_validate(ticket)
