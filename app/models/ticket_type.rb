class TicketType < ApplicationRecord
  belongs_to :event

  has_many :orders, dependent: :restrict_with_exception
  has_many :tickets, dependent: :restrict_with_exception

  validates :name, presence: true
  validates :price, presence: true, numericality: { greater_than: 0 }
  validates :quantity, presence: true, numericality: { greater_than: 0 }

  scope :active, -> { where(active: true) }
  scope :on_sale, -> { where(active: true) }

  def available_quantity
    quantity.to_i - reserved_quantity.to_i - sold_quantity.to_i
  end

  def sold_out?
    available_quantity <= 0
  end
end
