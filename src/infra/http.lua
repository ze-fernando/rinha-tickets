local bindings = require("src.infra.ffi")
local json = require("src.infra.json")

local ffi = bindings.ffi
local C = bindings.C

local Http = {}

local AF_INET = 2
local SOCK_STREAM = 1
local SOL_SOCKET = 1
local SO_REUSEADDR = 2
local SO_RCVTIMEO = 20
local SIGPIPE = 13
local SIG_IGN = 1
local MAX_HEADER_BYTES = 65536
local MAX_BODY_BYTES = 1048576
local READ_CHUNK = 4096

local reasons = {
  [200] = "OK",
  [201] = "Created",
  [400] = "Bad Request",
  [404] = "Not Found",
  [409] = "Conflict",
  [413] = "Payload Too Large",
  [422] = "Unprocessable Entity",
  [500] = "Internal Server Error",
}

local function ignore_sigpipe()
  C.signal(SIGPIPE, ffi.cast("void (*)(int)", SIG_IGN))
end

local function create_socket(host, port)
  local server = C.socket(AF_INET, SOCK_STREAM, 0)

  if server < 0 then
    error("Não foi possível criar o socket do servidor", 0)
  end

  local reuse = ffi.new("int[1]", 1)

  C.setsockopt(server, SOL_SOCKET, SO_REUSEADDR, reuse, ffi.sizeof("int"))

  local address = ffi.new("struct sockaddr_in")
  address.sin_family = AF_INET
  address.sin_port = C.htons(port)
  address.sin_addr.s_addr = C.inet_addr(host)

  if C.bind(server, ffi.cast("const struct sockaddr *", address), ffi.sizeof(address)) ~= 0 then
    C.close(server)
    error("Não foi possível vincular o servidor a " .. host .. ":" .. tostring(port), 0)
  end

  if C.listen(server, 128) ~= 0 then
    C.close(server)
    error("Não foi possível iniciar o servidor na porta " .. tostring(port), 0)
  end

  return server
end

local function set_read_timeout(client)
  local timeout = ffi.new("struct timeval")
  timeout.tv_sec = 5
  timeout.tv_usec = 0

  C.setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, timeout, ffi.sizeof(timeout))
end

local function read_chunk(client, buffer)
  local received = C.read(client, buffer, READ_CHUNK)

  if received <= 0 then
    return nil
  end

  return ffi.string(buffer, received)
end

local function read_request(client)
  local buffer = ffi.new("char[?]", READ_CHUNK)
  local raw = read_chunk(client, buffer)

  if raw == nil then
    return nil
  end

  while not raw:find("\r\n\r\n", 1, true) do
    if #raw > MAX_HEADER_BYTES then
      return nil, "cabeçalho muito grande"
    end

    local chunk = read_chunk(client, buffer)

    if chunk == nil then
      return nil, "conexão encerrada antes do fim do cabeçalho"
    end

    raw = raw .. chunk
  end

  local header_end = raw:find("\r\n\r\n", 1, true)
  local header_block = raw:sub(1, header_end - 1)
  local body = raw:sub(header_end + 4)

  local lines = {}

  for line in header_block:gmatch("[^\r\n]+") do
    lines[#lines + 1] = line
  end

  local request_line = lines[1]

  if request_line == nil then
    return nil, "requisição vazia"
  end

  local method, target = request_line:match("^(%u+)%s+(%S+)%s+HTTP/%d%.%d$")

  if method == nil then
    return nil, "linha de requisição inválida"
  end

  local headers = {}

  for index = 2, #lines do
    local name, value = lines[index]:match("^([^:]+):%s*(.*)$")

    if name then
      headers[name:lower()] = value
    end
  end

  local content_length = tonumber(headers["content-length"] or "0") or 0

  if content_length > MAX_BODY_BYTES then
    return nil, "corpo muito grande"
  end

  while #body < content_length do
    local chunk = read_chunk(client, buffer)

    if chunk == nil then
      return nil, "corpo incompleto"
    end

    body = body .. chunk
  end

  body = body:sub(1, content_length)

  local path
  local query = ""

  do
    local raw_path, raw_query = target:match("^([^?]*)%??(.*)$")

    path = raw_path or target
    query = raw_query or ""
  end

  return {
    method = method,
    path = path,
    query = query,
    headers = headers,
    body = body,
  }
end

local function encode_payload(payload)
  local ok, body = pcall(json.encode, payload)

  if ok then
    return body
  end

  return '{"code":"INTERNAL_ERROR","message":"Erro interno do servidor."}'
end

local function send_response(client, status, payload)
  local body = encode_payload(payload)
  local head = table.concat({
    "HTTP/1.1 " .. status .. " " .. (reasons[status] or "OK"),
    "Content-Type: application/json; charset=utf-8",
    "Content-Length: " .. #body,
    "Connection: close",
    "",
    "",
  }, "\r\n")

  local response = head .. body
  local sent = 0

  while sent < #response do
    local written = C.write(client, response:sub(sent + 1), #response - sent)

    if written <= 0 then
      break
    end

    sent = sent + written
  end
end

local function handle_connection(client, handler)
  local request, message = read_request(client)

  if request == nil then
    if message then
      send_response(client, 400, { code = "BAD_REQUEST", message = "Requisição inválida." })
    end

    return
  end

  local ok, status, payload = pcall(handler, request)

  if not ok then
    io.stderr:write("erro ao processar requisição: " .. tostring(status) .. "\n")
    status = 500
    payload = { code = "INTERNAL_ERROR", message = "Erro interno do servidor." }
  end

  send_response(client, status, payload)
end

function Http.serve(options, handler)
  ignore_sigpipe()

  local server = create_socket(options.host, options.port)

  io.write("Servidor rodando em http://" .. options.host .. ":" .. tostring(options.port) .. "\n")
  io.flush()

  while true do
    local client = C.accept(server, nil, nil)

    if client >= 0 then
      set_read_timeout(client)
      pcall(handle_connection, client, handler)
      C.close(client)
    end
  end
end

return Http
