local function project_root()
  local script = arg[0] or "src/main.lua"
  local root = script:match("^(.*)/src/main%.lua$")

  if root == nil or root == "" then
    return "."
  end

  return root
end

local root = project_root()

package.path = root .. "/?.lua;" .. package.path

local App = require("src.app")
local Config = require("src.config")
local Database = require("src.infra.database")
local Http = require("src.infra.http")
local Migrator = require("src.infra.migrator")

local database = Database.open(Config.database_path)

Migrator.run(database, Config.migrations_path)

local app = App.new(database)

Http.serve({ host = Config.host, port = Config.port }, function(request)
  return app:handle(request)
end)
