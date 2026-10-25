local Status = {
  OPEN = "open",
  IN_PROGRESS = "in_progress",
  CLOSED = "closed",
}

Status.ALL = {
  [Status.OPEN] = true,
  [Status.IN_PROGRESS] = true,
  [Status.CLOSED] = true,
}

function Status.valid(value)
  return Status.ALL[value] == true
end

return Status
