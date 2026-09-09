class Order < ApplicationRecord
  belongs_to :event
  belongs_to :ticket_type

  has_many :tickets, dependent: :destroy

  STATUSES = %w[pending paid failed cancelled expired].freeze

  validates :reference, presence: true, uniqueness: true
  validates :customer_name, presence: true
  validates :customer_email, presence: true
  validates :customer_phone, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }

  def paid?
    status == 'paid'
  end

  def pending?
    status == 'pending'
  end

  validate :event_payouts_ready, on: :create

  private

  def event_payouts_ready
    return if event.blank? || event.payouts_ready?

    errors.add(:base, 'This event is not set up to receive payments yet.')
  end
end
