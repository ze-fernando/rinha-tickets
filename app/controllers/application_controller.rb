class ApplicationController < ActionController::API
  rescue_from ApiError, with: :render_api_error
  rescue_from ActiveRecord::RecordNotUnique, with: :render_ticket_conflict
  rescue_from ActionController::ParameterMissing, with: :render_parameter_missing

  def route_not_found
    render json: {
      code: "RESOURCE_NOT_FOUND",
      message: "Recurso não encontrado."
    }, status: :not_found
  end

  private

  def render_api_error(error)
    render json: error.as_json, status: error.status
  end

  def render_ticket_conflict(_error)
    render json: TicketAlreadyExistsError.new.as_json, status: :conflict
  end

  def render_parameter_missing(error)
    render json: {
      code: "VALIDATION_ERROR",
      message: "Os dados informados são inválidos.",
      errors: { error.param => ["é obrigatório."] }
    }, status: 422
  end
end
