local json = require("src.infra.json")
local ApiErrors = require("src.ticket.errors")
local TicketData = require("src.ticket.dto")
local TicketResponse = require("src.ticket.response")
local TicketService = require("src.ticket.service")

local TicketController = {}

local function decode_body(request)
  if request.body == nil or request.body == "" then
    error(ApiErrors.validation({ body = { "O corpo da requisição é obrigatório." } }), 0)
  end

  local ok, payload = pcall(json.decode, request.body)

  if not ok then
    error(ApiErrors.validation({ body = { "O corpo da requisição deve conter um JSON válido." } }), 0)
  end

  return payload
end

local function ticket_data(request)
  local data, validation = TicketData.parse(decode_body(request))

  if data == nil then
    error(validation, 0)
  end

  return data
end

function TicketController.find_all(context)
  return 200, TicketResponse.collection(TicketService.find_all(context.database))
end

function TicketController.find_open(context)
  return 200, TicketResponse.collection(TicketService.find_open(context.database))
end

function TicketController.find_by_id(context)
  local ticket = TicketService.find_by_id(context.database, context.params.id)

  return 200, TicketResponse.from(ticket)
end

function TicketController.create(context)
  local ticket = TicketService.create(context.database, ticket_data(context.request))

  return 201, TicketResponse.from(ticket)
end

function TicketController.update(context)
  local data = ticket_data(context.request)
  local ticket = TicketService.update(context.database, context.params.id, data)

  return 200, TicketResponse.from(ticket)
end

function TicketController.finish(context)
  local ticket = TicketService.finish(context.database, context.params.id)

  return 200, TicketResponse.from(ticket)
end

return TicketController
