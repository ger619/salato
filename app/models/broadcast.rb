# app/models/broadcast.rb
class Broadcast < ApplicationRecord
  belongs_to :event
  belongs_to :user
  has_many :deliveries, class_name: 'BroadcastDelivery', dependent: :destroy

  validates :message, presence: true, length: { maximum: 1000 }

  def render_for(ticket)
    message.gsub('{{name}}', ticket.order.customer_name.to_s.split.first.to_s)
      .gsub('{{event}}', event.name)
  end
end
