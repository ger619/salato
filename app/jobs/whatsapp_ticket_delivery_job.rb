# app/jobs/whatsapp_ticket_delivery_job.rb
#
# Sends the order's ticket PDF to order.customer_phone over WhatsApp once the
# payment is confirmed. Enqueued by PaymentFulfillment, after the fulfilment
# transaction has committed.
#
# One message, not two. By default it is a TEXT message with a link to the
# buyer's tickets page, where they can download the PDF.
#
# Why not the PDF itself? Since 17 Sep 2026 OpenWA (whatsapp-web.js 1.34.7)
# fails every media send with a 500 ("Data passed to getter must include an id
# property"), while text sends still work. Once OpenWA ships an image with the
# fix, set WHATSAPP_SEND_PDF=true in config/deploy.yml to go back to sending
# the PDF with a caption.
class WhatsappTicketDeliveryJob < ApplicationJob
  queue_as :default

  retry_on Whatsapp::Client::Unavailable, wait: :polynomially_longer, attempts: 8
  retry_on Whatsapp::Client::SessionNotReady, wait: 1.minute, attempts: 10

  discard_on(ActiveJob::DeserializationError)

  discard_on(Whatsapp::Client::Error) do |job, error|
    Rails.logger.error("[WhatsApp] order #{job.arguments.first}: rejected by gateway — #{error.message}")
  end

  # Do NOT retry: the message may already be sitting in the buyer's chat.
  # Read the chat (or the dashboard) before resending by hand.
  discard_on(Whatsapp::Client::AmbiguousSend) do |job, error|
    Rails.logger.error("[WhatsApp] order #{job.arguments.first}: outcome unknown, NOT retrying — #{error.message}")
  end

  def perform(order_id)
    return unless Whatsapp::Client.configured?

    order = Order.find_by(id: order_id)

    return if order.blank?
    return unless order.paid?
    return if order.whatsapp_sent_at.present?

    chat_id = Whatsapp::Phone.to_jid(order.customer_phone)

    if chat_id.blank?
      Rails.logger.warn("[WhatsApp] order #{order.reference}: #{order.customer_phone.inspect} is not a usable number — skipped")
      return
    end

    # Same ordering the mailer and the download action use, so "2 of 3" means
    # the same ticket everywhere.
    tickets = order.tickets
      .includes(:event, :ticket_type, :order)
      .order(:ticket_number)
      .to_a

    if tickets.empty?
      Rails.logger.warn("[WhatsApp] order #{order.reference}: no tickets on the order — skipped")
      return
    end

    client = Whatsapp::Client.new

    if send_pdf?
      client.send_document(
        chat_id: chat_id,
        base64: Base64.strict_encode64(TicketPdf.generate_batch(tickets)),
        filename: "#{order.reference}-tickets.pdf",
        caption: caption(order, tickets)
      )
    else
      client.send_text(chat_id: chat_id, text: link_message(order, tickets))
    end

    # update_column, not update!: this is a delivery receipt, not a state
    # change, and it must not fire validations or touch updated_at.
    order.update_column(:whatsapp_sent_at, Time.current)
  end

  private

  def send_pdf?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('WHATSAPP_SEND_PDF', 'false'))
  end

  # Same page the confirmation email links to. The order id is a UUID, so
  # the link can't be guessed.
  def tickets_url(order)
    Rails.application.routes.url_helpers.event_order_url(
      order.event,
      order,
      **Rails.application.config.action_mailer.default_url_options.to_h
    )
  end

  def link_message(order, tickets)
    event = order.event

    <<~TEXT.strip
      Hi #{first_name(order)} 👋

      *#{event.name}*
      #{event.start_at.strftime('%A %-d %B · %-I:%M %p')}
      #{event.venue.presence || 'Venue to be announced'}

      Your #{ticket_word(tickets)} ready. Open this link to view and download them:
      #{tickets_url(order)}

      Show the QR code at the gate — one entry each.

      Ref: #{order.reference}
      — Salato
    TEXT
  end

  def caption(order, tickets)
    event = order.event

    <<~TEXT.strip
      Hi #{first_name(order)} 👋

      *#{event.name}*
      #{event.start_at.strftime('%A %-d %B · %-I:%M %p')}
      #{event.venue.presence || 'Venue to be announced'}

      Your #{ticket_word(tickets)} attached. Show the QR code at the gate — one entry each.

      Ref: #{order.reference}
      — Salato
    TEXT
  end

  def first_name(order)
    order.customer_name.to_s.split.first.presence || 'there'
  end

  def ticket_word(tickets)
    tickets.one? ? 'ticket is' : "#{tickets.size} tickets are"
  end
end
