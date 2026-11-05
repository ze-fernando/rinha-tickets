# Rinha Tickets

Projeto de estudo que implementa uma API de chamados em diferentes linguagens e stacks. A intenção é comparar formas de resolver o mesmo problema: organização do código, ferramentas, persistência, experiência de desenvolvimento e comportamento da API.

A proposta é aprender e trocar experiências, sem briga entre linguagens, torcida ou tentativa de declarar uma stack superior em tudo. Cada escolha tem contexto e trade-offs. Resultados de desempenho só fazem sentido acompanhados do ambiente, carga, versões e método utilizados.

Todas as implementações seguem o mesmo contrato de API descrito abaixo. Cada branch documenta a própria implementação em um `README.md`, com pré-requisitos, configuração e comandos daquela stack.

## Implementações

| Branch | Implementação |
| --- | --- |
| [main](https://github.com/ze-fernando/rinha-tickets/tree/main) | Entrada do projeto e documentação do comparativo |
| [go](https://github.com/ze-fernando/rinha-tickets/tree/go) | Go / Gin |
| [lua](https://github.com/ze-fernando/rinha-tickets/tree/lua) | Lua |
| [nim-lang](https://github.com/ze-fernando/rinha-tickets/tree/nim-lang) | Nim / Prologue |
| [node](https://github.com/ze-fernando/rinha-tickets/tree/node) | Node.js |
| [php](https://github.com/ze-fernando/rinha-tickets/tree/php) | PHP |
| [python](https://github.com/ze-fernando/rinha-tickets/tree/python) | Python / FastAPI |
| [ruby](https://github.com/ze-fernando/rinha-tickets/tree/ruby) | Ruby |
| [rust](https://github.com/ze-fernando/rinha-tickets/tree/rust) | Rust |

A `main` contém apenas a documentação do projeto, sem implementação. Cada branch mantém o código e as instruções de execução no próprio `README.md`. As implementações com pasta dedicada são [`go-gin/`](https://github.com/ze-fernando/rinha-tickets/tree/go/go-gin) na branch `go` e [`nim-prologue/`](https://github.com/ze-fernando/rinha-tickets/tree/nim-lang/nim-prologue) na branch `nim-lang`; as demais usam a raiz da própria branch.

## Contrato da API

Todos os endpoints de chamados usam o prefixo `/api/tickets`. Corpos de requisição e resposta usam JSON. As implementações não exigem autenticação.

| Método | Rota | Comportamento | Sucesso |
| --- | --- | --- | --- |
| GET | `/api/tickets/all` | Listar todos os chamados | 200 |
| GET | `/api/tickets/open` | Listar apenas chamados com status `open` | 200 |
| GET | `/api/tickets/{id}` | Buscar um chamado pelo ID inteiro | 200 |
| POST | `/api/tickets/create` | Criar um chamado | 201 |
| PUT | `/api/tickets/{id}/update` | Atualizar os dados de um chamado | 200 |
| PUT | `/api/tickets/{id}/finish` | Encerrar um chamado | 200 |

Não há exclusão, paginação, busca textual ou ordenação explícita. Listas vazias retornam `{"data": []}`. Não dependa da ordem dos itens.

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

| Campo | Tipo | Regra |
| --- | --- | --- |
| `title` | string | Obrigatório; único no banco, inclusive entre chamados encerrados |
| `description` | string | Obrigatório |
| `sector` | string | Obrigatório; texto livre |
| `status` | string | Opcional; padrão `open`; aceita `open`, `in_progress` ou `closed` |

Não há validação de tamanho mínimo, máximo ou remoção de espaços nesses textos. O `PUT /update` exige os três campos de texto: não é uma atualização parcial. Omitir `status` nesse endpoint aplica `open`, podendo reabrir um chamado.

### Respostas

Criação, consulta por ID, atualização e encerramento retornam um objeto com os campos abaixo. Os valores são ilustrativos:

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

`id` é gerado pelo banco. `created_at` é a data de criação e `finished_at` é a data de encerramento ou `null`. O formato exato das datas varia por stack; não presuma um sufixo de fuso. As implementações podem manter um `updated_at` no banco sem expô-lo na API.

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

A mensagem de título duplicado diz “em aberto”, mas a verificação considera todos os chamados. A atualização para um título já usado e a colisão de criações concorrentes não têm tratamento específico em todas as implementações; consulte o README da branch para saber como cada uma responde.

## Fluxo de atendimento

1. Crie um chamado com título único, descrição do problema e setor. Use `open` para iniciar o atendimento normal.
2. Consulte `/open` para encontrar chamados aguardando atendimento, ou `/all` para acompanhar todos.
3. Consulte `/{id}` para recuperar os dados antes de editá-los.
4. Envie os três campos de texto e `status: "in_progress"` para `/{id}/update` quando o atendimento começar. Esse chamado deixa de aparecer em `/open`.
5. Envie um `PUT` sem corpo para `/{id}/finish` ao concluir o atendimento. A API define `closed` e registra o horário de encerramento.
6. Consulte o chamado ou `/all` para verificar o resultado. Para reabrir, use `/update` com `open` ou `in_progress`; a data de encerramento será apagada.

O contrato não exige uma máquina de estados: as transições diretas entre todos os status são permitidas. Detalhes do encerramento:

- Atualizar para `closed` preenche `finished_at` se ainda não houver data e preserva a existente.
- Chamar `/finish` novamente substitui a data de encerramento pelo horário da nova chamada.
- Criar diretamente com `closed` é permitido, mas não preenche `finished_at`. Para o fluxo normal, crie com `open` e encerre depois.

## requests.sh

O [`requests.sh`](requests.sh) é um roteiro de verificação do contrato usando apenas `curl` e utilitários de shell, sem depender de `jq` nem da linguagem da implementação. Ele percorre o fluxo completo e falha com código de saída diferente de zero quando uma resposta ou um status HTTP não corresponde ao esperado.

```sh
./requests.sh
```

Por padrão o script usa `http://localhost:8000`. Para apontar para outra porta ou host:

```sh
BASE_URL=http://localhost:8080 ./requests.sh
```

O roteiro cria um chamado com título único, lista, consulta por ID, inicia o atendimento, tenta repetir a criação para conferir o 409, encerra, reabre, e valida os erros 404 e 422. O título padrão inclui um sufixo de data e PID para permitir execuções repetidas; use `TITLE=...` para fixar outro valor. Como cada execução cria dados novos, use um banco de desenvolvimento ou descartável ao rodar contra uma instância real.

Cada execução remove os arquivos temporários que cria. O script imprime cada etapa com o método, a rota e o status recebido, e encerra com `OK` quando todas as verificações passam.

## Como implementar e comparar outra stack

1. Use uma branch própria para a implementação e mantenha seu passo a passo de instalação e execução atualizado.
2. Preserve as rotas, os métodos, os nomes dos campos, os status e o formato das respostas ao buscar equivalência com este contrato.
3. Implemente persistência, criação de schema e o ciclo de criação, consulta, atendimento, encerramento e reabertura. Documente qualquer diferença de comportamento.
4. Verifique o fluxo completo e os erros: chamado inexistente, título duplicado, corpo inválido e listas vazias. Rode `./requests.sh` antes de abrir o pull request.
5. Ao propor uma mudança de contrato, registre a diferença para que as demais implementações possam acompanhar.
6. Para medir desempenho, use os mesmos recursos, dados iniciais e requisições; registre versões, concorrência, duração, aquecimento, latência, vazão e erros. Declare diferenças de banco e configuração que possam influenciar os resultados.

O objetivo é discutir decisões e aprender com os resultados. Compare implementações e condições concretas, com respeito às pessoas que usam cada tecnologia.
