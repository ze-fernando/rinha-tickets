local bindings = require("src.infra.ffi")

local ffi = bindings.ffi
local C = bindings.C

local Clock = {}

function Clock.now_iso8601()
  local time = ffi.new("struct timeval")

  if C.gettimeofday(time, nil) ~= 0 then
    error("Não foi possível obter a hora atual", 0)
  end

  local seconds = tonumber(time.tv_sec)
  local microseconds = tonumber(time.tv_usec)

  return os.date("!%Y-%m-%dT%H:%M:%S", seconds) .. string.format(".%06dZ", microseconds)
end

return Clock
