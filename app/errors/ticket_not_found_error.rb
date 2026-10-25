class TicketNotFoundError < ApiError
  def initialize
    super(
      message: "Chamado não encontrado",
      code: "TICKET_NOT_FOUND",
      status: 404
    )
  end
end
