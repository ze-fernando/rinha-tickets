class ValidationError < ApiError
  def initialize(errors)
    super(
      message: "Os dados informados são inválidos.",
      code: "VALIDATION_ERROR",
      status: 422,
      errors: errors
    )
  end
end
