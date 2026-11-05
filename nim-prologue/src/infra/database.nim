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
  result.exec(sql"PRAGMA busy_timeout=5000")
  result.exec(sql"PRAGMA journal_mode=WAL")
  result.createTables(Ticket())

proc db*(): DbConn =
  if connection.isNil:
    connection = openDatabase()
  connection
