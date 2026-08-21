class OrdersController < ApplicationController
  def new
    @event = Event.find_by!(slug: params[:event_slug])
    @ticket_type = @event.ticket_types.find(params[:ticket_type_id])

    @order = Order.new(
      quantity: 1,
      ticket_type: @ticket_type
    )
  end

  def create
    @event = Event.find_by!(slug: params[:event_slug])

    @ticket_type = @event.ticket_types.find(
      order_params[:ticket_type_id]
    )

    quantity = order_params[:quantity].to_i

    raise ArgumentError, 'Quantity must be greater than zero.' if quantity <= 0

    @order = nil

    ActiveRecord::Base.transaction do
      locked_ticket_type = TicketType
        .lock
        .find(@ticket_type.id)

      if locked_ticket_type.available_quantity < quantity
        @order = Order.new(order_params)
        @order.errors.add(
          :quantity,
          'not enough tickets are available'
        )

        raise ActiveRecord::Rollback
      end

      total = locked_ticket_type.price * quantity

      @order = Order.create!(
        event: @event,
        ticket_type: locked_ticket_type,
        reference: OrderReference.generate,
        customer_name: order_params[:customer_name],
        customer_email: order_params[:customer_email],
        customer_phone: order_params[:customer_phone],
        quantity: quantity,
        unit_price: locked_ticket_type.price,
        total_amount: total,
        currency: ENV.fetch('PAYSTACK_CURRENCY', 'KES'),
        status: 'pending',
        expires_at: 15.minutes.from_now
      )

      locked_ticket_type.update!(
        reserved_quantity:
          locked_ticket_type.reserved_quantity + quantity
      )
    end

    if @order&.persisted?
      redirect_to initialize_payment_order_path(@order)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def initialize_payment
    @order = Order.find(params[:id])

    unless @order.pending?
      redirect_to event_path(@order.event.slug)
      return
    end

    if @order.expires_at < Time.current
      ExpireOrder.call(@order)

      redirect_to event_path(@order.event.slug),
                  alert: 'This order has expired.'

      return
    end

    response = Paystack::Client.new.initialize_transaction(
      email: @order.customer_email,
      amount: Paystack::Money.to_subunit(@order.total_amount),
      reference: @order.reference,
      callback_url: payment_callback_url(
        reference: @order.reference
      ),
      metadata: {
        order_id: @order.id,
        event_id: @order.event_id
      }
    )

    redirect_to response.dig('data', 'authorization_url'),
                allow_other_host: true
  end

  private

  def order_params
    params.require(:order).permit(
      :ticket_type_id,
      :customer_name,
      :customer_email,
      :customer_phone,
      :quantity
    )
  end
end
