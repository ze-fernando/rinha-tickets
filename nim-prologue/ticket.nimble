import std/tables

version = "0.1.0"
author = "ze-fernando"
description = "Ticket API with Nim, Prologue and Norm"
license = "MIT"
srcDir = "src"
namedBin = {"main": "ticket"}.toTable

requires "nim >= 2.2.0", "prologue >= 0.6.8", "norm >= 2.8.7"

task test, "Run unit, integration and end-to-end tests":
  exec "nimble build -y"
  exec "nim c -r --hints:off tests/unit.nim"
  exec "nim c -r --hints:off tests/integration.nim"
  exec "nim c -r --hints:off tests/e2e.nim"
