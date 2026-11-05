import std/options
import norm/[model, pragmas]

const allowedStatuses* = ["open", "in_progress", "closed"]

type
  Ticket* {.tableName: "tickets".} = ref object of Model
    title* {.unique.}: string
    description*: string
    sector*: string
    status*: string
    finishedAt*: Option[string]
    createdAt*: string
    updatedAt*: string

proc isValidStatus*(status: string): bool =
  status in allowedStatuses
