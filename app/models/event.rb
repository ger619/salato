class Event < ApplicationRecord
  has_many :ticket_types, dependent: :destroy
  has_many :orders, dependent: :destroy
  has_many :tickets, dependent: :destroy

  validates :name, presence: true
  validates :start_at, presence: true
  validates :slug, presence: true

  scope :active, -> { where(active: true) }
end
