# app/jobs/whatsapp_ticket_delivery_job.rb
#
# Sends the order's tickets to order.customer_phone over WhatsApp once the
# payment is confirmed. Enqueued by PaymentFulfillment, after the fulfilment
# transaction has committed.
#
# Mirrors the confirmation email: ONE WhatsApp message that IS the tickets
# PDF (the same file the email attaches), with the event details as its
# caption. No links — the buyer taps the PDF in the chat to open or save it.
# One message, not two, so a retry can never leave a duplicate greeting.
#
# Needs OpenWA on the Baileys engine (config/deploy.yml, accessories.openwa):
# on whatsapp-web.js 1.34.7 every PDF/image send has failed since WhatsApp
# Web's 17 Sep 2026 update ("Data passed to getter must include an id
# property").
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

    # Same PDF and same filename as the email attachment. Sent as a document
    # (application/pdf), so WhatsApp shows it as a PDF file the buyer can open
    # and save straight from the chat.
    Whatsapp::Client.new.send_document(
      chat_id: chat_id,
      base64: Base64.strict_encode64(TicketPdf.generate_batch(tickets)),
      filename: "#{order.reference}-tickets.pdf",
      mimetype: 'application/pdf',
      caption: caption(order, tickets)
    )

    # update_column, not update!: this is a delivery receipt, not a state
    # change, and it must not fire validations or touch updated_at.
    order.update_column(:whatsapp_sent_at, Time.current)
  end

  private

  # WhatsApp formatting: *bold*. Kept short — it is read on a phone.
  def caption(order, tickets)
    event = order.event

    <<~TEXT.strip
      Hi #{first_name(order)} 👋

      *#{event.name}*
      📅 #{event.start_at.strftime('%A %-d %B · %-I:%M %p')}
      📍 #{event.venue.presence || 'Venue to be announced'}
      🎟️ #{tickets.size} × #{tickets.first.ticket_type&.name || 'Ticket'}

      Your #{ticket_word(tickets)} in the PDF above#{' — one page per ticket' if tickets.size > 1}. Show the QR code at the gate — one entry each.

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
