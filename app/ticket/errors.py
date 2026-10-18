from http import HTTPStatus

from fastapi import HTTPException


class TicketNotFound(HTTPException):
    def __init__(self, detail: str = "Chamado não existe") -> None:
        super().__init__(HTTPStatus.NOT_FOUND, detail)


class TicketAlreadyExists(HTTPException):
    def __init__(self, detail: str = "Chamado já em aberto") -> None:
        super().__init__(HTTPStatus.CONFLICT, detail)
