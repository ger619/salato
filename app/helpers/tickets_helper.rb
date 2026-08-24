module TicketsHelper
  # Inline SVG QR pointing at the gate-verification URL.
  # Uses the request host, so no APP_HOST env var needed here.
  def ticket_qr_svg(ticket, px: 200)
    qr = RQRCode::QRCode.new(
      verify_ticket_url(ticket.qr_token),
      level: :m
    )

    qr.as_svg(
      color: '150D3A',
      module_size: 4,
      shape_rendering: 'crispEdges',
      standalone: true,
      use_path: true,
      viewbox: true,
      svg_attributes: {
        width: px,
        height: px,
        role: 'img',
        'aria-label': "QR code for ticket #{ticket.ticket_number}"
      }
    ).html_safe
  end

  # Palette-consistent styling for each ticket state.
  def ticket_status_pill(ticket)
    case ticket.status
    when 'valid'
      { label: 'Valid for entry', classes: 'grad-edge text-ink' }
    when 'checked_in'
      { label: 'Checked in', classes: 'bg-ink text-white' }
    else
      { label: 'Cancelled', classes: 'bg-ink/8 text-ink2 line-through' }
    end
  end
end