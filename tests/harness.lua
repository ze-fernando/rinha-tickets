local Harness = {}
Harness.__index = Harness

function Harness.new()
  return setmetatable({ passed = 0, failed = 0, failures = {} }, Harness)
end

function Harness:run(suite_name, tests)
  for _, test in ipairs(tests) do
    local ok, failure = pcall(test.fn, self)

    if ok then
      self.passed = self.passed + 1
      io.write(string.format("  ok   %s > %s\n", suite_name, test.name))
    else
      self.failed = self.failed + 1
      self.failures[#self.failures + 1] = string.format("%s > %s: %s", suite_name, test.name, tostring(failure))
      io.write(string.format("  FAIL %s > %s\n", suite_name, test.name))
    end
  end
end

function Harness:equal(actual, expected, message)
  if actual ~= expected then
    error(
      string.format("%s (esperado: %s, recebido: %s)", message or "valores diferentes", tostring(expected), tostring(actual)),
      2
    )
  end
end

function Harness:truthy(value, message)
  if not value then
    error(message or "valor deveria ser verdadeiro", 2)
  end
end

function Harness:falsy(value, message)
  if value then
    error(message or "valor deveria ser falso", 2)
  end
end

function Harness:contains(list, expected, message)
  for _, value in ipairs(list or {}) do
    if value == expected then
      return
    end
  end

  error(string.format("%s (esperado conter: %s)", message or "item não encontrado", tostring(expected)), 2)
end

function Harness:matches(value, pattern, message)
  if type(value) ~= "string" or not value:match(pattern) then
    error(string.format("%s (valor: %s)", message or "valor não corresponde ao padrão", tostring(value)), 2)
  end
end

function Harness:error_status(callback, status, message)
  local ok, failure = pcall(callback)

  if ok then
    error(message or "era esperado um erro", 2)
  end

  if not (type(failure) == "table" and failure.__api_error == true) then
    error("erro não é uma ApiError: " .. tostring(failure), 2)
  end

  if status ~= nil and failure.status ~= status then
    error(
      string.format("%s (esperado status %d, recebido %s)", message or "status do erro diferente", status, tostring(failure.status)),
      2
    )
  end

  return failure
end

function Harness:summary()
  io.write(string.format("\n%d testes passaram, %d falharam\n", self.passed, self.failed))

  if self.failed > 0 then
    io.write("\nFalhas:\n")

    for _, failure in ipairs(self.failures) do
      io.write("  - " .. failure .. "\n")
    end

    return false
  end

  return true
end

return Harness
