import std/[options, strutils]
import norm/sqlite
import ../infra/database
import ./[errors, models, schemas]

proc failureFor(error: ref DbError): Failure =
  if error.msg.contains("UNIQUE constraint failed"): fConflict else: fInternal

proc getAll*(): seq[Ticket] =
  db().selectAll(Ticket)

proc getOpen*(): seq[Ticket] =
  db().select(Ticket, "status = ?", "open")

proc getById*(id: int64): Outcome[Ticket] =
  let tickets = db().select(Ticket, "id = ?", id)
  if tickets.len == 0:
    return failed[Ticket](fNotFound)
  success(tickets[0])

proc create*(input: TicketInput): Outcome[Ticket] =
  if db().exists(Ticket, "title = ?", input.title):
    return failed[Ticket](fConflict)

  let stamp = timestamp()
  var ticket = Ticket(
    title: input.title,
    description: input.description,
    sector: input.sector,
    status: input.status,
    finishedAt: none(string),
    createdAt: stamp,
    updatedAt: stamp
  )

  try:
    db().insert(ticket)
  except DbError as error:
    return failed[Ticket](failureFor(error))

  success(ticket)

proc update*(id: int64, input: TicketInput): Outcome[Ticket] =
  let tickets = db().select(Ticket, "id = ?", id)
  if tickets.len == 0:
    return failed[Ticket](fNotFound)

  var ticket = tickets[0]
  ticket.title = input.title
  ticket.description = input.description
  ticket.sector = input.sector
  ticket.status = input.status
  ticket.updatedAt = timestamp()

  if ticket.status == "closed":
    if ticket.finishedAt.isNone:
      ticket.finishedAt = some(timestamp())
  else:
    ticket.finishedAt = none(string)

  try:
    db().update(ticket)
  except DbError as error:
    return failed[Ticket](failureFor(error))

  success(ticket)

proc finish*(id: int64): Outcome[Ticket] =
  let tickets = db().select(Ticket, "id = ?", id)
  if tickets.len == 0:
    return failed[Ticket](fNotFound)

  var ticket = tickets[0]
  ticket.status = "closed"
  ticket.finishedAt = some(timestamp())
  ticket.updatedAt = timestamp()

  try:
    db().update(ticket)
  except DbError as error:
    return failed[Ticket](failureFor(error))

  success(ticket)
