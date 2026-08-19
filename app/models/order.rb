class Order < ApplicationRecord
  belongs_to :event
  belongs_to :ticket_type
end
