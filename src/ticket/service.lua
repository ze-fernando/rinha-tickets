local Clock = require("src.infra.clock")
local ApiErrors = require("src.ticket.errors")
local TicketModel = require("src.ticket.model")
local Status = require("src.ticket.status")

local TicketService = {}

local function is_unique_violation(failure)
  return type(failure) == "table"
    and failure.__database_error == true
    and (failure.code == 2067 or failure.code == 1555)
end

local function ensure_title_is_available(database, title, ignore_ticket_id)
  local existing = TicketModel.find_id_by_title(database, title, ignore_ticket_id)

  if existing then
    error(ApiErrors.ticket_already_exists(), 0)
  end
end

local function raise_failure(failure)
  if is_unique_violation(failure) then
    error(ApiErrors.ticket_already_exists(), 0)
  end

  error(failure, 0)
end

function TicketService.find_all(database)
  return TicketModel.find_all(database)
end

function TicketService.find_open(database)
  return TicketModel.find_open(database)
end

function TicketService.find_by_id(database, ticket_id)
  local ticket = TicketModel.find_by_id(database, ticket_id)

  if ticket == nil then
    error(ApiErrors.ticket_not_found(), 0)
  end

  return ticket
end

function TicketService.create(database, data)
  local ticket_id

  local ok, failure = pcall(function()
    database:transaction(function()
      ensure_title_is_available(database, data.title)
      ticket_id = TicketModel.insert(database, data, Clock.now_iso8601())
    end)
  end)

  if not ok then
    raise_failure(failure)
  end

  return TicketModel.find_by_id(database, ticket_id)
end

function TicketService.update(database, ticket_id, data)
  local ok, failure = pcall(function()
    database:transaction(function()
      local current = TicketService.find_by_id(database, ticket_id)

      ensure_title_is_available(database, data.title, ticket_id)

      local now = Clock.now_iso8601()
      local finished_at

      if data.status == Status.CLOSED then
        finished_at = current.finished_at or now
      end

      TicketModel.update(database, ticket_id, data, finished_at, now)
    end)
  end)

  if not ok then
    raise_failure(failure)
  end

  return TicketModel.find_by_id(database, ticket_id)
end

function TicketService.finish(database, ticket_id)
  local ok, failure = pcall(function()
    database:transaction(function()
      TicketService.find_by_id(database, ticket_id)
      TicketModel.finish(database, ticket_id, Clock.now_iso8601())
    end)
  end)

  if not ok then
    raise_failure(failure)
  end

  return TicketModel.find_by_id(database, ticket_id)
end

return TicketService
