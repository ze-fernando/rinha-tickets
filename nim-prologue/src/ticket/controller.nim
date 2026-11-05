import std/[json, options]
import prologue
import ./[errors, schemas, service]

proc respondJson(ctx: Context, code: HttpCode, body: JsonNode) =
  ctx.response = jsonResponse(body, code)

proc respondFailure(ctx: Context, failure: Failure, message = "") =
  case failure
  of fNotFound:
    ctx.respondJson(Http404, %*{"detail": "Chamado não existe"})
  of fConflict:
    ctx.respondJson(Http409, %*{"detail": "Chamado já em aberto"})
  of fInvalid:
    ctx.respondJson(Http422, %*{"detail": message})
  of fInternal, fNone:
    ctx.respondJson(Http500, %*{"detail": "Erro interno do servidor"})

proc ticketId(ctx: Context): Option[int64] =
  let parsed = parseId(ctx.getPathParams("id", ""))
  if parsed.ok:
    return some(parsed.value)

  if parsed.failure == fInvalid:
    ctx.respondJson(Http404, %*{"detail": "Not Found"})
  else:
    ctx.respondJson(Http404, %*{"detail": "Chamado não existe"})

  none(int64)

proc listAll*(ctx: Context) {.async, gcsafe.} =
  ctx.respondJson(Http200, service.getAll().toJson)

proc listOpen*(ctx: Context) {.async, gcsafe.} =
  ctx.respondJson(Http200, service.getOpen().toJson)

proc getTicket*(ctx: Context) {.async, gcsafe.} =
  let id = ctx.ticketId()
  if id.isNone:
    return

  let outcome = service.getById(id.get)
  if outcome.ok:
    ctx.respondJson(Http200, outcome.value.toJson)
  else:
    ctx.respondFailure(outcome.failure)

proc createTicket*(ctx: Context) {.async, gcsafe.} =
  let input = parseTicketInput(ctx.request.body)
  if not input.ok:
    ctx.respondFailure(input.failure, input.message)
    return

  let outcome = service.create(input.value)
  if outcome.ok:
    ctx.respondJson(Http201, outcome.value.toJson)
  else:
    ctx.respondFailure(outcome.failure)

proc updateTicket*(ctx: Context) {.async, gcsafe.} =
  let id = ctx.ticketId()
  if id.isNone:
    return

  let input = parseTicketInput(ctx.request.body)
  if not input.ok:
    ctx.respondFailure(input.failure, input.message)
    return

  let outcome = service.update(id.get, input.value)
  if outcome.ok:
    ctx.respondJson(Http200, outcome.value.toJson)
  else:
    ctx.respondFailure(outcome.failure)

proc finishTicket*(ctx: Context) {.async, gcsafe.} =
  let id = ctx.ticketId()
  if id.isNone:
    return

  let outcome = service.finish(id.get)
  if outcome.ok:
    ctx.respondJson(Http200, outcome.value.toJson)
  else:
    ctx.respondFailure(outcome.failure)
