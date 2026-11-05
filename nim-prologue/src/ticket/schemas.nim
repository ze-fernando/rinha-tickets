import std/[json, options, strutils, times]
import ./[errors, models]

type
  TicketInput* = object
    title*: string
    description*: string
    sector*: string
    status*: string

proc timestamp*(): string =
  now().utc.format("yyyy-MM-dd'T'HH:mm:ss")

proc requireString(payload: JsonNode, field: string): Outcome[string] =
  if not payload.hasKey(field):
    return failed[string](fInvalid, "Field required")

  let value = payload[field]
  if value.kind != JString:
    return failed[string](fInvalid, "Input should be a valid string")

  success(value.getStr)

proc parseStatus(payload: JsonNode): Outcome[string] =
  if not payload.hasKey("status"):
    return success("open")

  let value = payload["status"]
  if value.kind != JString:
    return failed[string](fInvalid, "Input should be a valid string")

  let status = value.getStr
  if not status.isValidStatus:
    return failed[string](
      fInvalid,
      "Input should be 'open', 'in_progress' or 'closed'"
    )

  success(status)

proc parseTicketInput*(body: string): Outcome[TicketInput] =
  var payload: JsonNode
  try:
    payload = parseJson(body)
  except CatchableError:
    return failed[TicketInput](fInvalid, "JSON decode error")

  if payload.kind != JObject:
    return failed[TicketInput](fInvalid, "Input should be a valid object")

  let title = requireString(payload, "title")
  if not title.ok:
    return failed[TicketInput](fInvalid, title.message)

  let description = requireString(payload, "description")
  if not description.ok:
    return failed[TicketInput](fInvalid, description.message)

  let sector = requireString(payload, "sector")
  if not sector.ok:
    return failed[TicketInput](fInvalid, sector.message)

  let status = parseStatus(payload)
  if not status.ok:
    return failed[TicketInput](fInvalid, status.message)

  success(
    TicketInput(
      title: title.value,
      description: description.value,
      sector: sector.value,
      status: status.value
    )
  )

proc parseId*(raw: string): Option[int64] =
  if raw.len == 0:
    return none(int64)

  for character in raw:
    if character notin {'0'..'9'}:
      return none(int64)

  try:
    let value = parseBiggestInt(raw)
    if value > int64.high:
      return none(int64)
    some(value.int64)
  except ValueError:
    none(int64)

proc toJson*(ticket: Ticket): JsonNode =
  result = newJObject()
  result["id"] = %ticket.id
  result["title"] = %ticket.title
  result["description"] = %ticket.description
  result["sector"] = %ticket.sector
  result["status"] = %ticket.status
  result["finished_at"] =
    if ticket.finishedAt.isSome: %ticket.finishedAt.get else: newJNull()
  result["created_at"] = %ticket.createdAt

proc toJson*(tickets: seq[Ticket]): JsonNode =
  var items = newJArray()
  for ticket in tickets:
    items.add(ticket.toJson)
  %*{"data": items}
