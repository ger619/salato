# app/mailers/salato_mailer.rb
class SalatoMailer < ApplicationMailer
  # Mailers do not load app helpers automatically, and the template reuses
  # ticket_status_pill so the email, the web card and the PDF agree on what
  # each status is called.
  helper :tickets

  def ticket_confirmation(order)
    @order = order
    @event = order.event

    # Same ordering OrdersController#download and #show use, so "2 of 3"
    # means the same ticket in the email, on the page and in the PDF.
    @tickets = order.tickets
      .includes(:event, :ticket_type, :order)
      .order(:ticket_number)
      .to_a

    # No tickets means fulfilment did not finish. Returning before `mail`
    # yields a NullMail: nothing sends, nothing raises.
    if @tickets.empty?
      Rails.logger.warn("[SalatoMailer] order #{order.reference} has no tickets — skipping confirmation")
      return
    end

    # The existing member route on orders — public, so it works from an
    # inbox with no session.
    @download_url = download_event_order_url(@event, @order)

    # Same file the download action sends, same filename.
    attachments["#{@order.reference}-tickets.pdf"] = {
      mime_type: 'application/pdf',
      content: TicketPdf.generate_batch(@tickets)
    }

    mail(
      to: @order.customer_email,
      subject: "Your #{ticket_word} for #{@event.name}"
    )
  end

  private

  def ticket_word
    @tickets.one? ? 'ticket' : "#{@tickets.size} tickets"
  end
end
