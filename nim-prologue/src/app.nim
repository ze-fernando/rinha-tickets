import std/[os, strutils]
import prologue
import ./ticket/controller

proc jsonNotFound(ctx: Context) {.async, gcsafe.} =
  ctx.response = jsonResponse(%*{"detail": "Not Found"}, Http404)

proc jsonInternal(ctx: Context) {.async, gcsafe.} =
  ctx.response = jsonResponse(%*{"detail": "Erro interno do servidor"}, Http500)

proc configuredPort(): Port =
  let raw = getEnv("PORT")
  if raw.len == 0:
    return Port(8000)

  try:
    let value = parseInt(raw)
    if value > 0 and value <= 65535:
      Port(value)
    else:
      Port(8000)
  except ValueError:
    Port(8000)

proc newTicketApp*(): Prologue =
  result = newApp(
    settings = newSettings(port = configuredPort(), debug = false),
    errorHandlerTable = newErrorHandlerTable(
      {Http404: jsonNotFound, Http500: jsonInternal}
    )
  )

  result.get("/api/tickets/all", listAll)
  result.get("/api/tickets/open", listOpen)
  result.post("/api/tickets/create", createTicket)
  result.get("/api/tickets/{id}", getTicket)
  result.put("/api/tickets/{id}/update", updateTicket)
  result.put("/api/tickets/{id}/finish", finishTicket)
