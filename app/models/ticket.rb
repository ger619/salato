class Ticket < ApplicationRecord
  belongs_to :event
  belongs_to :order
  belongs_to :ticket_type
end
