#!/usr/bin/env bash
set -u

BASE_URL="${BASE_URL:-http://localhost:8000}"
TITLE="${TITLE:-Impressora $(date +%s)-$$}"
DESCRIPTION="A impressora da recepção não aparece na rede."
SECTOR="Recepção"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl não encontrado no PATH." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
response_file="$tmp_dir/response.json"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "FALHOU: $*" >&2
  if [ -s "$response_file" ]; then
    sed 's/^/  /' "$response_file" >&2
  fi
  exit 1
}

request() {
  local method="$1"
  local path="$2"
  local expected="$3"
  local body="${4:-}"
  local code

  if [ -n "$body" ]; then
    code="$(curl -sS -o "$response_file" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path" \
      -H 'Content-Type: application/json' \
      -d "$body")" || fail "$method $path sem resposta"
  else
    code="$(curl -sS -o "$response_file" -w '%{http_code}' \
      -X "$method" "$BASE_URL$path")" || fail "$method $path sem resposta"
  fi

  printf '%-4s %-32s %s\n' "$method" "$path" "$code"

  [ "$code" = "$expected" ] || fail "$method $path retornou $code, esperado $expected"
}

body_has() {
  local expected
  expected="$(printf '%s' "$1" | tr -d ' \n\r\t')"
  tr -d ' \n\r\t' < "$response_file" | grep -Fq -- "$expected" ||
    fail "resposta não contém $1"
}

body_lacks() {
  local unexpected
  unexpected="$(printf '%s' "$1" | tr -d ' \n\r\t')"
  tr -d ' \n\r\t' < "$response_file" | grep -Fq -- "$unexpected" &&
    fail "resposta não deveria conter $1"
  return 0
}

echo "Base: $BASE_URL"
echo

request GET "/api/tickets/all" 200
body_has '"data"'

request POST "/api/tickets/create" 201 \
  "{\"title\":\"$TITLE\",\"description\":\"$DESCRIPTION\",\"sector\":\"$SECTOR\"}"
body_has '"status":"open"'
body_has '"finished_at":null'
body_has "\"title\":\"$TITLE\""

ticket_id="$(tr -d ' \n\r\t' < "$response_file" |
  grep -o '"id":[0-9]*' | head -n 1 | cut -d: -f2)"
[ -n "$ticket_id" ] || fail "id não encontrado na resposta de criação"

request GET "/api/tickets/$ticket_id" 200
body_has "\"title\":\"$TITLE\""

request GET "/api/tickets/open" 200
body_has "\"id\":$ticket_id,"

request POST "/api/tickets/create" 409 \
  "{\"title\":\"$TITLE\",\"description\":\"$DESCRIPTION\",\"sector\":\"$SECTOR\"}"
body_has '"detail"'

request PUT "/api/tickets/$ticket_id/update" 200 \
  "{\"title\":\"$TITLE\",\"description\":\"Em análise\",\"sector\":\"$SECTOR\",\"status\":\"in_progress\"}"
body_has '"status":"in_progress"'

request GET "/api/tickets/open" 200
body_lacks "\"id\":$ticket_id,"

request PUT "/api/tickets/$ticket_id/finish" 200
body_has '"status":"closed"'
body_lacks '"finished_at":null'

request PUT "/api/tickets/$ticket_id/update" 200 \
  "{\"title\":\"$TITLE\",\"description\":\"Voltou\",\"sector\":\"$SECTOR\",\"status\":\"open\"}"
body_has '"status":"open"'
body_has '"finished_at":null'

request GET "/api/tickets/999999" 404
body_has 'Chamado não existe'

request GET "/api/tickets/abc" 404
body_has 'Not Found'

request POST "/api/tickets/create" 422 '{}'

request GET "/api/unknown" 404
body_has 'Not Found'

echo
echo "OK: contrato verificado em $BASE_URL"
