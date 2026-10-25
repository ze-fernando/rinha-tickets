local function project_root()
  local script = arg[0] or "tests/run.lua"
  local root = script:match("^(.*)/tests/run%.lua$")

  if root == nil or root == "" then
    return "."
  end

  return root
end

local root = project_root()

package.path = root .. "/?.lua;" .. package.path

local Harness = require("tests.harness")

local harness = Harness.new()

local suites = {
  require("tests.json_test"),
  require("tests.dto_test"),
  require("tests.service_test"),
  require("tests.app_test"),
}

for _, suite in ipairs(suites) do
  harness:run(suite.name, suite.tests)
end

os.exit(harness:summary() and 0 or 1)
