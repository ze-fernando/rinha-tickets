class TicketsService
  class << self
    def find_all
      Ticket.order(created_at: :desc).map { |ticket| TicketResponse.new(ticket) }
    end

    def find_open
      Ticket
        .where(status: TicketStatus::OPEN)
        .order(created_at: :desc)
        .map { |ticket| TicketResponse.new(ticket) }
    end

    def find_by_id(ticket_id)
      TicketResponse.new(find_ticket!(ticket_id))
    end

    def create(data)
      Ticket.transaction do
        ensure_title_is_available(data.title)

        ticket = Ticket.create!(
          title: data.title,
          description: data.description,
          sector: data.sector,
          status: data.status
        )

        TicketResponse.new(ticket)
      end
    rescue ActiveRecord::RecordNotUnique
      raise TicketAlreadyExistsError
    end

    def update(ticket_id, data)
      Ticket.transaction do
        ticket = find_ticket!(ticket_id)

        ensure_title_is_available(data.title, ignore_ticket_id: ticket.id)

        finished_at = if data.status == TicketStatus::CLOSED
                        ticket.finished_at || Time.current
                      end

        ticket.update!(
          title: data.title,
          description: data.description,
          sector: data.sector,
          status: data.status,
          finished_at: finished_at
        )

        TicketResponse.new(ticket)
      end
    rescue ActiveRecord::RecordNotUnique
      raise TicketAlreadyExistsError
    end

    def finish(ticket_id)
      Ticket.transaction do
        ticket = find_ticket!(ticket_id)

        ticket.update!(
          status: TicketStatus::CLOSED,
          finished_at: Time.current
        )

        TicketResponse.new(ticket)
      end
    end

    private

    def find_ticket!(ticket_id)
      Ticket.find_by(id: ticket_id) || raise(TicketNotFoundError)
    end

    def ensure_title_is_available(title, ignore_ticket_id: nil)
      relation = Ticket.where(title: title)
      relation = relation.where.not(id: ignore_ticket_id) if ignore_ticket_id

      raise TicketAlreadyExistsError if relation.exists?
    end
  end
end
