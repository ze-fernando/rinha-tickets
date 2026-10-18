from fastapi import FastAPI

from app.ticket.controller import router

app = FastAPI()

app.include_router(router)
