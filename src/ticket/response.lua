local json = require("src.infra.json")

local TicketResponse = {}

function TicketResponse.from(row)
  return {
    id = row.id,
    title = row.title,
    description = row.description,
    sector = row.sector,
    status = row.status,
    finished_at = row.finished_at or json.null,
    created_at = row.created_at,
    updated_at = row.updated_at,
  }
end

function TicketResponse.collection(rows)
  local items = json.array({})

  for _, row in ipairs(rows) do
    items[#items + 1] = TicketResponse.from(row)
  end

  return items
end

return TicketResponse
