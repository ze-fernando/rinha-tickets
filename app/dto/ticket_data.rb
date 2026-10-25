class TicketData
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :title
  attribute :description
  attribute :sector
  attribute :status, default: TicketStatus::OPEN

  validates :title,
            presence: { message: "O título é obrigatório." }

  validates :title,
            length: {
              maximum: 255,
              message: "O título deve ter no máximo 255 caracteres."
            },
            if: -> { title.is_a?(String) }

  validates :description,
            presence: { message: "A descrição é obrigatória." }

  validates :sector,
            presence: { message: "O setor é obrigatório." }

  validates :sector,
            length: {
              maximum: 255,
              message: "O setor deve ter no máximo 255 caracteres."
            },
            if: -> { sector.is_a?(String) }

  validates :status,
            inclusion: {
              in: TicketStatus::ALL,
              message: "O status deve ser open, in_progress ou closed."
            },
            if: -> { status.is_a?(String) }

  validate :text_fields_must_be_strings

  def self.from_params(params)
    new(
      title: params[:title],
      description: params[:description],
      sector: params[:sector],
      status: params[:status] || TicketStatus::OPEN
    )
  end

  def status=(value)
    super(value.is_a?(String) ? value.downcase : value)
  end

  private

  def text_fields_must_be_strings
    {
      title: "O título deve ser um texto.",
      description: "A descrição deve ser um texto.",
      sector: "O setor deve ser um texto.",
      status: "O status deve ser open, in_progress ou closed."
    }.each do |attribute, message|
      value = public_send(attribute)
      errors.add(attribute, message) if value.present? && !value.is_a?(String)
    end
  end
end
