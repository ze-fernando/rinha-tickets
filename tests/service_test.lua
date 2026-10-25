local Config = require("src.config")
local Database = require("src.infra.database")
local Migrator = require("src.infra.migrator")
local TicketService = require("src.ticket.service")
local Status = require("src.ticket.status")

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

local function new_database()
  local database = Database.open(":memory:")
  database:execute_script(read_file(SCHEMA_PATH))

  return database
end

local sequence = 0

local function new_data(overrides)
  sequence = sequence + 1

  local data = {
    title = "Chamado " .. sequence,
    description = "Descrição " .. sequence,
    sector = "TI",
    status = Status.OPEN,
  }

  for key, value in pairs(overrides or {}) do
    data[key] = value
  end

  return data
end

return {
  name = "service",
  tests = {
    {
      name = "cria um chamado com status open",
      fn = function(t)
        local database = new_database()
        local ticket = TicketService.create(database, new_data())

        t:equal(type(ticket.id), "number")
        t:equal(ticket.status, Status.OPEN)
        t:equal(ticket.finished_at, nil)
        t:matches(ticket.created_at, "^%d%d%d%d%-%d%d%-%d%dT%d%d:%d%d:%d%d%.%d%d%d%d%d%dZ$")
        t:equal(ticket.created_at, ticket.updated_at)
      end,
    },
    {
      name = "recusa título duplicado",
      fn = function(t)
        local database = new_database()
        local data = new_data()

        TicketService.create(database, data)

        local failure = t:error_status(function()
          TicketService.create(database, new_data({ title = data.title }))
        end, 409)

        t:equal(failure.code, "TICKET_ALREADY_EXISTS")
        t:equal(failure.message, "Chamado já em aberto")
      end,
    },
    {
      name = "lista todos os chamados do mais recente para o mais antigo",
      fn = function(t)
        local database = new_database()
        local first = TicketService.create(database, new_data())
        local second = TicketService.create(database, new_data())
        local third = TicketService.create(database, new_data())
        local tickets = TicketService.find_all(database)

        t:equal(#tickets, 3)
        t:equal(tickets[1].id, third.id)
        t:equal(tickets[2].id, second.id)
        t:equal(tickets[3].id, first.id)
      end,
    },
    {
      name = "lista apenas chamados abertos",
      fn = function(t)
        local database = new_database()
        local open_ticket = TicketService.create(database, new_data())
        TicketService.create(database, new_data({ status = Status.IN_PROGRESS }))
        TicketService.create(database, new_data({ status = Status.CLOSED }))

        local tickets = TicketService.find_open(database)

        t:equal(#tickets, 1)
        t:equal(tickets[1].id, open_ticket.id)
      end,
    },
    {
      name = "busca um chamado por id",
      fn = function(t)
        local database = new_database()
        local created = TicketService.create(database, new_data())
        local ticket = TicketService.find_by_id(database, created.id)

        t:equal(ticket.title, created.title)
      end,
    },
    {
      name = "retorna 404 para chamado inexistente",
      fn = function(t)
        local database = new_database()
        local failure = t:error_status(function() TicketService.find_by_id(database, 999999) end, 404)

        t:equal(failure.code, "TICKET_NOT_FOUND")
        t:equal(failure.message, "Chamado não encontrado")
      end,
    },
    {
      name = "fecha, preserva e limpa finished_at na atualização",
      fn = function(t)
        local database = new_database()
        local created = TicketService.create(database, new_data())
        local data = new_data({ title = created.title, status = Status.CLOSED })

        local closed = TicketService.update(database, created.id, data)

        t:equal(closed.status, Status.CLOSED)
        t:truthy(closed.finished_at)

        local closed_again = TicketService.update(
          database,
          created.id,
          new_data({ title = created.title, status = Status.CLOSED })
        )

        t:equal(closed_again.finished_at, closed.finished_at)

        local reopened = TicketService.update(
          database,
          created.id,
          new_data({ title = created.title, status = Status.OPEN })
        )

        t:equal(reopened.status, Status.OPEN)
        t:equal(reopened.finished_at, nil)
        t:truthy(reopened.updated_at >= created.updated_at)
      end,
    },
    {
      name = "recusa atualização para um título já usado",
      fn = function(t)
        local database = new_database()
        local first = TicketService.create(database, new_data())
        local second = TicketService.create(database, new_data())

        t:error_status(function()
          TicketService.update(
            database,
            second.id,
            new_data({ title = first.title, status = Status.OPEN })
          )
        end, 409)

        local unchanged = TicketService.find_by_id(database, second.id)

        t:equal(unchanged.title, second.title)
      end,
    },
    {
      name = "finaliza um chamado",
      fn = function(t)
        local database = new_database()
        local created = TicketService.create(database, new_data({ status = Status.IN_PROGRESS }))
        local finished = TicketService.finish(database, created.id)

        t:equal(finished.status, Status.CLOSED)
        t:truthy(finished.finished_at)
        t:truthy(finished.finished_at > created.updated_at)
      end,
    },
    {
      name = "retorna 404 ao finalizar chamado inexistente",
      fn = function(t)
        local database = new_database()
        local failure = t:error_status(function() TicketService.finish(database, 999999) end, 404)

        t:equal(failure.code, "TICKET_NOT_FOUND")
      end,
    },
    {
      name = "executa as migrations de forma idempotente",
      fn = function(t)
        local path = os.tmpname()
        os.remove(path)

        local database = Database.open(path)

        Migrator.run(database, Config.migrations_path)
        Migrator.run(database, Config.migrations_path)

        local versions = database:query("SELECT version FROM schema_migrations")

        t:equal(#versions, 1)
        t:equal(versions[1].version, "20261025000000_create_tickets")

        database:close()

        os.remove(path)
        os.remove(path .. "-wal")
        os.remove(path .. "-shm")
      end,
    },
  },
}
