import std/[json, options, unittest]
import ticket/[errors, models, schemas]

suite "ticket input":
  test "accepts required fields and defaults status":
    let outcome = parseTicketInput(
      """{"title":"Impressora","description":"Sem rede","sector":"Recepção"}"""
    )
    check outcome.ok
    check outcome.value.title == "Impressora"
    check outcome.value.description == "Sem rede"
    check outcome.value.sector == "Recepção"
    check outcome.value.status == "open"

  test "accepts every allowed status":
    for status in allowedStatuses:
      let outcome = parseTicketInput(
        """{"title":"A","description":"B","sector":"C","status":"""" &
          status & """"}"""
      )
      check outcome.ok
      check outcome.value.status == status

  test "keeps empty strings as valid values":
    let outcome = parseTicketInput(
      """{"title":"","description":"","sector":""}"""
    )
    check outcome.ok
    check outcome.value.title.len == 0

  test "ignores unknown fields":
    let outcome = parseTicketInput(
      """{"title":"A","description":"B","sector":"C","extra":true}"""
    )
    check outcome.ok

  test "rejects invalid json":
    let outcome = parseTicketInput("{")
    check not outcome.ok
    check outcome.failure == fInvalid
    check outcome.message == "JSON decode error"

  test "rejects non object bodies":
    for body in ["", "null", "[]", "42", "true"]:
      let outcome = parseTicketInput(body)
      check not outcome.ok
      check outcome.failure == fInvalid

  test "rejects missing fields":
    for body in [
      """{"description":"B","sector":"C"}""",
      """{"title":"A","sector":"C"}""",
      """{"title":"A","description":"B"}"""
    ]:
      let outcome = parseTicketInput(body)
      check not outcome.ok
      check outcome.failure == fInvalid
      check outcome.message == "Field required"

  test "rejects non string fields":
    for body in [
      """{"title":1,"description":"B","sector":"C"}""",
      """{"title":null,"description":"B","sector":"C"}""",
      """{"title":"A","description":[],"sector":"C"}"""
    ]:
      let outcome = parseTicketInput(body)
      check not outcome.ok
      check outcome.message == "Input should be a valid string"

  test "rejects invalid status":
    for status in ["", "OPEN", "done", "closed "] :
      let outcome = parseTicketInput(
        """{"title":"A","description":"B","sector":"C","status":"""" &
          status & """"}"""
      )
      check not outcome.ok
      check outcome.message ==
        "Input should be 'open', 'in_progress' or 'closed'"

  test "rejects null status":
    let outcome = parseTicketInput(
      """{"title":"A","description":"B","sector":"C","status":null}"""
    )
    check not outcome.ok
    check outcome.message == "Input should be a valid string"

suite "path id":
  test "accepts decimal ids":
    check parseId("0") == some(0'i64)
    check parseId("1") == some(1'i64)
    check parseId("9223372036854775807") == some(int64.high)

  test "rejects everything else":
    for raw in ["", "-1", "+1", "1.5", " 1", "1 ", "abc", "1e3"]:
      check parseId(raw).isNone

  test "rejects overflow":
    check parseId("9223372036854775808").isNone

suite "ticket serialization":
  test "serializes an open ticket":
    let ticket = Ticket(
      title: "A",
      description: "B",
      sector: "C",
      status: "open",
      finishedAt: none(string),
      createdAt: "2026-10-29T12:00:00"
    )
    let payload = ticket.toJson
    check payload["id"].getInt == 0
    check payload["finished_at"].kind == JNull
    check payload["created_at"].getStr == "2026-10-29T12:00:00"
    check not payload.hasKey("updated_at")

  test "serializes a finished ticket":
    let ticket = Ticket(
      title: "A",
      description: "B",
      sector: "C",
      status: "closed",
      finishedAt: some("2026-10-29T13:00:00"),
      createdAt: "2026-10-29T12:00:00"
    )
    check ticket.toJson["finished_at"].getStr == "2026-10-29T13:00:00"

  test "wraps lists in data":
    let payload = newSeq[Ticket]().toJson
    check payload["data"].kind == JArray
    check payload["data"].len == 0

suite "timestamps":
  test "uses the contract shape":
    let value = timestamp()
    check value.len == 19
    check value[4] == '-'
    check value[7] == '-'
    check value[10] == 'T'
    check value[13] == ':'
    check value[16] == ':'
