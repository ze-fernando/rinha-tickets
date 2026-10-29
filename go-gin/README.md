# Go / Gin / GORM

Implementação do contrato de chamados do [projeto](../README.md), com Gin, GORM e SQLite. A organização segue controller → service → modelo/persistência.

## Executar

Pré-requisitos: Go 1.25 ou superior e compilador C (GCC ou Clang), pois o driver SQLite usa CGO.

```sh
cd go-gin
go mod download
go run ./cmd/api
```

O servidor escuta em `http://localhost:8000`. O GORM cria/atualiza a tabela `tickets` e seu índice único de título automaticamente ao iniciar (`AutoMigrate`). Essa estratégia não fornece migrações versionadas nem rollback; use um arquivo SQLite próprio desta implementação.

Configurações opcionais:

| Variável | Padrão | Uso |
| --- | --- | --- |
| `ADDR` | `:8000` | Endereço HTTP |
| `DATABASE_PATH` | `database.sqlite` | Arquivo SQLite, relativo ao diretório de execução |
| `GIN_MODE` | `debug` | Use `release` para execução sem mensagens de depuração |

```sh
ADDR=:8080 DATABASE_PATH=/tmp/tickets.sqlite GIN_MODE=release go run ./cmd/api
go test ./...
go test -race ./...
go vet ./...
go build -o api ./cmd/api
```

## Contrato

| Método | Rota | Sucesso |
| --- | --- | --- |
| GET | `/api/tickets/all` | 200, `{"data": [...]}` |
| GET | `/api/tickets/open` | 200, `{"data": [...]}` |
| GET | `/api/tickets/{id}` | 200 |
| POST | `/api/tickets/create` | 201 |
| PUT | `/api/tickets/{id}/update` | 200 |
| PUT | `/api/tickets/{id}/finish` | 200 |

Criação e atualização exigem `title`, `description` e `sector` como strings (inclusive vazias). `status` aceita `open`, `in_progress` ou `closed`; omiti-lo aplica `open`, inclusive na atualização. Campos extras são ignorados. Não há autenticação, exclusão, paginação ou ordenação garantida.

```sh
curl -i http://localhost:8000/api/tickets/create \
  -H 'Content-Type: application/json' \
  -d '{"title":"Impressora","description":"Sem rede","sector":"Recepção"}'
curl http://localhost:8000/api/tickets/all
curl -X PUT http://localhost:8000/api/tickets/1/finish
```

Objetos retornam `id`, `title`, `description`, `sector`, `status`, `finished_at` e `created_at`. `updated_at` é persistido, mas não exposto. Listas vazias retornam `{"data":[]}`.

As regras de datas seguem a referência: criar com `closed` deixa `finished_at` nulo; atualizar para `closed` preenche a data apenas se ausente; `/finish` sempre substitui a data; reabrir limpa a data. Operações não têm chave de idempotência; repetir `/finish` modifica a data e repetir a criação pode retornar 409.

Erros usam `{"detail": ...}`: 404 com `Chamado não existe`, 409 com `Chamado já em aberto`, 422 para JSON/campos inválidos e 500 com mensagem genérica para falhas internas. IDs fora do formato inteiro decimal não negativo retornam 404.

Diferenças explícitas em relação à referência Python:

- Unicidade é tratada no banco: conflitos retornam 409 também em atualizações e criações concorrentes.
- Datas usam RFC 3339 com fuso; a forma exata pode diferir da serialização SQLite/Python.
- Detalhes de validação são strings do binding do Gin, não os objetos de erro do Pydantic.
- Não são fornecidos Swagger UI, ReDoc ou OpenAPI automático.
- A criação/atualização de schema usa `AutoMigrate`, em vez de migrações versionadas Alembic.

## Estrutura

- `cmd/api`: configuração e inicialização do servidor.
- `internal/database`: conexão SQLite e migração GORM.
- `internal/ticket/model.go`: modelo persistido e entrada validada.
- `internal/ticket/service.go`: consultas e transições de status.
- `internal/ticket/controller.go`: rotas, binding e respostas HTTP.
- `internal/ticket/api_test.go`: testes HTTP com SQLite temporário, incluindo persistência após reabrir o banco.

Referências: [Gin](https://gin-gonic.com/en/docs/quickstart/), [GORM/SQLite](https://gorm.io/docs/connecting_to_the_database.html) e [atualizações GORM](https://gorm.io/docs/update.html).
