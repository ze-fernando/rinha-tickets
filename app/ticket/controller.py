from http import HTTPStatus

from fastapi import APIRouter

from app.infra.database import Session
from app.ticket import service
from app.ticket.schemas import NewTicket, TicketList, TicketResponse

router = APIRouter(prefix="/api/tickets")


@router.get(
    "/all",
    response_model=TicketList,
    status_code=HTTPStatus.OK,
)
async def get_all(db: Session) -> TicketList:
    return await service.get_all(db)


@router.get(
    "/open",
    response_model=TicketList,
    status_code=HTTPStatus.OK,
)
async def get_open(db: Session) -> TicketList:
    return await service.get_open(db)


@router.get(
    "/{ticket_id:int}",
    response_model=TicketResponse,
    status_code=HTTPStatus.OK,
)
async def get_by_id(db: Session, ticket_id: int) -> TicketResponse:
    return await service.get_by_id(db, ticket_id)


@router.post(
    "/create",
    response_model=TicketResponse,
    status_code=HTTPStatus.CREATED,
)
async def create(db: Session, ticket: NewTicket) -> TicketResponse:
    return await service.create(db, ticket)


@router.put(
    "/{ticket_id:int}/update",
    response_model=TicketResponse,
    status_code=HTTPStatus.OK,
)
async def update(db: Session, ticket_id: int, ticket: NewTicket) -> TicketResponse:
    return await service.update(db, ticket_id, ticket)


@router.put(
    "/{ticket_id:int}/finish",
    response_model=TicketResponse,
    status_code=HTTPStatus.OK,
)
async def finish(db: Session, ticket_id: int) -> TicketResponse:
    return await service.finish(db, ticket_id)
