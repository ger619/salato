class PaymentFulfillment
  def self.call(order:, transaction:)
    new(
      order: order,
      transaction: transaction
    ).call
  end

  def initialize(order:, transaction:)
    @order = order
    @transaction = transaction
  end

  def call
    ActiveRecord::Base.transaction do
      order = Order.lock.find(@order.id)

      return order if order.paid?

      validate_payment_amount!(order)

      ticket_type = TicketType.lock.find(
        order.ticket_type_id
      )

      raise 'Invalid ticket reservation.' if ticket_type.reserved_quantity < order.quantity

      ticket_type.update!(
        reserved_quantity:
          ticket_type.reserved_quantity - order.quantity,

        sold_quantity:
          ticket_type.sold_quantity + order.quantity
      )

      order.update!(
        status: 'paid',
        paid_at: Time.current
      )

      create_tickets!(order)

      order
    end
  end

  private

  def validate_payment_amount!(order)
    expected = Paystack::Money.to_subunit(
      order.total_amount
    )

    actual = @transaction.fetch('amount').to_i

    return if expected == actual

    raise(
      "Payment amount mismatch. Expected #{expected}, received #{actual}"
    )
  end

  def create_tickets!(order)
    return if order.tickets.exists?

    order.quantity.times do
      Ticket.create!(
        event: order.event,
        order: order,
        ticket_type: order.ticket_type,
        ticket_number: TicketNumberGenerator.generate,
        attendee_name: order.customer_name,
        attendee_email: order.customer_email,
        qr_token: SecureRandom.urlsafe_base64(32),
        status: 'valid'
      )
    end
  end
end
