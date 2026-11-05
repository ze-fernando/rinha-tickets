# Nim / Prologue / Norm

Implementação do contrato de chamados do [projeto](../README.md), com Prologue, Norm e SQLite. A organização segue controller → service → modelos, com validação e serialização separadas.

## Executar

Pré-requisitos: Nim 2.2 ou superior e Nimble disponíveis no terminal. O compilador C padrão do sistema é usado no build.

```sh
cd nim-prologue
nimble install -d
nimble build
./ticket
```

O servidor escuta em `http://localhost:8000`. A tabela `tickets` é criada por `createTables` na inicialização, sem migrações versionadas nem rollback. Use um arquivo SQLite próprio desta implementação.

Configurações opcionais:

| Variável | Padrão | Uso |
| --- | --- | --- |
| `PORT` | `8000` | Porta HTTP; valores inválidos voltam para o padrão |
| `DATABASE_PATH` | `database.sqlite` | Arquivo SQLite, relativo ao diretório de execução |

```sh
PORT=8080 DATABASE_PATH=/tmp/tickets.sqlite ./ticket
```

A inicialização ativa `journal_mode=WAL`; cada thread abre a própria conexão SQLite com `busy_timeout=5000`. O build precisa de `--deepcopy:on` por causa da integração entre Prologue e Norm; a opção já está em `config.nims`.

## Testes

```sh
nimble test
```

A tarefa compila o binário e executa, nesta ordem:

- `tests/unit.nim`: validação de entrada, IDs de caminho, serialização e formato de data.
- `tests/integration.nim`: regras de criação, atualização, encerramento e reabertura contra um SQLite temporário.
- `tests/e2e.nim`: sobe o binário em uma porta livre e percorre o fluxo HTTP completo, incluindo erros.

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

As regras de datas seguem a referência: criar com `closed` deixa `finished_at` nulo; atualizar para `closed` preenche a data apenas se ausente; `/finish` substitui a data, respeitando a precisão de segundos; reabrir limpa a data. Operações não têm chave de idempotência; repetir `/finish` atualiza a data e repetir a criação retorna 409.

Erros usam `{"detail": ...}`: 404 com `Chamado não existe`, 409 com `Chamado já em aberto`, 422 para JSON/campos inválidos e 500 com mensagem genérica para falhas internas. IDs com caracteres inválidos ou negativos retornam 404 com o detalhe genérico da rota; inteiros decimais acima de `int64` são tratados como chamado inexistente.

Diferenças explícitas em relação à referência Python:

- Conflitos de título em atualizações e criações concorrentes retornam 409; a referência não trata esse caso.
- Datas são sempre UTC e truncadas em segundos; a referência pode incluir frações de segundo.
- Chamar `/finish` duas vezes dentro do mesmo segundo pode manter o mesmo `finished_at`.
- Detalhes de validação são strings simples, não os objetos de erro do Pydantic.
- Não são fornecidos Swagger UI, ReDoc ou OpenAPI automático.
- A criação de schema usa `createTables`, em vez de migrações versionadas Alembic.

## Estrutura

- `src/main.nim`: ponto de entrada, abre o banco e inicia o servidor.
- `src/app.nim`: aplicação Prologue, rotas, porta e tratadores de 404/500.
- `src/infra/database.nim`: conexão SQLite por thread, WAL e criação da tabela.
- `src/ticket/models.nim`: modelo persistido e status permitidos.
- `src/ticket/schemas.nim`: validação de entrada, IDs, datas e serialização.
- `src/ticket/service.nim`: consultas e transições de status.
- `src/ticket/controller.nim`: handlers HTTP e mapeamento de erros.
- `tests/unit.nim`, `tests/integration.nim`, `tests/e2e.nim`: testes por camada.

Referências: [Prologue](https://github.com/planety/prologue), [Norm](https://github.com/moigagoo/norm) e [SQLite](https://www.sqlite.org/).
