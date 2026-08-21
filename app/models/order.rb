class Order < ApplicationRecord
  belongs_to :event
  belongs_to :ticket_type

  has_many :tickets, dependent: :destroy

  STATUSES = %w[pending paid failed cancelled expired].freeze

  validates :references, presence: true, uniqueness: true
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
end
