require 'prawn'
require 'rqrcode'

class TicketPdf
  def self.generate(ticket)
    new(ticket).generate
  end

  def initialize(ticket)
    @ticket = ticket
  end

  def generate
    Prawn::Document.new(
      page_size: 'A6',
      margin: 40
    ) do |pdf|
      pdf.text(
        @ticket.event.name,
        size: 24,
        style: :bold
      )

      pdf.move_down 10

      pdf.text(
        'EVENT TICKET',
        size: 14
      )

      pdf.move_down 30

      pdf.text(
        'ATTENDEE',
        size: 10
      )

      pdf.text(
        @ticket.attendee_name,
        size: 22,
        style: :bold
      )

      pdf.move_down 20

      pdf.text(
        'TICKET NUMBER',
        size: 10
      )

      pdf.text(
        @ticket.ticket_number,
        size: 18,
        style: :bold
      )

      pdf.move_down 20

      pdf.text(
        'TICKET TYPE',
        size: 10
      )

      pdf.text(
        @ticket.ticket_type.name,
        size: 16
      )

      pdf.move_down 20

      pdf.text(
        'VENUE',
        size: 10
      )

      pdf.text(
        @ticket.event.venue.to_s,
        size: 14
      )

      pdf.move_down 20

      pdf.text(
        'DATE',
        size: 10
      )

      pdf.text(
        @ticket.event.starts_at.strftime(
          '%A, %d %B %Y at %I:%M %p'
        ),
        size: 14
      )

      pdf.move_down 35

      qr = RQRCode::QRCode.new(
        verify_ticket_url(@ticket.qr_token)
      )

      png = qr.as_png(
        size: 300,
        border_modules: 4
      )

      pdf.image(
        StringIO.new(png.to_blob),
        width: 180,
        height: 180
      )

      pdf.move_down 15

      pdf.text(
        'Scan this QR code at the entrance.',
        size: 10
      )

      pdf.move_down 20

      pdf.stroke_horizontal_rule

      pdf.move_down 15

      pdf.text(
        "Payment Reference: #{@ticket.order.reference}",
        size: 9
      )

      pdf.text(
        "Ticket status: #{@ticket.status.upcase}",
        size: 9
      )
    end.render
  end

  private

  def verify_ticket_url(token)
    Rails.application.routes.url_helpers.verify_ticket_url(
      token,
      host: ENV.fetch('APP_HOST').sub(%r{\Ahttps?://}, '')
    )
  end
end
