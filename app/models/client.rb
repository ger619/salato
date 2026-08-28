class Client < ApplicationRecord
  has_many :users, dependent: :nullify
  has_one_attached :logo
end
