class TicketAlreadyExistsError < ApiError
  def initialize
    super(
      message: "Chamado já em aberto",
      code: "TICKET_ALREADY_EXISTS",
      status: 409
    )
  end
end
