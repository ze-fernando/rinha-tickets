local json = {}

json.null = setmetatable({}, { __tostring = function() return "null" end })

local array_metatable = {}

function json.array(items)
  return setmetatable(items or {}, array_metatable)
end

function json.is_array(value)
  return getmetatable(value) == array_metatable
end

function json.is_null(value)
  return value == json.null
end

local string_escapes = {
  ['"'] = '\\"',
  ["\\"] = "\\\\",
  ["\b"] = "\\b",
  ["\f"] = "\\f",
  ["\n"] = "\\n",
  ["\r"] = "\\r",
  ["\t"] = "\\t",
}

local function encode_string(value)
  local encoded = value:gsub('[%z\1-\31\\"]', function(character)
    local escaped = string_escapes[character]

    if escaped then
      return escaped
    end

    return string.format("\\u%04x", character:byte())
  end)

  return '"' .. encoded .. '"'
end

local function encode_number(value)
  if value ~= value or value == math.huge or value == -math.huge then
    error("Não é possível codificar um número inválido", 0)
  end

  if value % 1 == 0 and math.abs(value) < 1e15 then
    return string.format("%d", value)
  end

  return string.format("%.14g", value)
end

local function is_sequence(value)
  local count = 0

  for key in pairs(value) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 then
      return false
    end

    count = count + 1
  end

  for index = 1, count do
    if value[index] == nil then
      return false
    end
  end

  return count > 0
end

local encode_value

local function encode_table(value, depth, seen)
  if depth > 64 then
    error("Estrutura JSON muito profunda", 0)
  end

  if seen[value] then
    error("Não é possível codificar uma estrutura circular", 0)
  end

  seen[value] = true

  local result

  if json.is_array(value) or is_sequence(value) then
    local items = {}

    for index = 1, #value do
      items[index] = encode_value(value[index], depth + 1, seen)
    end

    result = "[" .. table.concat(items, ",") .. "]"
  else
    local entries = {}

    for key in pairs(value) do
      if type(key) == "string" then
        entries[#entries + 1] = { name = key, value = value[key] }
      elseif type(key) == "number" then
        entries[#entries + 1] = { name = tostring(key), value = value[key] }
      else
        error("Chave JSON não suportada: " .. type(key), 0)
      end
    end

    table.sort(entries, function(left, right) return left.name < right.name end)

    local items = {}

    for _, entry in ipairs(entries) do
      items[#items + 1] = encode_string(entry.name) .. ":" .. encode_value(entry.value, depth + 1, seen)
    end

    result = "{" .. table.concat(items, ",") .. "}"
  end

  seen[value] = nil

  return result
end

encode_value = function(value, depth, seen)
  if value == json.null then
    return "null"
  end

  local kind = type(value)

  if kind == "nil" then
    return "null"
  end

  if kind == "boolean" then
    return value and "true" or "false"
  end

  if kind == "number" then
    return encode_number(value)
  end

  if kind == "string" then
    return encode_string(value)
  end

  if kind == "table" then
    return encode_table(value, depth, seen)
  end

  error("Tipo JSON não suportado: " .. kind, 0)
end

function json.encode(value)
  return encode_value(value, 0, {})
end

local function utf8_character(codepoint)
  if codepoint < 0x80 then
    return string.char(codepoint)
  end

  if codepoint < 0x800 then
    return string.char(0xC0 + math.floor(codepoint / 0x40), 0x80 + codepoint % 0x40)
  end

  if codepoint < 0x10000 then
    return string.char(
      0xE0 + math.floor(codepoint / 0x1000),
      0x80 + math.floor(codepoint / 0x40) % 0x40,
      0x80 + codepoint % 0x40
    )
  end

  return string.char(
    0xF0 + math.floor(codepoint / 0x40000),
    0x80 + math.floor(codepoint / 0x1000) % 0x40,
    0x80 + math.floor(codepoint / 0x40) % 0x40,
    0x80 + codepoint % 0x40
  )
end

local function decode(input)
  if type(input) ~= "string" then
    error("JSON inválido: a entrada deve ser um texto", 0)
  end

  local position = 1
  local length = #input

  local function skip_whitespace()
    local _, finish = input:find("^[ \t\r\n]*", position)

    position = finish + 1
  end

  local function fail(message)
    error("JSON inválido: " .. message .. " (posição " .. position .. ")", 0)
  end

  local function parse_string()
    position = position + 1

    local chunks = {}

    while true do
      if position > length then
        fail("texto não terminado")
      end

      local character = input:sub(position, position)

      if character == '"' then
        position = position + 1
        break
      end

      if character == "\\" then
        local escape = input:sub(position + 1, position + 1)
        local replacements = {
          ['"'] = '"',
          ["\\"] = "\\",
          ["/"] = "/",
          b = "\b",
          f = "\f",
          n = "\n",
          r = "\r",
          t = "\t",
        }

        if replacements[escape] then
          chunks[#chunks + 1] = replacements[escape]
          position = position + 2
        elseif escape == "u" then
          local hex = input:sub(position + 2, position + 5)

          if #hex ~= 4 or not hex:match("^%x%x%x%x$") then
            fail("escape unicode inválido")
          end

          local codepoint = tonumber(hex, 16)
          position = position + 6

          if codepoint >= 0xD800 and codepoint <= 0xDBFF then
            local low_hex = input:sub(position + 2, position + 5)

            if input:sub(position, position + 1) ~= "\\u" or #low_hex ~= 4 or not low_hex:match("^%x%x%x%x$") then
              fail("par surrogate inválido")
            end

            local low = tonumber(low_hex, 16)

            if low < 0xDC00 or low > 0xDFFF then
              fail("par surrogate inválido")
            end

            codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + (low - 0xDC00)
            position = position + 6
          end

          chunks[#chunks + 1] = utf8_character(codepoint)
        else
          fail("escape desconhecido")
        end
      elseif character:byte() < 32 then
        fail("caractere de controle não escapado")
      else
        chunks[#chunks + 1] = character
        position = position + 1
      end
    end

    return table.concat(chunks)
  end

  local parse_value

  local function parse_object()
    position = position + 1

    local object = {}

    skip_whitespace()

    if input:sub(position, position) == "}" then
      position = position + 1
      return object
    end

    while true do
      skip_whitespace()

      if input:sub(position, position) ~= '"' then
        fail("chave esperada")
      end

      local key = parse_string()

      skip_whitespace()

      if input:sub(position, position) ~= ":" then
        fail("':' esperado")
      end

      position = position + 1
      object[key] = parse_value()
      skip_whitespace()

      local character = input:sub(position, position)

      if character == "," then
        position = position + 1
      elseif character == "}" then
        position = position + 1
        return object
      else
        fail("'}' esperado")
      end
    end
  end

  local function parse_array()
    position = position + 1

    local items = json.array({})

    skip_whitespace()

    if input:sub(position, position) == "]" then
      position = position + 1
      return items
    end

    while true do
      items[#items + 1] = parse_value()
      skip_whitespace()

      local character = input:sub(position, position)

      if character == "," then
        position = position + 1
      elseif character == "]" then
        position = position + 1
        return items
      else
        fail("']' esperado")
      end
    end
  end

  local function parse_number()
    local number = input:match("^-?%d+%.%d+[eE][-+]?%d+", position)
      or input:match("^-?%d+%.%d+", position)
      or input:match("^-?%d+[eE][-+]?%d+", position)
      or input:match("^-?%d+", position)

    if not number then
      fail("número esperado")
    end

    position = position + #number

    return tonumber(number)
  end

  parse_value = function()
    skip_whitespace()

    local character = input:sub(position, position)

    if character == "{" then
      return parse_object()
    end

    if character == "[" then
      return parse_array()
    end

    if character == '"' then
      return parse_string()
    end

    if character == "t" then
      if input:sub(position, position + 3) ~= "true" then
        fail("valor esperado")
      end

      position = position + 4
      return true
    end

    if character == "f" then
      if input:sub(position, position + 4) ~= "false" then
        fail("valor esperado")
      end

      position = position + 5
      return false
    end

    if character == "n" then
      if input:sub(position, position + 3) ~= "null" then
        fail("valor esperado")
      end

      position = position + 4
      return json.null
    end

    return parse_number()
  end

  local value = parse_value()

  skip_whitespace()

  if position <= length then
    fail("conteúdo extra ao final")
  end

  return value
end

json.decode = decode

return json
