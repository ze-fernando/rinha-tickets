local json = require("src.infra.json")
local ApiErrors = require("src.ticket.errors")
local Status = require("src.ticket.status")

local TicketData = {}

local function add(details, field, message)
  local messages = details[field]

  if messages == nil then
    messages = {}
    details[field] = messages
  end

  messages[#messages + 1] = message
end

local function character_count(value)
  local utf8 = rawget(_G, "utf8")

  if utf8 and utf8.len then
    local count = utf8.len(value)

    if count then
      return count
    end
  end

  return select(2, value:gsub("[^\128-\191]", ""))
end

local function is_missing(value)
  return value == nil or json.is_null(value)
end

local function is_blank(value)
  return type(value) == "string" and value:match("^%s*$") ~= nil
end

local function validate_text(details, field, value, required_message, type_message, maximum, maximum_message)
  if is_missing(value) or is_blank(value) then
    add(details, field, required_message)
    return
  end

  if type(value) ~= "string" then
    add(details, field, type_message)
    return
  end

  if maximum ~= nil and character_count(value) > maximum then
    add(details, field, maximum_message)
  end
end

function TicketData.parse(payload)
  if is_missing(payload) or type(payload) ~= "table" or json.is_array(payload) then
    return nil, ApiErrors.validation({
      body = { "O corpo da requisição deve ser um objeto JSON." },
    })
  end

  local details = {}

  validate_text(
    details,
    "title",
    payload.title,
    "O título é obrigatório.",
    "O título deve ser um texto.",
    255,
    "O título deve ter no máximo 255 caracteres."
  )

  validate_text(
    details,
    "description",
    payload.description,
    "A descrição é obrigatória.",
    "A descrição deve ser um texto.",
    nil,
    nil
  )

  validate_text(
    details,
    "sector",
    payload.sector,
    "O setor é obrigatório.",
    "O setor deve ser um texto.",
    255,
    "O setor deve ter no máximo 255 caracteres."
  )

  local status = payload.status

  if is_missing(status) then
    status = Status.OPEN
  elseif type(status) ~= "string" then
    add(details, "status", "O status deve ser open, in_progress ou closed.")
  else
    status = status:lower()

    if not Status.valid(status) then
      add(details, "status", "O status deve ser open, in_progress ou closed.")
    end
  end

  if next(details) ~= nil then
    return nil, ApiErrors.validation(details)
  end

  return {
    title = payload.title,
    description = payload.description,
    sector = payload.sector,
    status = status,
  }
end

return TicketData
