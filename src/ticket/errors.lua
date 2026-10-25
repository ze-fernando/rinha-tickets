local ApiErrors = {}

local function build(status, code, message, details)
  return {
    __api_error = true,
    status = status,
    code = code,
    message = message,
    errors = details,
  }
end

function ApiErrors.is_api_error(value)
  return type(value) == "table" and value.__api_error == true
end

function ApiErrors.ticket_not_found()
  return build(404, "TICKET_NOT_FOUND", "Chamado não encontrado")
end

function ApiErrors.ticket_already_exists()
  return build(409, "TICKET_ALREADY_EXISTS", "Chamado já em aberto")
end

function ApiErrors.validation(details)
  return build(422, "VALIDATION_ERROR", "Os dados informados são inválidos.", details)
end

function ApiErrors.resource_not_found()
  return build(404, "RESOURCE_NOT_FOUND", "Recurso não encontrado.")
end

function ApiErrors.internal()
  return build(500, "INTERNAL_ERROR", "Erro interno do servidor.")
end

function ApiErrors.payload(error)
  local payload = {
    code = error.code,
    message = error.message,
  }

  if error.errors ~= nil then
    payload.errors = error.errors
  end

  return payload
end

return ApiErrors
