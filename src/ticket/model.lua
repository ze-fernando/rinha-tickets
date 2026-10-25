local Database = require("src.infra.database")
local Status = require("src.ticket.status")

local TicketModel = {}

local COLUMNS = "id, title, description, sector, status, finished_at, created_at, updated_at"

function TicketModel.find_all(database)
  return database:query("SELECT " .. COLUMNS .. " FROM tickets ORDER BY created_at DESC, id DESC")
end

function TicketModel.find_open(database)
  return database:query(
    "SELECT " .. COLUMNS .. " FROM tickets WHERE status = ? ORDER BY created_at DESC, id DESC",
    { Status.OPEN }
  )
end

function TicketModel.find_by_id(database, ticket_id)
  return database:query("SELECT " .. COLUMNS .. " FROM tickets WHERE id = ?", { ticket_id })[1]
end

function TicketModel.find_id_by_title(database, title, ignore_ticket_id)
  if ignore_ticket_id ~= nil then
    return database:query(
      "SELECT id FROM tickets WHERE title = ? AND id <> ? LIMIT 1",
      { title, ignore_ticket_id }
    )[1]
  end

  return database:query("SELECT id FROM tickets WHERE title = ? LIMIT 1", { title })[1]
end

function TicketModel.insert(database, data, now)
  return database:insert(
    "INSERT INTO tickets (title, description, sector, status, finished_at, created_at, updated_at) "
      .. "VALUES (?, ?, ?, ?, NULL, ?, ?)",
    { data.title, data.description, data.sector, data.status, now, now }
  )
end

function TicketModel.update(database, ticket_id, data, finished_at, now)
  database:execute(
    "UPDATE tickets SET title = ?, description = ?, sector = ?, status = ?, finished_at = ?, updated_at = ? WHERE id = ?",
    {
      data.title,
      data.description,
      data.sector,
      data.status,
      finished_at or Database.NULL,
      now,
      ticket_id,
    }
  )
end

function TicketModel.finish(database, ticket_id, now)
  database:execute(
    "UPDATE tickets SET status = ?, finished_at = ?, updated_at = ? WHERE id = ?",
    { Status.CLOSED, now, now, ticket_id }
  )
end

return TicketModel
