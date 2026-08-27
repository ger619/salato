class PaymentsController < ApplicationController
  skip_forgery_protection only: :webhook

  def callback
    reference = params[:reference]

    if reference.blank?
      redirect_to root_path,
                  alert: 'Payment reference missing.'
      return
    end

    order = Order.find_by(reference: reference)

    unless order
      redirect_to root_path,
                  alert: 'Order not found.'
      return
    end

    result = Paystack::Client.new.verify_transaction(reference)

    transaction = result.fetch('data')

    unless transaction['status'] == 'success'
      redirect_to event_path(order.event.slug),
                  alert: 'Payment was not successful.'
      return
    end

    PaymentFulfillment.call(
      order: order,
      transaction: transaction
    )

    redirect_to ticket_path(order.tickets.first),
                notice: 'Payment successful. Your ticket is ready.'
  rescue StandardError => e
    Rails.logger.error(
      "Payment callback failed: #{e.class}: #{e.message}"
    )

    redirect_to event_path(order&.event&.slug || ''),
                alert: 'We could not confirm your payment yet.'
  end

  def webhook
    raw_body = request.raw_post

    signature = request.headers['x-paystack-signature']

    unless valid_signature?(raw_body, signature)
      head :unauthorized
      return
    end

    payload = JSON.parse(raw_body)

    if payload['event'] == 'charge.success'
      transaction = payload.fetch('data')

      order = Order.find_by(
        reference: transaction['reference']
      )

      if order
        PaymentFulfillment.call(
          order: order,
          transaction: transaction
        )
      end
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  rescue StandardError => e
    Rails.logger.error(
      "Paystack webhook error: #{e.class}: #{e.message}"
    )

    head :internal_server_error
  end

  private

  def valid_signature?(body, signature)
    return false if signature.blank?

    expected = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('SHA512'),
      ENV.fetch('PAYSTACK_SECRET_KEY'),
      body
    )

    ActiveSupport::SecurityUtils.secure_compare(
      expected,
      signature
    )
  end
end
