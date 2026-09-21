class TicketType < ApplicationRecord
  belongs_to :event

  has_many :orders, dependent: :restrict_with_exception
  has_many :tickets, dependent: :restrict_with_exception

  validates :name, presence: true
  # 0 means a free ticket: no Paystack, the ticket is issued straight away.
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :on_sale, -> { where(active: true) }

  def available_quantity
    quantity.to_i - reserved_quantity.to_i - sold_quantity.to_i
  end

  def sold_out?
    available_quantity <= 0
  end

  def free?
    price.to_d.zero?
  end

  # Free tickets don't need a Paystack subaccount; paid ones do.
  def purchasable?
    free? || event.payouts_ready?
  end
end
