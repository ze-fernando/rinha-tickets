class ApiError < StandardError
  attr_reader :code, :status, :errors

  def initialize(message:, code:, status:, errors: nil)
    super(message)

    @code = code
    @status = status
    @errors = errors
  end

  def as_json(*)
    payload = { code: code, message: message }
    payload[:errors] = errors if errors.present?
    payload
  end
end
