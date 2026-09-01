class Ticket < ApplicationRecord
  belongs_to :event
  belongs_to :order
  belongs_to :ticket_type

  STATUSES = %w[valid checked_in cancelled].freeze

  validates :ticket_number, presence: true, uniqueness: true
  validates :attendee_name, presence: true
  validates :status, inclusion: { in: STATUSES }
  belongs_to :checked_in_by, class_name: 'User', optional: true

  def valid_ticket?
    status == 'valid'
  end

  def checked_in?
    status == 'checked_in'
  end
end
