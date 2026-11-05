type
  Failure* = enum
    fNone
    fNotFound
    fConflict
    fInvalid
    fInternal

  Outcome*[T] = object
    case ok*: bool
    of true:
      value*: T
    else:
      failure*: Failure
      message*: string

proc success*[T](value: T): Outcome[T] =
  Outcome[T](ok: true, value: value)

proc failed*[T](failure: Failure, message = ""): Outcome[T] =
  Outcome[T](ok: false, failure: failure, message: message)
