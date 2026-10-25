local ApiErrors = require("src.ticket.errors")
local json = require("src.infra.json")
local TicketData = require("src.ticket.dto")

local function parse_error(t, payload)
  local data, failure = TicketData.parse(payload)

  t:equal(data, nil)
  t:truthy(ApiErrors.is_api_error(failure))
  t:equal(failure.status, 422)

  return failure
end

return {
  name = "dto",
  tests = {
    {
      name = "usa o status open por padrão",
      fn = function(t)
        local data = TicketData.parse({ title = "Chamado", description = "Descrição", sector = "TI" })

        t:equal(data.title, "Chamado")
        t:equal(data.status, "open")
      end,
    },
    {
      name = "normaliza o status para minúsculas",
      fn = function(t)
        local data = TicketData.parse({
          title = "Chamado",
          description = "Descrição",
          sector = "TI",
          status = "IN_PROGRESS",
        })

        t:equal(data.status, "in_progress")
      end,
    },
    {
      name = "exige todos os campos obrigatórios",
      fn = function(t)
        local failure = parse_error(t, {})

        t:equal(failure.errors.title[1], "O título é obrigatório.")
        t:equal(failure.errors.description[1], "A descrição é obrigatória.")
        t:equal(failure.errors.sector[1], "O setor é obrigatório.")
      end,
    },
    {
      name = "recusa textos em branco",
      fn = function(t)
        local failure = parse_error(t, { title = "   ", description = "\n", sector = "\t" })

        t:equal(failure.errors.title[1], "O título é obrigatório.")
        t:equal(failure.errors.description[1], "A descrição é obrigatória.")
        t:equal(failure.errors.sector[1], "O setor é obrigatório.")
      end,
    },
    {
      name = "recusa campos que não são texto",
      fn = function(t)
        local failure = parse_error(t, { title = 10, description = true, sector = json.array({}) })

        t:equal(failure.errors.title[1], "O título deve ser um texto.")
        t:equal(failure.errors.description[1], "A descrição deve ser um texto.")
        t:equal(failure.errors.sector[1], "O setor deve ser um texto.")
      end,
    },
    {
      name = "limita título e setor a 255 caracteres",
      fn = function(t)
        local failure = parse_error(t, {
          title = string.rep("á", 256),
          description = "Descrição",
          sector = string.rep("b", 256),
        })

        t:equal(failure.errors.title[1], "O título deve ter no máximo 255 caracteres.")
        t:equal(failure.errors.sector[1], "O setor deve ter no máximo 255 caracteres.")
      end,
    },
    {
      name = "aceita título e setor com 255 caracteres",
      fn = function(t)
        local data = TicketData.parse({
          title = string.rep("á", 255),
          description = "Descrição",
          sector = string.rep("b", 255),
        })

        t:equal(#data.title, 510)
      end,
    },
    {
      name = "recusa status inválido",
      fn = function(t)
        local failure = parse_error(t, {
          title = "Chamado",
          description = "Descrição",
          sector = "TI",
          status = "invalid",
        })

        t:equal(failure.errors.status[1], "O status deve ser open, in_progress ou closed.")
      end,
    },
    {
      name = "recusa status que não é texto",
      fn = function(t)
        local failure = parse_error(t, {
          title = "Chamado",
          description = "Descrição",
          sector = "TI",
          status = 1,
        })

        t:equal(failure.errors.status[1], "O status deve ser open, in_progress ou closed.")
      end,
    },
    {
      name = "recusa corpo que não é objeto",
      fn = function(t)
        local failure = parse_error(t, json.array({ "Chamado" }))

        t:equal(failure.errors.body[1], "O corpo da requisição deve ser um objeto JSON.")
      end,
    },
  },
}
