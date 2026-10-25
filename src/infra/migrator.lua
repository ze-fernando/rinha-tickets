local Clock = require("src.infra.clock")

local Migrator = {}

local function read_file(path)
  local file = io.open(path, "r")

  if not file then
    error("Migration não encontrada: " .. path, 0)
  end

  local content = file:read("a")
  file:close()

  return content
end

function Migrator.run(database, migrations_path)
  database:execute("CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TEXT NOT NULL)")

  local applied = {}

  for _, row in ipairs(database:query("SELECT version FROM schema_migrations")) do
    applied[row.version] = true
  end

  local manifest = dofile(migrations_path .. "/manifest.lua")

  for _, version in ipairs(manifest) do
    if not applied[version] then
      local sql = read_file(migrations_path .. "/" .. version .. ".sql")

      database:transaction(function()
        database:execute_script(sql)
        database:execute(
          "INSERT INTO schema_migrations (version, applied_at) VALUES (?, ?)",
          { version, Clock.now_iso8601() }
        )
      end)
    end
  end
end

return Migrator
