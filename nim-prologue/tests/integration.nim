import std/[options, os, unittest]
import norm/sqlite
import ticket/[errors, models, schemas, service]
import infra/database

let databaseFile =
  getTempDir() / "ticket-integration-" & $getCurrentProcessId() & ".sqlite"

proc cleanup() =
  for suffix in ["", "-wal", "-shm"]:
    removeFile(databaseFile & suffix)

cleanup()
putEnv("DATABASE_PATH", databaseFile)
initDatabase()

suite "ticket service":
  test "starts with empty lists":
    check service.getAll().len == 0
    check service.getOpen().len == 0

  test "creates a ticket":
    let outcome = service.create(
      TicketInput(
        title: "Teclado quebrado",
        description: "Algumas teclas não funcionam",
        sector: "Financeiro",
        status: "open"
      )
    )
    check outcome.ok
    check outcome.value.id > 0
    check outcome.value.finishedAt.isNone
    check outcome.value.createdAt.len == 19

  test "reads a ticket by id":
    let outcome = service.getById(1)
    check outcome.ok
    check outcome.value.title == "Teclado quebrado"
    check outcome.value.status == "open"

  test "returns not found for a missing id":
    check service.getById(999999).failure == fNotFound
    check service.update(
      999999,
      TicketInput(title: "A", description: "B", sector: "C", status: "open")
    ).failure == fNotFound
    check service.finish(999999).failure == fNotFound

  test "rejects duplicated titles":
    let outcome = service.create(
      TicketInput(
        title: "Teclado quebrado",
        description: "Outro problema",
        sector: "TI",
        status: "open"
      )
    )
    check not outcome.ok
    check outcome.failure == fConflict

  test "lists open tickets":
    let openTickets = service.getOpen()
    check openTickets.len == 1
    check openTickets[0].title == "Teclado quebrado"

  test "moves a ticket to in progress":
    let outcome = service.update(
      1,
      TicketInput(
        title: "Teclado quebrado",
        description: "Trocando o teclado",
        sector: "Financeiro",
        status: "in_progress"
      )
    )
    check outcome.ok
    check outcome.value.status == "in_progress"
    check outcome.value.finishedAt.isNone
    check service.getOpen().len == 0

  test "finishes a ticket and replaces the finish date":
    let first = service.finish(1)
    check first.ok
    check first.value.status == "closed"
    check first.value.finishedAt.isSome

    let firstDate = first.value.finishedAt.get
    sleep(1100)

    let second = service.finish(1)
    check second.ok
    check second.value.finishedAt.get != firstDate

  test "preserves the finish date when updating to closed":
    let created = service.create(
      TicketInput(
        title: "Monitor sem sinal",
        description: "Cabo desconectado",
        sector: "Recepção",
        status: "open"
      )
    )
    check created.ok

    let closed = service.update(
      created.value.id,
      TicketInput(
        title: "Monitor sem sinal",
        description: "Cabo desconectado",
        sector: "Recepção",
        status: "closed"
      )
    )
    check closed.ok
    let closedDate = closed.value.finishedAt.get

    sleep(1100)

    let again = service.update(
      created.value.id,
      TicketInput(
        title: "Monitor sem sinal",
        description: "Cabo desconectado",
        sector: "Recepção",
        status: "closed"
      )
    )
    check again.ok
    check again.value.finishedAt.get == closedDate

  test "reopens a ticket and clears the finish date":
    let outcome = service.update(
      1,
      TicketInput(
        title: "Teclado quebrado",
        description: "Voltou a falhar",
        sector: "Financeiro",
        status: "open"
      )
    )
    check outcome.ok
    check outcome.value.finishedAt.isNone
    check service.getOpen().len == 1

  test "rejects a title already used by another ticket":
    let outcome = service.create(
      TicketInput(
        title: "Impressora travada",
        description: "Fila parada",
        sector: "Recepção",
        status: "open"
      )
    )
    check outcome.ok

    let conflict = service.update(
      outcome.value.id,
      TicketInput(
        title: "Teclado quebrado",
        description: "Fila parada",
        sector: "Recepção",
        status: "open"
      )
    )
    check not conflict.ok
    check conflict.failure == fConflict

    let unchanged = service.getById(outcome.value.id)
    check unchanged.ok
    check unchanged.value.title == "Impressora travada"

  test "keeps data after opening the database again":
    let direct = open(databaseFile, "", "", "")
    try:
      let stored = direct.select(Ticket, "id = ?", 1)
      check stored.len == 1
      check stored[0].title == "Teclado quebrado"
    finally:
      direct.close()

  test "exposes every ticket in the full list":
    check service.getAll().len == 3

  test "creates a closed ticket without a finish date":
    let outcome = service.create(
      TicketInput(
        title: "Projeto encerrado",
        description: "Aberto antes do sistema",
        sector: "Diretoria",
        status: "closed"
      )
    )
    check outcome.ok
    check outcome.value.status == "closed"
    check outcome.value.finishedAt.isNone

closeDatabase()
cleanup()
