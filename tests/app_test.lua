local json = require("src.infra.json")
local App = require("src.app")
local Config = require("src.config")
local Database = require("src.infra.database")

local SCHEMA_PATH = Config.migrations_path .. "/20261025000000_create_tickets.sql"

local function read_file(path)
  local file = io.open(path, "r")

  if not file then
    error("Arquivo não encontrado: " .. path, 0)
  end

  local content = file:read("a")
  file:close()

  return content
end

local function new_application()
  local database = Database.open(":memory:")
  database:execute_script(read_file(SCHEMA_PATH))

  return App.new(database)
end

local function request(method, path, body)
  return { method = method, path = path, body = body or "", headers = {} }
end

local function create_ticket(application, payload)
  local body = json.encode(payload or {
    title = "Chamado",
    description = "Descrição",
    sector = "TI",
  })

  return application:handle(request("POST", "/api/tickets/create", body))
end

return {
  name = "app",
  tests = {
    {
      name = "retorna 404 padronizado para rota desconhecida",
      fn = function(t)
        local application = new_application()
        local status, payload = application:handle(request("GET", "/api/unknown"))

        t:equal(status, 404)
        t:equal(payload.code, "RESOURCE_NOT_FOUND")
        t:equal(payload.message, "Recurso não encontrado.")
      end,
    },
    {
      name = "retorna 404 para id não numérico",
      fn = function(t)
        local application = new_application()
        local status, payload = application:handle(request("GET", "/api/tickets/abc"))

        t:equal(status, 404)
        t:equal(payload.code, "RESOURCE_NOT_FOUND")
      end,
    },
    {
      name = "cria um chamado pela rota",
      fn = function(t)
        local application = new_application()
        local status, payload = create_ticket(application, {
          title = "Chamado novo",
          description = "Descrição do chamado",
          sector = "TI",
        })

        t:equal(status, 201)
        t:equal(type(payload.id), "number")
        t:equal(payload.status, "open")
        t:truthy(json.is_null(payload.finished_at))
        t:matches(payload.created_at, "Z$")
      end,
    },
    {
      name = "normaliza o status recebido pela rota",
      fn = function(t)
        local application = new_application()
        local status, payload = create_ticket(application, {
          title = "Chamado em andamento",
          description = "Descrição",
          sector = "TI",
          status = "IN_PROGRESS",
        })

        t:equal(status, 201)
        t:equal(payload.status, "in_progress")
      end,
    },
    {
      name = "retorna 409 para título duplicado",
      fn = function(t)
        local application = new_application()
        local payload = {
          title = "Chamado duplicado",
          description = "Descrição",
          sector = "TI",
        }

        create_ticket(application, payload)

        local status, body = create_ticket(application, payload)

        t:equal(status, 409)
        t:equal(body.code, "TICKET_ALREADY_EXISTS")
        t:equal(body.message, "Chamado já em aberto")
      end,
    },
    {
      name = "retorna 422 para payload inválido",
      fn = function(t)
        local application = new_application()
        local status, payload = create_ticket(application, { title = "Sem descrição", sector = "TI" })

        t:equal(status, 422)
        t:equal(payload.code, "VALIDATION_ERROR")
        t:equal(payload.message, "Os dados informados são inválidos.")
        t:equal(payload.errors.description[1], "A descrição é obrigatória.")
      end,
    },
    {
      name = "retorna 422 para json inválido",
      fn = function(t)
        local application = new_application()
        local status, payload = application:handle(request("POST", "/api/tickets/create", "{invalid}"))

        t:equal(status, 422)
        t:equal(payload.errors.body[1], "O corpo da requisição deve conter um JSON válido.")
      end,
    },
    {
      name = "exige corpo na criação",
      fn = function(t)
        local application = new_application()
        local status, payload = application:handle(request("POST", "/api/tickets/create"))

        t:equal(status, 422)
        t:equal(payload.errors.body[1], "O corpo da requisição é obrigatório.")
      end,
    },
    {
      name = "atualiza um chamado pela rota",
      fn = function(t)
        local application = new_application()
        local _, created = create_ticket(application, {
          title = "Chamado para atualizar",
          description = "Descrição",
          sector = "TI",
        })

        local body = json.encode({
          title = "Chamado atualizado",
          description = "Descrição atualizada",
          sector = "RH",
          status = "closed",
        })

        local status, payload = application:handle(
          request("PUT", "/api/tickets/" .. created.id .. "/update", body)
        )

        t:equal(status, 200)
        t:equal(payload.title, "Chamado atualizado")
        t:equal(payload.status, "closed")
        t:truthy(payload.finished_at)
      end,
    },
    {
      name = "finaliza um chamado pela rota",
      fn = function(t)
        local application = new_application()
        local _, created = create_ticket(application, {
          title = "Chamado para finalizar",
          description = "Descrição",
          sector = "TI",
        })

        local status, payload = application:handle(
          request("PUT", "/api/tickets/" .. created.id .. "/finish")
        )

        t:equal(status, 200)
        t:equal(payload.status, "closed")
        t:truthy(payload.finished_at)
      end,
    },
    {
      name = "lista todos e apenas os abertos",
      fn = function(t)
        local application = new_application()

        create_ticket(application, { title = "Aberto", description = "Descrição", sector = "TI" })
        create_ticket(application, {
          title = "Em andamento",
          description = "Descrição",
          sector = "TI",
          status = "in_progress",
        })

        local all_status, all = application:handle(request("GET", "/api/tickets/all"))
        local open_status, open = application:handle(request("GET", "/api/tickets/open"))

        t:equal(all_status, 200)
        t:truthy(json.is_array(all))
        t:equal(#all, 2)
        t:equal(open_status, 200)
        t:truthy(json.is_array(open))
        t:equal(#open, 1)
        t:equal(open[1].status, "open")
      end,
    },
    {
      name = "retorna lista vazia quando não há chamados",
      fn = function(t)
        local application = new_application()
        local status, payload = application:handle(request("GET", "/api/tickets/all"))

        t:equal(status, 200)
        t:truthy(json.is_array(payload))
        t:equal(#payload, 0)
        t:equal(json.encode(payload), "[]")
      end,
    },
  },
}
