import std/[os, strutils]
import norm/sqlite
import ../ticket/models

const defaultDatabasePath = "database.sqlite"

var connection {.threadvar.}: DbConn

proc databasePath*(): string =
  let configured = getEnv("DATABASE_PATH")
  if configured.len > 0: configured else: defaultDatabasePath

proc openDatabase(): DbConn =
  result = open(databasePath(), "", "", "")
  try:
    result.exec(sql"PRAGMA busy_timeout=5000")
  except CatchableError:
    result.close()
    raise

proc db*(): DbConn =
  if connection.isNil:
    connection = openDatabase()
  connection

proc closeDatabase*() =
  if not connection.isNil:
    connection.close()
    connection = nil

proc initDatabase*() =
  let database = openDatabase()
  try:
    database.exec(sql"PRAGMA journal_mode=WAL")
    database.createTables(Ticket())
  finally:
    database.close()
