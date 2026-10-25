class TicketResponse
  attr_reader :ticket

  def initialize(ticket)
    @ticket = ticket
  end

  def as_json(*)
    {
      id: ticket.id,
      title: ticket.title,
      description: ticket.description,
      sector: ticket.sector,
      status: ticket.status,
      finished_at: iso8601(ticket.finished_at),
      created_at: iso8601(ticket.created_at),
      updated_at: iso8601(ticket.updated_at)
    }
  end

  private

  def iso8601(value)
    value&.utc&.iso8601(6)
  end
end
