class OrdersController < ApplicationController
  PAYABLE_ACTIONS = %i[pay initialize_payment start_card charge_mobile].freeze
  ORDER_ACTIONS = (%i[show download payment_status] + PAYABLE_ACTIONS).freeze

  # What the buyer picks → Paystack's provider code.
  MOBILE_PROVIDERS = { 'mpesa' => 'mpesa', 'airtel' => 'atl' }.freeze

  # Paystack statuses that mean "the buyer still has something to do".
  AWAITING_BUYER = %w[pay_offline send_otp send_pin pending ongoing processing queued].freeze

  before_action :set_event, only: %i[new create] + ORDER_ACTIONS
  before_action :set_order, only: ORDER_ACTIONS
  before_action :ensure_sales_open, only: %i[new create] + PAYABLE_ACTIONS
  before_action :ensure_payouts_configured, only: %i[new create] + PAYABLE_ACTIONS
  before_action :ensure_order_payable, only: PAYABLE_ACTIONS

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
      @order.errors.add(:quantity, 'must be greater than zero')

      render :new, status: :unprocessable_entity
      return
    end

    @order = nil

    ActiveRecord::Base.transaction do
      locked_ticket_type = TicketType.lock.find(@ticket_type.id)

      if locked_ticket_type.available_quantity < quantity
        @order = Order.new(order_params)
        @order.errors.add(:quantity, 'not enough tickets are available')

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
        reserved_quantity: locked_ticket_type.reserved_quantity + quantity
      )
    end

    if @order&.persisted? && @order.free?
      # Free ticket: skip Paystack and issue the tickets right now.
      PaymentFulfillment.call(order: @order)

      redirect_to event_order_path(@event, @order),
                  notice: 'You are in! Your free tickets have been emailed to you.'
    elsif @order&.persisted?
      redirect_to pay_event_order_path(@event, @order)
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

  # Salato-branded payment page: M-Pesa, Airtel Money or card.
  # No Paystack call happens until the buyer picks a method and taps pay.
  def pay; end

  # Card only: starts (once) a card-only Paystack transaction for the popup.
  def start_card
    access_code = ensure_card_transaction!

    render json: {
      access_code: access_code,
      callback_url: payment_callback_url(reference: card_reference)
    }
  rescue Paystack::Error => e
    log_payment_error(e)
    render json: { error: card_error_message(e) }, status: :bad_gateway
  rescue StandardError => e
    log_payment_error(e)
    render json: { error: "We couldn't open card payment. Please try again." },
           status: :bad_gateway
  end

  # M-Pesa / Airtel Money: sends the prompt straight to the buyer's phone.
  # Each attempt gets a fresh reference so the buyer can retry.
  def charge_mobile
    provider = MOBILE_PROVIDERS[params[:provider].to_s]
    phone = Paystack::Phone.kenyan(params[:phone])

    unless provider
      render json: { error: 'Choose M-Pesa or Airtel Money.' }, status: :unprocessable_entity
      return
    end

    unless phone
      render json: { error: 'Enter a valid Kenyan phone number, e.g. 0712 345 678.' },
             status: :unprocessable_entity
      return
    end

    reference = "#{@order.reference}-MM#{SecureRandom.hex(4).upcase}"
    @order.update!(paystack_reference: reference)

    data = Paystack::Client.new.charge_mobile_money(
      email: @order.customer_email,
      amount: Paystack::Money.to_subunit(@order.total_price),
      phone: phone,
      provider: provider,
      reference: reference,
      subaccount: @event.client&.paystack_subaccount_code,
      metadata: payment_metadata
    ).fetch('data')

    case data['status']
    when 'success'
      PaymentFulfillment.call(order: @order, transaction: data)
      render json: paid_json
    when *AWAITING_BUYER
      render json: {
        status: 'pending',
        message: data['display_text'].presence || default_prompt_message(phone)
      }
    else
      # "failed", "reversed", "abandoned", or anything new Paystack adds.
      # Paystack puts the reason in data.message for a failed charge.
      Rails.logger.warn(
        "M-Pesa charge #{reference} came back #{data['status'].inspect}: #{data.to_json}"
      )

      render json: { error: charge_failure_message(data) },
             status: :unprocessable_entity
    end
  rescue Paystack::Error => e
    log_payment_error(e)
    render json: { error: mobile_error_message(e) }, status: :bad_gateway
  rescue StandardError => e
    log_payment_error(e)
    render json: { error: "We couldn't send the payment prompt. Check the number and try again." },
           status: :bad_gateway
  end

  # Polled by the pay page while the buyer approves on their phone.
  # The webhook normally fulfils the order first; verifying here also
  # covers local development, where Paystack can't reach the webhook.
  def payment_status
    return render(json: paid_json) if @order.paid?

    unless @order.pending?
      render json: { status: 'closed', redirect_url: event_path(@event.slug) }
      return
    end

    if @order.paystack_reference.present?
      data = Paystack::Client.new.verify_transaction(@order.paystack_reference).fetch('data')

      case data['status']
      when 'success'
        PaymentFulfillment.call(order: @order, transaction: data)
        return render(json: paid_json)
      when 'failed', 'reversed'
        return render(json: {
                        status: 'failed',
                        error: charge_failure_message(data)
                      })
      end
    end

    render json: { status: 'pending' }
  rescue StandardError => e
    log_payment_error(e)
    render json: { status: 'pending' }
  end

  # Fallback when the popup script can't load: Paystack's hosted card page
  # for the same card transaction.
  def initialize_payment
    redirect_to "https://checkout.paystack.com/#{ensure_card_transaction!}",
                allow_other_host: true
  rescue StandardError => e
    log_payment_error(e)
    redirect_to event_path(@event.slug),
                alert: "We couldn't start your payment. Please try again in a moment."
  end

  private

  def set_event
    @event = Event.find_by!(slug: params[:event_slug])
  end

  def set_order
    @order = @event.orders.find(params[:id])
  end

  # No new orders, and no paying for pending ones, once the event is over.
  def ensure_sales_open
    return unless @event.sales_closed?

    bounce event_path(@event.slug), 'This event has ended. Tickets are no longer on sale.'
  end

  # Paid tickets need the organiser's Paystack subaccount. Free tickets don't,
  # so an organiser can host a free event without finishing payout setup.
  def ensure_payouts_configured
    return if @event.payouts_ready?
    return if requested_ticket_type&.free?
    return if @order&.free?

    bounce event_path(@event.slug),
           'Tickets for this event are not on sale yet. The organiser still needs to finish their payout setup.'
  end

  # Only pending, unexpired orders can be paid.
  def ensure_order_payable
    # A free order should never reach Paystack. If one is somehow still
    # pending (e.g. fulfilment crashed), finish it here instead.
    if @order.free? && @order.pending?
      PaymentFulfillment.call(order: @order)
      @order.reload
    end

    if @order.paid?
      request.format.json? ? render(json: paid_json) : redirect_to(event_order_path(@event, @order))
      return
    end

    unless @order.pending?
      bounce event_path(@event.slug), 'This order can no longer be paid.'
      return
    end

    return unless @order.expires_at < Time.current

    ExpireOrder.call(@order)
    bounce event_path(@event.slug), 'This order has expired.'
  end

  # Redirect for normal page loads; JSON for the pay page's fetch calls.
  def bounce(path, message)
    if request.format.json?
      render json: { status: 'closed', error: message, redirect_url: path },
             status: :unprocessable_entity
    else
      redirect_to path, alert: message
    end
  end

  # The ticket type being ordered, on the new/create pages.
  def requested_ticket_type
    id = params[:ticket_type_id].presence || params.dig(:order, :ticket_type_id).presence
    return nil unless id

    @event.ticket_types.find_by(id: id)
  end

  def card_reference
    "#{@order.reference}-CARD"
  end

  # Which channels the card transaction may use. Forcing %w[card] fails with
  # "No active channel to process transaction" whenever card isn't enabled on
  # the live Paystack account. Set PAYSTACK_CARD_CHANNELS to a comma-separated
  # list to change it, or to "any" to let Paystack offer whatever is enabled.
  def card_channels
    configured = ENV.fetch('PAYSTACK_CARD_CHANNELS', 'card')

    return nil if configured.blank? || configured.casecmp('any').zero?

    configured.split(',').map(&:strip).reject(&:blank?)
  end

  # Started once and kept on the order; the row lock stops a double click
  # from initialising twice.
  def ensure_card_transaction!
    @order.with_lock do
      if @order.paystack_access_code.blank?
        response = Paystack::Client.new.initialize_transaction(
          email: @order.customer_email,
          amount: Paystack::Money.to_subunit(@order.total_price),
          reference: card_reference,
          callback_url: payment_callback_url(reference: card_reference),
          subaccount: @event.client&.paystack_subaccount_code,
          channels: card_channels,
          metadata: payment_metadata
        )

        # Keep the reference too, so payment_status can verify a card attempt
        # instead of re-checking a stale mobile money reference.
        @order.update!(
          paystack_access_code: response.dig('data', 'access_code'),
          paystack_reference: card_reference
        )
      end
    end

    @order.paystack_access_code
  end

  def payment_metadata
    client = @event.client

    {
      order_id: @order.id,
      event_id: @order.event_id,
      client_id: client&.id,
      subaccount_code: client&.paystack_subaccount_code
    }.compact
  end

  def paid_json
    { status: 'paid', redirect_url: event_order_path(@event, @order) }
  end

  def default_prompt_message(phone)
    name = params[:provider] == 'airtel' ? 'Airtel Money' : 'M-Pesa'

    "We've sent a #{name} prompt to #{phone}. Enter your PIN to pay."
  end

  # Paystack's own wording is usually clearer than anything generic
  # ("Insufficient funds", "Request cancelled by user").
  def charge_failure_message(data)
    data['message'].presence ||
      data['gateway_response'].presence ||
      'The payment was declined. Please try again.'
  end

  def mobile_error_message(error)
    if error.reason.to_s.match?(/no active channel/i)
      'Mobile money is not switched on for this event yet. Please try card, or contact the organiser.'
    else
      "We couldn't send the payment prompt: #{error.reason}"
    end
  end

  def card_error_message(error)
    if error.reason.to_s.match?(/no active channel/i)
      'Card payment is not available for this event yet. Please pay with M-Pesa or Airtel Money.'
    else
      "We couldn't open card payment: #{error.reason}"
    end
  end

  # Logs the full Paystack body, which is where the real reason lives.
  def log_payment_error(error)
    detail = error.is_a?(Paystack::Error) ? error.to_log : error.message

    Rails.logger.error(
      "Paystack payment error for order #{@order&.reference}: #{error.class}: #{detail}"
    )
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
