local ApiErrors = require("src.ticket.errors")
local TicketRoutes = require("src.ticket.routes")

local App = {}
App.__index = App

local function match(routes, method, path)
  local segments = {}

  for segment in path:gmatch("[^/]+") do
    segments[#segments + 1] = segment
  end

  for _, route in ipairs(routes) do
    if route.method == method and #route.segments == #segments then
      local params = {}
      local matched = true

      for index, expected in ipairs(route.segments) do
        local actual = segments[index]

        if expected:sub(1, 1) == ":" then
          if actual:match("^%d+$") then
            params[expected:sub(2)] = tonumber(actual)
          else
            matched = false
            break
          end
        elseif expected ~= actual then
          matched = false
          break
        end
      end

      if matched then
        return route, params
      end
    end
  end

  return nil
end

function App.new(database)
  return setmetatable({ database = database, routes = TicketRoutes.build() }, App)
end

function App:dispatch(request)
  local route, params = match(self.routes, request.method, request.path)

  if route == nil then
    error(ApiErrors.resource_not_found(), 0)
  end

  return route.action({
    database = self.database,
    request = request,
    params = params,
  })
end

function App:handle(request)
  local ok, status, payload = pcall(self.dispatch, self, request)

  if ok then
    return status, payload
  end

  if ApiErrors.is_api_error(status) then
    return status.status, ApiErrors.payload(status)
  end

  io.stderr:write("erro interno: " .. tostring(status) .. "\n")

  local internal = ApiErrors.internal()

  return internal.status, ApiErrors.payload(internal)
end

return App
