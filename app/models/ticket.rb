class Ticket < ApplicationRecord
  belongs_to :event
  belongs_to :order
  belongs_to :ticket_type

  STATUSES = %w[valid checked_in cancelled].freeze
  def self.filtered(params)
    params = params.to_h.with_indifferent_access
    scope = params[:status].present? ? where(status: params[:status]) : where(status: STATUSES)
    scope = scope.where(ticket_type_id: params[:ticket_type_id]) if params[:ticket_type_id].present?
    scope
  end

  delegate :customer_phone, :customer_name, to: :order, allow_nil: true

  scope :with_phone, -> { joins(:order).where.not(orders: { customer_phone: [nil, ''] }) }

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
