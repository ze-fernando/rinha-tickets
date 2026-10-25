# Ticket API — Lua

API de chamados construída com LuaJIT, FFI e SQLite, sem dependências externas.
O servidor HTTP, o acesso ao SQLite e o parser JSON são implementados no próprio
projeto usando apenas a biblioteca padrão e chamadas FFI para libc e libsqlite3.

## Requisitos

- LuaJIT 2.1 ou superior
- libsqlite3

## Executar

```bash
./bin/dev
```

O servidor sobe por padrão em `http://0.0.0.0:8000` com o banco
`database.sqlite`. As migrations pendentes são aplicadas na inicialização.

Variáveis de ambiente (também lidas de um arquivo `.env`):

| Variável | Padrão | Descrição |
| --- | --- | --- |
| `PORT` | `8000` | Porta HTTP |
| `HOST` | `0.0.0.0` | Endereço de escuta |
| `DATABASE_PATH` | `database.sqlite` | Caminho do banco SQLite |

## Testes

```bash
./bin/test
```

Com o servidor rodando na porta `8000`, execute também a suíte de aceitação:

```bash
../requests.sh
```

## Endpoints

| Método | Rota | Descrição |
| --- | --- | --- |
| GET | `/api/tickets/all` | Lista todos os chamados, mais recentes primeiro |
| GET | `/api/tickets/open` | Lista apenas chamados com status `open` |
| GET | `/api/tickets/:id` | Busca um chamado por ID |
| POST | `/api/tickets/create` | Cria um chamado |
| PUT | `/api/tickets/:id/update` | Atualiza um chamado |
| PUT | `/api/tickets/:id/finish` | Finaliza um chamado |

O `status` aceita `open`, `in_progress` e `closed`, sem diferenciar
maiúsculas de minúsculas, e assume `open` quando não informado.

Resposta de um chamado:

```json
{
  "id": 1,
  "title": "Chamado",
  "description": "Descrição",
  "sector": "TI",
  "status": "open",
  "finished_at": null,
  "created_at": "2026-10-24T20:45:21.123456Z",
  "updated_at": "2026-10-24T20:45:21.123456Z"
}
```

Erros seguem o formato:

```json
{
  "code": "TICKET_NOT_FOUND",
  "message": "Chamado não encontrado"
}
```

Erros de validação retornam `422` com os campos inválidos:

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Os dados informados são inválidos.",
  "errors": {
    "description": ["A descrição é obrigatória."]
  }
}
```

## Estrutura

```
src/
  main.lua            inicialização do servidor e das migrations
  app.lua             roteamento, despacho e tratamento de erros
  config.lua          leitura de ambiente e .env
  infra/
    ffi.lua           declarações FFI de libc e libsqlite3
    database.lua      conexão e operações SQLite
    json.lua          codificação e decodificação JSON
    clock.lua         timestamps UTC com microssegundos
    http.lua          servidor HTTP/1.1
    migrator.lua      executor de migrations
  ticket/
    controller.lua    camada HTTP
    dto.lua           validação e normalização da entrada
    errors.lua        erros de domínio
    model.lua         consultas SQL
    response.lua      serialização de saída
    routes.lua        definição das rotas
    service.lua       regras de negócio
migrations/
  manifest.lua        ordem das migrations
  *.sql               schema
tests/
  run.lua             executor da suíte
```
