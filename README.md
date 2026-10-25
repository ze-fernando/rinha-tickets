# Ticket API — Ruby on Rails

API de chamados em modo `--api`, construída com Ruby on Rails 8.1, Ruby 3.4,
SQLite e Active Record.

## Requisitos

- Ruby 3.4.10
- Bundler
- SQLite 3

## Executar

```bash
bundle install
bin/rails db:prepare
bin/rails server
```

O servidor sobe por padrão na porta `8000`. Para usar outra porta:

```bash
PORT=3000 bin/rails server
```

## Testes

```bash
bin/rails test
bin/rails zeitwerk:check
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
maiúsculas de minúsculas. Quando omitido na criação, assume `open`.

## Estrutura

- `app/controllers/api/tickets_controller.rb`: camada HTTP, fina.
- `app/dto/ticket_data.rb`: DTO de entrada com validações e normalização.
- `app/dto/ticket_response.rb`: DTO de saída.
- `app/services/tickets_service.rb`: regras de negócio e transações.
- `app/models/ticket.rb`: modelo Active Record e enum de status.
- `app/errors/`: exceções customizadas da API.
- `app/enums/ticket_status.rb`: valores canônicos de status.
- `db/migrate/`: schema SQLite com índice único de título e check constraint.
- `test/integration/ticket_api_test.rb`: testes de integração HTTP.

## Formato de erro

```json
{
  "code": "TICKET_NOT_FOUND",
  "message": "Chamado não encontrado"
}
```

Erros de validação incluem o campo `errors`:

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Os dados informados são inválidos.",
  "errors": {
    "description": ["A descrição é obrigatória."]
  }
}
```

## Regras de status

- Criar sem status grava `open`.
- Atualizar para `closed` preenche `finished_at` se ainda não existir.
- Reabrir um chamado limpa `finished_at`.
- `finish` sempre grava `closed` e um novo `finished_at`.
