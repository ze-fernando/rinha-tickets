class Ticket < ApplicationRecord
  enum :status, {
    open: TicketStatus::OPEN,
    in_progress: TicketStatus::IN_PROGRESS,
    closed: TicketStatus::CLOSED
  }, validate: true

  validates :title,
            presence: true,
            uniqueness: true,
            length: { maximum: 255 }

  validates :description, presence: true

  validates :sector,
            presence: true,
            length: { maximum: 255 }
end
