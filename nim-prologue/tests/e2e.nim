import std/[httpclient, json, net, os, osproc, strutils, unittest]

let projectRoot = getCurrentDir()
let binary = projectRoot / "ticket"

proc freePort(): Port =
  let socket = newSocket()
  defer: socket.close()
  socket.bindAddr(Port(0), "127.0.0.1")
  let (_, port) = socket.getLocalAddr()
  port

let port = freePort()
let baseUrl = "http://127.0.0.1:" & $port
let databaseFile = getTempDir() / "ticket-e2e-" & $getCurrentProcessId() & ".sqlite"

proc cleanup() =
  for suffix in ["", "-wal", "-shm"]:
    removeFile(databaseFile & suffix)

proc waitForServer(client: HttpClient): bool =
  for attempt in 0..<100:
    try:
      if client.get(baseUrl & "/api/tickets/all").code == Http200:
        return true
    except CatchableError:
      discard
    sleep(100)
  false

proc send(
  client: HttpClient,
  verb: HttpMethod,
  path: string,
  body = ""
): Response =
  if body.len == 0:
    client.request(baseUrl & path, httpMethod = verb)
  else:
    client.request(
      baseUrl & path,
      httpMethod = verb,
      body = body,
      headers = newHttpHeaders({"Content-Type": "application/json"})
    )

proc payload(response: Response): JsonNode =
  parseJson(response.body)

cleanup()
putEnv("PORT", $port)
putEnv("DATABASE_PATH", databaseFile)

suite "http api":
  test "runs the full ticket lifecycle":
    require fileExists(binary)

    let process = startProcess(
      binary,
      workingDir = projectRoot,
      options = {poUsePath}
    )

    defer:
      process.terminate()
      if process.waitForExit(2000) == -1:
        process.kill()
        discard process.waitForExit(2000)
      process.close()
      cleanup()

    let client = newHttpClient(timeout = 5000)
    defer: client.close()

    check client.waitForServer()

    let createBody = """{"title":"Impressora","description":"Sem rede","sector":"Recepção"}"""
    let created = client.send(HttpPost, "/api/tickets/create", createBody)
    check created.code == Http201
    let createdPayload = created.payload
    check createdPayload["status"].getStr == "open"
    check createdPayload["finished_at"].kind == JNull
    check createdPayload["created_at"].getStr.len == 19
    check not createdPayload.hasKey("updated_at")
    let ticketId = createdPayload["id"].getInt
    let ticketPath = "/api/tickets/" & $ticketId

    let duplicated = client.send(HttpPost, "/api/tickets/create", createBody)
    check duplicated.code == Http409
    check duplicated.payload["detail"].getStr == "Chamado já em aberto"

    let allTickets = client.send(HttpGet, "/api/tickets/all")
    check allTickets.code == Http200
    check allTickets.payload["data"].len == 1

    let openTickets = client.send(HttpGet, "/api/tickets/open")
    check openTickets.code == Http200
    check openTickets.payload["data"].len == 1

    let found = client.send(HttpGet, ticketPath)
    check found.code == Http200
    check found.payload["title"].getStr == "Impressora"

    let missing = client.send(HttpGet, "/api/tickets/999999")
    check missing.code == Http404
    check missing.payload["detail"].getStr == "Chamado não existe"

    let malformed = client.send(HttpGet, "/api/tickets/abc")
    check malformed.code == Http404
    check malformed.payload["detail"].getStr == "Not Found"

    let malformedUpdate = client.send(HttpPut, "/api/tickets/abc/update", createBody)
    check malformedUpdate.code == Http404
    check malformedUpdate.payload["detail"].getStr == "Not Found"

    let malformedFinish = client.send(HttpPut, "/api/tickets/abc/finish")
    check malformedFinish.code == Http404
    check malformedFinish.payload["detail"].getStr == "Not Found"

    let overflowing = client.send(HttpGet, "/api/tickets/9223372036854775808")
    check overflowing.code == Http404
    check overflowing.payload["detail"].getStr == "Chamado não existe"

    let updateBody =
      """{"title":"Impressora","description":"Em análise","sector":"Recepção","status":"in_progress"}"""
    let updated = client.send(HttpPut, ticketPath & "/update", updateBody)
    check updated.code == Http200
    check updated.payload["status"].getStr == "in_progress"

    let noOpenTickets = client.send(HttpGet, "/api/tickets/open")
    check noOpenTickets.payload["data"].len == 0

    let finished = client.send(HttpPut, ticketPath & "/finish")
    check finished.code == Http200
    check finished.payload["status"].getStr == "closed"
    check finished.payload["finished_at"].kind == JString

    let reopenedBody =
      """{"title":"Impressora","description":"Voltou","sector":"Recepção"}"""
    let reopened = client.send(HttpPut, ticketPath & "/update", reopenedBody)
    check reopened.code == Http200
    check reopened.payload["status"].getStr == "open"
    check reopened.payload["finished_at"].kind == JNull

    let invalidBody = client.send(HttpPost, "/api/tickets/create", "{}")
    check invalidBody.code == Http422
    check invalidBody.payload["detail"].getStr == "Field required"

    let invalidStatus = client.send(
      HttpPost,
      "/api/tickets/create",
      """{"title":"A","description":"B","sector":"C","status":"done"}"""
    )
    check invalidStatus.code == Http422

    let unknownRoute = client.send(HttpGet, "/api/unknown")
    check unknownRoute.code == Http404
    check unknownRoute.payload["detail"].getStr == "Not Found"

    let other = client.send(
      HttpPost,
      "/api/tickets/create",
      """{"title":"Monitor","description":"Sem sinal","sector":"TI"}"""
    )
    check other.code == Http201

    let duplicateUpdate = client.send(
      HttpPut,
      ticketPath & "/update",
      """{"title":"Monitor","description":"Sem sinal","sector":"TI","status":"open"}"""
    )
    check duplicateUpdate.code == Http409
    check duplicateUpdate.payload["detail"].getStr == "Chamado já em aberto"
