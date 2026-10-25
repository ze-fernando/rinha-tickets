require "test_helper"

class TicketApiTest < ActionDispatch::IntegrationTest
  setup do
    Ticket.delete_all
  end

  test "lists all tickets ordered by newest first" do
    older = create_ticket(title: "Chamado antigo", created_at: 2.days.ago)
    newer = create_ticket(title: "Chamado novo", created_at: 1.day.ago)

    get "/api/tickets/all"

    assert_response :ok
    body = json_body

    assert_equal [newer.id, older.id], body.map { |ticket| ticket["id"] }
    assert_equal(
      %w[created_at description finished_at id sector status title updated_at],
      body.first.keys.sort
    )
  end

  test "returns an empty list when there are no tickets" do
    get "/api/tickets/all"

    assert_response :ok
    assert_equal [], json_body
  end

  test "lists only open tickets" do
    open_ticket = create_ticket(title: "Aberto")
    create_ticket(title: "Em andamento", status: TicketStatus::IN_PROGRESS)
    create_ticket(
      title: "Fechado",
      status: TicketStatus::CLOSED,
      finished_at: 1.hour.ago
    )

    get "/api/tickets/open"

    assert_response :ok
    assert_equal [open_ticket.id], json_body.map { |ticket| ticket["id"] }
  end

  test "shows a ticket by id" do
    ticket = create_ticket(title: "Chamado detalhado")

    get "/api/tickets/#{ticket.id}"

    assert_response :ok
    body = json_body

    assert_equal ticket.id, body["id"]
    assert_equal "Chamado detalhado", body["title"]
    assert_equal "Descrição do Chamado detalhado", body["description"]
    assert_equal "TI", body["sector"]
    assert_equal "open", body["status"]
    assert_nil body["finished_at"]
  end

  test "returns not found when the ticket does not exist" do
    get "/api/tickets/999999"

    assert_response :not_found
    assert_equal "TICKET_NOT_FOUND", json_body["code"]
    assert_equal "Chamado não encontrado", json_body["message"]
  end

  test "creates a ticket with the default open status" do
    assert_difference -> { Ticket.count }, 1 do
      post "/api/tickets/create",
           params: {
             title: "Novo chamado",
             description: "Descrição do novo chamado",
             sector: "TI"
           },
           as: :json
    end

    assert_response :created
    body = json_body

    assert_equal "Novo chamado", body["title"]
    assert_equal "open", body["status"]
    assert_nil body["finished_at"]
    assert_equal "TI", body["sector"]
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\z/, body["created_at"])
  end

  test "normalizes a case insensitive status on create" do
    post "/api/tickets/create",
         params: {
           title: "Chamado fechado",
           description: "Descrição",
           sector: "TI",
           status: "CLOSED"
         },
         as: :json

    assert_response :created
    assert_equal "closed", json_body["status"]
  end

  test "returns conflict when creating a ticket with a duplicated title" do
    create_ticket(title: "Chamado duplicado")

    post "/api/tickets/create",
         params: {
           title: "Chamado duplicado",
           description: "Outra descrição",
           sector: "TI"
         },
         as: :json

    assert_response :conflict
    assert_equal "TICKET_ALREADY_EXISTS", json_body["code"]
    assert_equal "Chamado já em aberto", json_body["message"]
  end

  test "returns validation errors when required fields are missing" do
    post "/api/tickets/create",
         params: { title: "Chamado sem descrição", sector: "TI" },
         as: :json

    assert_response 422
    body = json_body

    assert_equal "VALIDATION_ERROR", body["code"]
    assert_equal ["A descrição é obrigatória."], body.dig("errors", "description")
  end

  test "returns validation errors for all missing required fields" do
    post "/api/tickets/create", params: {}, as: :json

    assert_response 422
    body = json_body

    assert_equal ["O título é obrigatório."], body.dig("errors", "title")
    assert_equal ["A descrição é obrigatória."], body.dig("errors", "description")
    assert_equal ["O setor é obrigatório."], body.dig("errors", "sector")
  end

  test "returns validation errors when the status is invalid" do
    post "/api/tickets/create",
         params: {
           title: "Chamado inválido",
           description: "Descrição",
           sector: "TI",
           status: "invalid"
         },
         as: :json

    assert_response 422
    assert_equal(
      ["O status deve ser open, in_progress ou closed."],
      json_body.dig("errors", "status")
    )
  end

  test "returns validation errors when fields are not strings" do
    post "/api/tickets/create",
         params: {
           title: ["Chamado inválido"],
           description: 123,
           sector: "TI",
           status: ["open"]
         },
         as: :json

    assert_response 422
    body = json_body

    assert_includes body.dig("errors", "title"), "O título deve ser um texto."
    assert_includes body.dig("errors", "description"), "A descrição deve ser um texto."
    assert_includes(
      body.dig("errors", "status"),
      "O status deve ser open, in_progress ou closed."
    )
  end

  test "updates a ticket and closes it" do
    ticket = create_ticket(title: "Chamado para atualizar")

    put "/api/tickets/#{ticket.id}/update",
        params: {
          title: "Chamado atualizado",
          description: "Descrição atualizada",
          sector: "RH",
          status: "closed"
        },
        as: :json

    assert_response :ok
    body = json_body
    ticket.reload

    assert_equal "Chamado atualizado", body["title"]
    assert_equal "closed", body["status"]
    assert_not_nil body["finished_at"]
    assert_equal "closed", ticket.status
    assert_not_nil ticket.finished_at
  end

  test "clears finished_at when a ticket is reopened" do
    ticket = create_ticket(
      title: "Chamado para reabrir",
      status: TicketStatus::CLOSED,
      finished_at: 1.hour.ago
    )

    put "/api/tickets/#{ticket.id}/update",
        params: {
          title: "Chamado para reabrir",
          description: "Descrição",
          sector: "TI",
          status: "open"
        },
        as: :json

    assert_response :ok
    assert_nil json_body["finished_at"]
    assert_nil ticket.reload.finished_at
  end

  test "preserves finished_at when an already closed ticket is updated" do
    finished_at = 1.hour.ago
    ticket = create_ticket(
      title: "Chamado fechado",
      status: TicketStatus::CLOSED,
      finished_at: finished_at
    )

    put "/api/tickets/#{ticket.id}/update",
        params: {
          title: "Chamado fechado atualizado",
          description: "Descrição",
          sector: "TI",
          status: "closed"
        },
        as: :json

    assert_response :ok
    assert_in_delta finished_at.to_f, ticket.reload.finished_at.to_f, 0.001
  end

  test "returns conflict when updating a ticket to a duplicated title" do
    create_ticket(title: "Título existente")
    ticket = create_ticket(title: "Outro título")

    put "/api/tickets/#{ticket.id}/update",
        params: {
          title: "Título existente",
          description: "Descrição",
          sector: "TI",
          status: "open"
        },
        as: :json

    assert_response :conflict
    assert_equal "TICKET_ALREADY_EXISTS", json_body["code"]
  end

  test "returns not found when updating a missing ticket" do
    put "/api/tickets/999999/update",
        params: {
          title: "Chamado inexistente",
          description: "Descrição",
          sector: "TI",
          status: "open"
        },
        as: :json

    assert_response :not_found
    assert_equal "TICKET_NOT_FOUND", json_body["code"]
  end

  test "returns validation errors when updating with an invalid payload" do
    ticket = create_ticket(title: "Chamado válido")

    put "/api/tickets/#{ticket.id}/update",
        params: { title: "Chamado válido", sector: "TI", status: "open" },
        as: :json

    assert_response 422
    assert_equal ["A descrição é obrigatória."], json_body.dig("errors", "description")
    assert_equal "Chamado válido", ticket.reload.title
  end

  test "finishes a ticket" do
    ticket = create_ticket(
      title: "Chamado em andamento",
      status: TicketStatus::IN_PROGRESS
    )

    put "/api/tickets/#{ticket.id}/finish", as: :json

    assert_response :ok
    body = json_body

    assert_equal "closed", body["status"]
    assert_not_nil body["finished_at"]
    assert_equal "closed", ticket.reload.status
    assert_not_nil ticket.finished_at
  end

  test "finishing an already closed ticket updates finished_at" do
    previous_finished_at = 1.day.ago
    ticket = create_ticket(
      title: "Chamado já fechado",
      status: TicketStatus::CLOSED,
      finished_at: previous_finished_at
    )

    put "/api/tickets/#{ticket.id}/finish", as: :json

    assert_response :ok
    assert_operator Time.iso8601(json_body["finished_at"]), :>, previous_finished_at
  end

  test "returns not found when finishing a missing ticket" do
    put "/api/tickets/999999/finish", as: :json

    assert_response :not_found
    assert_equal "TICKET_NOT_FOUND", json_body["code"]
  end

  test "returns a standardized error for unknown routes" do
    get "/api/unknown"

    assert_response :not_found
    assert_equal "RESOURCE_NOT_FOUND", json_body["code"]
    assert_equal "Recurso não encontrado.", json_body["message"]
  end

  private

  def create_ticket(title:, status: TicketStatus::OPEN, finished_at: nil, created_at: Time.current)
    Ticket.create!(
      title: title,
      description: "Descrição do #{title}",
      sector: "TI",
      status: status,
      finished_at: finished_at,
      created_at: created_at,
      updated_at: created_at
    )
  end

  def json_body
    JSON.parse(response.body)
  end
end
