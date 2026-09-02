class Client < ApplicationRecord
  has_many :users, dependent: :nullify
  has_one_attached :logo
  has_rich_text :description
end
