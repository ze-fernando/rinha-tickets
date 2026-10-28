# Rinha Tickets

Projeto de estudo que implementa uma API de chamados em diferentes linguagens e stacks. A intenção é comparar formas de resolver o mesmo problema: organização do código, ferramentas, persistência, experiência de desenvolvimento e comportamento da API.

A proposta é aprender e trocar experiências, sem briga entre linguagens, torcida ou tentativa de declarar uma stack superior em tudo. Cada escolha tem contexto e trade-offs. Resultados de desempenho só fazem sentido acompanhados do ambiente, carga, versões e método utilizados.

## Implementações

| Branch | Implementação |
| --- | --- |
| [main](https://github.com/ze-fernando/rinha-tickets/tree/main) | Entrada do projeto e documentação do comparativo |
| [lua](https://github.com/ze-fernando/rinha-tickets/tree/lua) | Lua |
| [node](https://github.com/ze-fernando/rinha-tickets/tree/node) | Node.js |
| [php](https://github.com/ze-fernando/rinha-tickets/tree/php) | PHP |
| [python](https://github.com/ze-fernando/rinha-tickets/tree/python) | Python / FastAPI |
| [ruby](https://github.com/ze-fernando/rinha-tickets/tree/ruby) | Ruby |
| [rust](https://github.com/ze-fernando/rinha-tickets/tree/rust) | Rust |

A `main` foi criada a partir da implementação Python e também contém esse código. A documentação abaixo descreve essa implementação; a equivalência das demais branches deve ser verificada antes de comparar resultados.

## Executar a implementação Python

Pré-requisitos: Git, Python 3.14 ou superior e PDM disponíveis no terminal. As dependências estão em `pyproject.toml`, com versões resolvidas em `pdm.lock`.

```sh
git clone git@github.com:ze-fernando/rinha-tickets.git
cd rinha-tickets
git switch python
pdm install
pdm run alembic upgrade head
pdm run dev
```

Para executar o código presente na `main`, use `git switch main` no lugar de `git switch python`.

O servidor atende em `http://localhost:8000`. O comando de desenvolvimento usa recarga automática e escuta em `0.0.0.0:8000`.

O banco é SQLite, no arquivo `database.sqlite` relativo ao diretório em que os comandos são executados. Execute os comandos na raiz do projeto. A URL `sqlite+aiosqlite:///database.sqlite` está definida no código da aplicação e das migrações; não há configuração por variável de ambiente nem arquivo `.env` obrigatório. A criação das tabelas é feita pelo Alembic, antes de iniciar a API.

| Comando | Finalidade |
| --- | --- |
| `pdm install` | Instalar as dependências |
| `pdm run dev` | Iniciar a API em desenvolvimento |
| `pdm run alembic upgrade head` | Aplicar as migrações existentes |
| `pdm run alembic current` | Consultar a revisão do banco |
| `pdm run alembic revision --autogenerate -m "descricao"` | Gerar uma migração para revisar antes de aplicar |

O atalho `pdm run migrate "descricao"` gera uma migração e a aplica em seguida. Para mudanças de schema, prefira gerar, revisar o arquivo e só então executar `upgrade head`.

## Contrato da API

Todos os endpoints de chamados usam o prefixo `/api/tickets`. Corpos de requisição e resposta usam JSON. A implementação atual não exige autenticação.

| Método | Rota | Comportamento | Sucesso |
| --- | --- | --- | --- |
| GET | `/api/tickets/all` | Listar todos os chamados | 200 |
| GET | `/api/tickets/open` | Listar apenas chamados com status `open` | 200 |
| GET | `/api/tickets/{id}` | Buscar um chamado pelo ID inteiro | 200 |
| POST | `/api/tickets/create` | Criar um chamado | 201 |
| PUT | `/api/tickets/{id}/update` | Atualizar os dados de um chamado | 200 |
| PUT | `/api/tickets/{id}/finish` | Encerrar um chamado | 200 |

Não há exclusão, paginação, busca textual ou ordenação explícita. Listas vazias retornam `{"data": []}`. Não dependa da ordem dos itens.

Documentação interativa, com os schemas completos e possibilidade de executar requisições:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- OpenAPI: `http://localhost:8000/openapi.json`

### Dados de entrada

Criação e atualização recebem o mesmo corpo:

```json
{
  "title": "Impressora sem conexão",
  "description": "A impressora da recepção não aparece na rede.",
  "sector": "Recepção",
  "status": "open"
}
```

| Campo | Tipo | Regra atual |
| --- | --- | --- |
| `title` | string | Obrigatório; único no banco, inclusive entre chamados encerrados |
| `description` | string | Obrigatório |
| `sector` | string | Obrigatório; texto livre |
| `status` | string | Opcional; padrão `open`; aceita `open`, `in_progress` ou `closed` |

Não há validação explícita de tamanho mínimo, máximo ou remoção de espaços nesses textos. O `PUT /update` exige os três campos de texto: não é uma atualização parcial. Omitir `status` nesse endpoint aplica `open`, podendo reabrir um chamado.

### Respostas

Criação, consulta por ID, atualização e encerramento retornam um objeto com os seguintes campos. Os valores abaixo são ilustrativos:

```json
{
  "title": "Impressora sem conexão",
  "description": "A impressora da recepção não aparece na rede.",
  "sector": "Recepção",
  "status": "open",
  "id": 1,
  "finished_at": null,
  "created_at": "2026-10-28T12:00:00"
}
```

`id` é gerado pelo banco. `created_at` é a data de criação e `finished_at` é a data de encerramento ou `null`. Datas são serializadas como strings de data/hora; não presuma um sufixo de fuso na resposta SQLite. O banco também mantém `updated_at`, mas a API não o expõe.

As duas listagens envolvem os objetos em `data`:

```json
{
  "data": [
    {
      "title": "Impressora sem conexão",
      "description": "A impressora da recepção não aparece na rede.",
      "sector": "Recepção",
      "status": "open",
      "id": 1,
      "finished_at": null,
      "created_at": "2026-10-28T12:00:00"
    }
  ]
}
```

### Erros e limites conhecidos

| Situação | HTTP | Resposta/comportamento |
| --- | --- | --- |
| ID inteiro inexistente na consulta, atualização ou encerramento | 404 | `{"detail":"Chamado não existe"}` |
| Criação com título já existente | 409 | `{"detail":"Chamado já em aberto"}` |
| Corpo ausente, campo obrigatório ausente ou status inválido | 422 | Erro de validação com detalhes em `detail` |
| Caminho com ID que não corresponde ao conversor inteiro da rota | 404 | Rota não encontrada |

A mensagem de título duplicado diz “em aberto”, mas a verificação considera todos os chamados. A atualização para um título já usado e a colisão de criações concorrentes não têm tratamento específico de erro de integridade; não há garantia de resposta 409 nesses casos.

## Fluxo de atendimento

1. Crie um chamado com título único, descrição do problema e setor. Use `open` para iniciar o atendimento normal.
2. Consulte `/open` para encontrar chamados aguardando atendimento, ou `/all` para acompanhar todos.
3. Consulte `/{id}` para recuperar os dados antes de editá-los.
4. Envie os três campos de texto e `status: "in_progress"` para `/{id}/update` quando o atendimento começar. Esse chamado deixa de aparecer em `/open`.
5. Envie um `PUT` sem corpo para `/{id}/finish` ao concluir o atendimento. A API define `closed` e registra o horário de encerramento.
6. Consulte o chamado ou `/all` para verificar o resultado. Para reabrir, use `/update` com `open` ou `in_progress`; a data de encerramento será apagada.

O código permite transições diretas entre todos os status; não existe uma máquina de estados que obrigue a passar por `in_progress`.

Detalhes do encerramento atual:

- Atualizar para `closed` preenche `finished_at` se ainda não houver data e preserva a existente.
- Chamar `/finish` novamente substitui a data de encerramento pelo horário da nova chamada.
- Criar diretamente com `closed` é permitido, mas não preenche `finished_at`. Para o fluxo normal, crie com `open` e encerre depois.

### Exemplo completo com curl

Com o servidor ativo, execute os comandos na sequência. Substitua `1` pelo `id` retornado na criação e use outro título se ele já existir.

```sh
# Criar
curl -i -X POST http://localhost:8000/api/tickets/create \
  -H 'Content-Type: application/json' \
  -d '{"title":"Impressora sem conexão","description":"Não aparece na rede","sector":"Recepção","status":"open"}'

# Listar todos e os abertos
curl http://localhost:8000/api/tickets/all
curl http://localhost:8000/api/tickets/open

# Consultar
curl http://localhost:8000/api/tickets/1

# Iniciar atendimento, enviando todos os campos obrigatórios
curl -i -X PUT http://localhost:8000/api/tickets/1/update \
  -H 'Content-Type: application/json' \
  -d '{"title":"Impressora sem conexão","description":"Verificando conexão de rede","sector":"Recepção","status":"in_progress"}'

# Encerrar e conferir
curl -i -X PUT http://localhost:8000/api/tickets/1/finish
curl http://localhost:8000/api/tickets/1
```

## Organização e fluxo interno

```text
Requisição HTTP
  → controller (rota e validação do corpo com schemas)
  → service (consulta e regras do chamado)
  → SQLAlchemy / sessão assíncrona
  → SQLite
  → schema de resposta → JSON
```

| Arquivo/diretório | Responsabilidade |
| --- | --- |
| `app/main.py` | Criar a aplicação FastAPI e registrar as rotas |
| `app/ticket/controller.py` | Definir endpoints, códigos de sucesso e schemas |
| `app/ticket/schemas.py` | Definir entradas e respostas com Pydantic |
| `app/ticket/service.py` | Consultar, criar, atualizar e encerrar chamados |
| `app/ticket/models.py` | Definir a tabela `tickets` e os status |
| `app/ticket/errors.py` | Definir os erros de chamado inexistente e duplicado |
| `app/infra/database.py` | Configurar engine, sessão e campos comuns do modelo |
| `migrations/` | Versionar o schema com Alembic |

Cada requisição recebe uma sessão por injeção de dependência. Operações de escrita fazem `commit` e recarregam o objeto antes de montar a resposta. Consultas usam a sessão sem alterar dados. O título possui restrição de unicidade no banco, além da consulta prévia realizada na criação.

## Como implementar e comparar outra stack

1. Use uma branch própria para a implementação e mantenha seu passo a passo de instalação e execução atualizado.
2. Preserve as rotas, os métodos, os nomes dos campos, os status e o formato das respostas ao buscar equivalência com este contrato.
3. Implemente persistência, migrações e o ciclo de criação, consulta, atendimento, encerramento e reabertura. Documente qualquer diferença de comportamento.
4. Verifique o fluxo completo e os erros: chamado inexistente, título duplicado, corpo inválido e listas vazias. Confira também os detalhes de encerramento descritos acima.
5. Ao propor uma mudança de contrato, registre a diferença para que as demais implementações possam acompanhar.
6. Para medir desempenho, use os mesmos recursos, dados iniciais e requisições; registre versões, concorrência, duração, aquecimento, latência, vazão e erros. Declare diferenças de banco e configuração que possam influenciar os resultados.

O objetivo é discutir decisões e aprender com os resultados. Compare implementações e condições concretas, com respeito às pessoas que usam cada tecnologia.
