local TicketController = require("src.ticket.controller")

local TicketRoutes = {}

local definitions = {
  { method = "GET", path = "/api/tickets/all", action = TicketController.find_all },
  { method = "GET", path = "/api/tickets/open", action = TicketController.find_open },
  { method = "GET", path = "/api/tickets/:id", action = TicketController.find_by_id },
  { method = "POST", path = "/api/tickets/create", action = TicketController.create },
  { method = "PUT", path = "/api/tickets/:id/update", action = TicketController.update },
  { method = "PUT", path = "/api/tickets/:id/finish", action = TicketController.finish },
}

local function split(path)
  local segments = {}

  for segment in path:gmatch("[^/]+") do
    segments[#segments + 1] = segment
  end

  return segments
end

function TicketRoutes.build()
  local routes = {}

  for _, definition in ipairs(definitions) do
    routes[#routes + 1] = {
      method = definition.method,
      segments = split(definition.path),
      action = definition.action,
    }
  end

  return routes
end

return TicketRoutes
