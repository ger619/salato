class PaymentsController < ApplicationController
  skip_forgery_protection only: :webhook

  PENDING_STATUSES = %w[pending ongoing processing queued].freeze

  # Paystack sends the buyer's browser here after a card payment.
  # The reference is the attempt reference, e.g. "EVT-…-CARD".
  def callback
    reference = params[:reference].to_s

    if reference.blank?
      redirect_to root_path, alert: 'Payment reference missing.'
      return
    end

    order = Order.for_paystack_reference(reference)

    unless order
      redirect_to root_path, alert: 'We could not find that order.'
      return
    end

    # The webhook may have fulfilled the order before the buyer got back.
    if order.paid?
      redirect_to event_order_path(order.event, order),
                  notice: 'Payment successful. Your tickets are ready.'
      return
    end

    transaction = Paystack::Client.new.verify_transaction(reference).fetch('data')

    case transaction['status']
    when 'success'
      fulfil(order, transaction)

      redirect_to event_order_path(order.event, order),
                  notice: 'Payment successful. Your tickets are ready.'
    when *PENDING_STATUSES
      redirect_to event_path(order.event.slug),
                  notice: "Your payment is still processing. We'll email your tickets as soon as it clears."
    else
      redirect_to pay_event_order_path(order.event, order),
                  alert: 'That payment did not go through. Please try again.'
    end
  rescue StandardError => e
    Rails.logger.error(
      "Payment callback failed for #{reference.presence || 'unknown reference'}: #{e.class}: #{e.message}"
    )

    fallback = order&.event ? event_path(order.event.slug) : root_path

    redirect_to fallback,
                alert: 'We could not confirm your payment yet. If you were charged, your tickets will be emailed shortly.'
  end

  # Paystack calls this server-to-server for every payment, including
  # M-Pesa and Airtel Money prompts approved on the buyer's phone.
  def webhook
    raw_body = request.raw_post

    unless valid_signature?(raw_body, request.headers['x-paystack-signature'])
      head :unauthorized
      return
    end

    payload = JSON.parse(raw_body)

    if payload['event'] == 'charge.success'
      transaction = payload.fetch('data')
      order = Order.for_paystack_reference(transaction['reference'])

      if order
        fulfil(order, transaction)
      else
        Rails.logger.warn(
          "Paystack webhook: no order for reference #{transaction['reference']}"
        )
      end
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue StandardError => e
    Rails.logger.error("Paystack webhook error: #{e.class}: #{e.message}")

    # A non-2xx response makes Paystack retry later.
    head :internal_server_error
  end

  private

  # Idempotent and locked inside PaymentFulfillment, so the callback, the
  # webhook and the pay page's status check can all call it safely.
  def fulfil(order, transaction)
    PaymentFulfillment.call(order: order, transaction: transaction)
  end

  def valid_signature?(body, signature)
    return false if signature.blank?

    expected = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('SHA512'),
      ENV.fetch('PAYSTACK_SECRET_KEY'),
      body
    )

    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
end
