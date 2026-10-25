local Config = {}

local function project_root()
  local source = debug.getinfo(1, "S").source

  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end

  local root = source:match("^(.*)/src/config%.lua$")

  if root == nil or root == "" then
    return "."
  end

  return root
end

local function read_env_file(path)
  local values = {}
  local file = io.open(path, "r")

  if not file then
    return values
  end

  for line in file:lines() do
    local trimmed = line:gsub("^%s+", ""):gsub("%s+$", "")

    if trimmed ~= "" and trimmed:sub(1, 1) ~= "#" then
      local key, value = trimmed:match("^([%w_]+)%s*=%s*(.-)%s*$")

      if key and value then
        local first = value:sub(1, 1)
        local last = value:sub(-1)

        if (first == '"' and last == '"') or (first == "'" and last == "'") then
          value = value:sub(2, -2)
        end

        values[key] = value
      end
    end
  end

  file:close()

  return values
end

local root = project_root()
local file_values = read_env_file(root .. "/.env")

local function env(key, default)
  local value = os.getenv(key)

  if value == nil or value == "" then
    value = file_values[key]
  end

  if value == nil or value == "" then
    return default
  end

  return value
end

local function resolve(path)
  if path:sub(1, 1) == "/" then
    return path
  end

  return root .. "/" .. path
end

Config.root = root
Config.port = tonumber(env("PORT", "8000"))
Config.host = env("HOST", "0.0.0.0")
Config.database_path = resolve(env("DATABASE_PATH", "database.sqlite"))
Config.migrations_path = root .. "/migrations"

return Config
