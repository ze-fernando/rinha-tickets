from datetime import datetime
from enum import StrEnum

from sqlalchemy import DateTime, Enum, String
from sqlalchemy.orm import Mapped, mapped_column

from app.infra.database import Base


class Status(StrEnum):
    OPEN = "open"
    IN_PROGRESS = "in_progress"
    CLOSED = "closed"


class Ticket(Base):
    __tablename__ = "tickets"

    title: Mapped[str] = mapped_column(String)
    description: Mapped[str] = mapped_column(String)
    sector: Mapped[str] = mapped_column(String)
    status: Mapped[Status] = mapped_column(Enum(Status))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
