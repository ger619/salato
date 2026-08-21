class Ticket < ApplicationRecord
  belongs_to :event
  belongs_to :order
  belongs_to :ticket_type

  has_one_attached :qr_token


  STATUSES = %w[valid checked_in cancelled].freeze

  validates :ticket_number, presence: true, uniqueness: true
  validates :qr_token, presence: true, uniqueness: true
  validates :attendee_name, presence: true
  validates :status, inclusion: { in: STATUSES }

  def valid_ticket?
    status == 'valid'
  end

  def checked_in?
    status == 'checked_in'
  end
end
