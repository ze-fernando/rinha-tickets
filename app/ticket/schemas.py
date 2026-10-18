from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.ticket.models import Status


class NewTicket(BaseModel):
    title: str
    description: str
    sector: str
    status: Status = Status.OPEN


class TicketResponse(NewTicket):
    model_config = ConfigDict(from_attributes=True)
    id: int
    finished_at: datetime | None
    created_at: datetime


class TicketList(BaseModel):
    data: list[TicketResponse]
