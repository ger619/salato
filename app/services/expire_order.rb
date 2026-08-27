class ExpireOrder
  def self.call(order)
    new(order).call
  end

  def initialize(order)
    @order = order
  end

  def call
    ActiveRecord::Base.transaction do
      order = Order.lock.find(@order.id)

      return unless order.pending?

      ticket_type = TicketType.lock.find(order.ticket_type_id)

      ticket_type.update!(
        reserved_quantity: [
          ticket_type.reserved_quantity - order.quantity,
          0
        ].max
      )

      order.update!(
        status: 'expired'
      )
    end
  end
end
