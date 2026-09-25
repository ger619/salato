class BroadcastDelivery < ApplicationRecord
  belongs_to :broadcast
  belongs_to :ticket
end
