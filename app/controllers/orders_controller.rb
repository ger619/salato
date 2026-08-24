class OrdersController < ApplicationController
  before_action :set_event, only: %i[new create show download initialize_payment]
  before_action :set_order, only: %i[show download]

  def new
    @ticket_type = @event.ticket_types.find(params[:ticket_type_id])

    @order = Order.new(
      quantity: 1,
      ticket_type: @ticket_type
    )
  end

  def create
    ticket_type_id = order_params[:ticket_type_id]

    if ticket_type_id.blank?
      redirect_to event_path(@event.slug),
                  alert: 'Please select a ticket type.'
      return
    end

    @ticket_type = @event.ticket_types.find(ticket_type_id)

    quantity = order_params[:quantity].to_i

    if quantity <= 0
      @order = Order.new(order_params)

      @order.errors.add(
        :quantity,
        'must be greater than zero'
      )

      render :new, status: :unprocessable_entity
      return
    end

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
        total_price: total,
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
      redirect_to initialize_payment_event_order_path(@event, @order)
    else
      render :new, status: :unprocessable_entity
    end
  end

  # Every ticket in the order. This is where the callback lands, so a
  # buyer who bought three tickets sees three, not just the first one.
  def show
    @tickets = ordered_tickets

    return if @tickets.any?

    redirect_to event_path(@event.slug),
                alert: 'This order does not have any tickets yet.'
  end

  # All of the order's tickets as one multi-page PDF, one ticket per page.
  def download
    tickets = ordered_tickets

    if tickets.empty?
      redirect_to event_path(@event.slug),
                  alert: 'This order does not have any tickets yet.'
      return
    end

    send_data(
      TicketPdf.generate_batch(tickets),
      filename: "#{@order.reference}-tickets.pdf",
      type: 'application/pdf',
      disposition: 'attachment'
    )
  end

  def initialize_payment
    @order = @event.orders.find(params[:id])

    unless @order.pending?
      redirect_to event_order_path(@event, @order)
      return
    end

    if @order.expires_at < Time.current
      ExpireOrder.call(@order)

      redirect_to event_path(@event.slug),
                  alert: 'This order has expired.'

      return
    end

    response = Paystack::Client.new.initialize_transaction(
      email: @order.customer_email,
      amount: Paystack::Money.to_subunit(@order.total_price),
      reference: @order.reference,
      callback_url: payment_callback_url(
        reference: @order.reference
      ),
      metadata: {
        order_id: @order.id,
        event_id: @order.event_id
      }
    )

    redirect_to response.dig('data', 'authorization_url'), allow_other_host: true
  end

  private

  def set_event
    @event = Event.find_by!(slug: params[:event_slug])
  end

  def set_order
    @order = @event.orders.find(params[:id])
  end

  # Stable order so "ticket 2 of 3" means the same thing on the web page,
  # in the PDF, and on a reload.
  def ordered_tickets
    @order
      .tickets
      .includes(:event, :ticket_type, :order)
      .order(:ticket_number)
      .to_a
  end

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
