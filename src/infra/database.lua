local bindings = require("src.infra.ffi")

local ffi = bindings.ffi
local sqlite = bindings.sqlite

local Database = {}
Database.__index = Database
Database.NULL = setmetatable({}, { __tostring = function() return "NULL" end })

local SQLITE_OK = 0
local SQLITE_ROW = 100
local SQLITE_DONE = 101
local SQLITE_INTEGER = 1
local SQLITE_FLOAT = 2
local SQLITE_TEXT = 3
local SQLITE_BLOB = 4
local SQLITE_NULL = 5
local SQLITE_TRANSIENT = ffi.cast("void (*)(void *)", -1)

local function new_error(code, message)
  return { __database_error = true, code = code, message = message }
end

function Database:_raise()
  local message = ffi.string(sqlite.sqlite3_errmsg(self.handle))
  local code = sqlite.sqlite3_extended_errcode(self.handle)

  error(new_error(code, message), 0)
end

function Database:_prepare(sql)
  local statement = ffi.new("sqlite3_stmt*[1]")
  local result = sqlite.sqlite3_prepare_v2(self.handle, sql, -1, statement, nil)

  if result ~= SQLITE_OK then
    self:_raise()
  end

  return statement[0]
end

function Database:_bind(statement, params)
  if not params then
    return
  end

  for index = 1, #params do
    local value = params[index]
    local result

    if value == nil or value == Database.NULL then
      result = sqlite.sqlite3_bind_null(statement, index)
    elseif type(value) == "number" then
      result = sqlite.sqlite3_bind_int64(statement, index, value)
    elseif type(value) == "string" then
      result = sqlite.sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    elseif type(value) == "boolean" then
      result = sqlite.sqlite3_bind_int64(statement, index, value and 1 or 0)
    else
      error("Tipo de parâmetro não suportado: " .. type(value), 0)
    end

    if result ~= SQLITE_OK then
      sqlite.sqlite3_finalize(statement)
      self:_raise()
    end
  end
end

function Database:_row(statement)
  local row = {}
  local columns = sqlite.sqlite3_column_count(statement)

  for column = 0, columns - 1 do
    local name = ffi.string(sqlite.sqlite3_column_name(statement, column))
    local kind = sqlite.sqlite3_column_type(statement, column)

    if kind == SQLITE_INTEGER then
      row[name] = tonumber(sqlite.sqlite3_column_int64(statement, column))
    elseif kind == SQLITE_FLOAT then
      row[name] = sqlite.sqlite3_column_double(statement, column)
    elseif kind == SQLITE_TEXT then
      row[name] = ffi.string(sqlite.sqlite3_column_text(statement, column))
    elseif kind == SQLITE_BLOB then
      row[name] = ffi.string(sqlite.sqlite3_column_text(statement, column), sqlite.sqlite3_column_bytes(statement, column))
    end
  end

  return row
end

function Database:query(sql, params)
  local statement = self:_prepare(sql)
  self:_bind(statement, params)

  local rows = {}

  while true do
    local result = sqlite.sqlite3_step(statement)

    if result == SQLITE_ROW then
      rows[#rows + 1] = self:_row(statement)
    elseif result == SQLITE_DONE then
      break
    else
      sqlite.sqlite3_finalize(statement)
      self:_raise()
    end
  end

  sqlite.sqlite3_finalize(statement)

  return rows
end

function Database:execute(sql, params)
  local statement = self:_prepare(sql)
  self:_bind(statement, params)

  local result

  repeat
    result = sqlite.sqlite3_step(statement)
  until result ~= SQLITE_ROW

  sqlite.sqlite3_finalize(statement)

  if result ~= SQLITE_DONE then
    self:_raise()
  end
end

function Database:insert(sql, params)
  self:execute(sql, params)

  return tonumber(sqlite.sqlite3_last_insert_rowid(self.handle))
end

function Database:execute_script(sql)
  local error_message = ffi.new("char*[1]")
  local result = sqlite.sqlite3_exec(self.handle, sql, nil, nil, error_message)

  if result ~= SQLITE_OK then
    local message = ffi.string(sqlite.sqlite3_errmsg(self.handle))

    if error_message[0] ~= nil then
      message = ffi.string(error_message[0])
      sqlite.sqlite3_free(error_message[0])
    end

    error(new_error(result, message), 0)
  end
end

function Database:transaction(callback)
  self:execute("BEGIN IMMEDIATE")

  local ok, result = pcall(callback)

  if not ok then
    pcall(function() self:execute("ROLLBACK") end)
    error(result, 0)
  end

  local committed, commit_error = pcall(function() self:execute("COMMIT") end)

  if not committed then
    pcall(function() self:execute("ROLLBACK") end)
    error(commit_error, 0)
  end

  return result
end

function Database:close()
  if self.handle ~= nil then
    sqlite.sqlite3_close(self.handle)
    self.handle = nil
  end
end

local function open(path)
  local handle = ffi.new("sqlite3*[1]")
  local result = sqlite.sqlite3_open(path, handle)

  if result ~= SQLITE_OK then
    local message = "não foi possível abrir o banco de dados"

    if handle[0] ~= nil then
      message = ffi.string(sqlite.sqlite3_errmsg(handle[0]))
      sqlite.sqlite3_close(handle[0])
    end

    error("Erro ao abrir o banco de dados: " .. message, 0)
  end

  local self = setmetatable({ handle = handle[0] }, Database)

  sqlite.sqlite3_busy_timeout(self.handle, 5000)
  self:execute("PRAGMA journal_mode = WAL")
  self:execute("PRAGMA foreign_keys = ON")

  return self
end

Database.open = open

return Database
