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

  # Gate-facing verification state. Tuned to be read at arm's length in bad
  # light, so each status gets its own colour, icon and one-word verdict.
  VERIFICATION_STATES = {
    'valid' => {
      verdict: 'ADMIT',
      headline: 'Valid for entry',
      bar: 'bg-emerald-600',
      wash: 'bg-emerald-50',
      stroke: '#059669',
      icon: 'M20 6L9 17l-5-5'
    },
    'checked_in' => {
      verdict: 'DO NOT ADMIT',
      headline: 'Already checked in',
      bar: 'bg-amber-500',
      wash: 'bg-amber-50',
      stroke: '#d97706',
      icon: 'M12 8v5M12 16.5v.01M10.3 3.9L1.8 18a2 2 0 001.7 3h17a2 2 0 001.7-3L14.7 3.9a2 2 0 00-3.4 0z'
    }
  }.freeze

  CANCELLED_STATE = {
    verdict: 'DO NOT ADMIT',
    headline: 'Ticket cancelled',
    bar: 'bg-red-600',
    wash: 'bg-red-50',
    stroke: '#dc2626',
    icon: 'M18 6L6 18M6 6l12 12'
  }.freeze

  def ticket_verification_state(ticket)
    VERIFICATION_STATES.fetch(ticket.status, CANCELLED_STATE)
  end
end
