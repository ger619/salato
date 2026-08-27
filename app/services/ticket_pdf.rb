require 'prawn'
require 'rqrcode'

# A6 portrait (297.6 x 419.5pt) — same 0.71 aspect as the web ticket card.
# One ticket per page; generate_batch puts a whole order in one file.
#
# NOTE ON PRAWN: text_box silently ignores :color and :font. Prawn only
# validates options when Prawn.debug or $DEBUG is on, so unknown keys are
# dropped without error and the text inherits whatever fill_color and font
# were last set. Every string here goes through #text, which sets both
# explicitly. Don't reintroduce color:/font: as text_box options.
class TicketPdf
  INK = '150D3A'.freeze
  INK2 = '3A3260'.freeze
  MUTED = '6F6890'.freeze
  FAINT = '8B84A6'.freeze
  MIST = 'F7F4FB'.freeze
  PAPER = 'FFFFFF'.freeze
  MAGENTA = 'AB2692'.freeze
  VIOLET = '7620B1'.freeze
  HAIRLINE = 'E6E1EF'.freeze
  PERF_LINE = 'C9C2DA'.freeze

  # linear-gradient(105deg, #7620B1 0%, #AB2692 34%, #E13765 62%, #FC8027 100%)
  GRADIENT_STOPS = [
    [0.00, '7620B1'],
    [0.34, 'AB2692'],
    [0.62, 'E13765'],
    [1.00, 'FC8027']
  ].freeze

  INSET = 14 # card margin inside the page
  PAD = 20 # card's own horizontal padding
  BAND_H = 42 # gradient header
  STUB_H = 180 # everything below the perforation

  # ── public API — everything here must stay above `private` ──────────────

  def self.generate(ticket)
    generate_batch([ticket])
  end

  # One page per ticket, in the order given. Pass the order's tickets and
  # the buyer gets a single file they can print or forward.
  def self.generate_batch(tickets)
    list = Array(tickets)

    raise ArgumentError, 'TicketPdf needs at least one ticket' if list.empty?

    document = Prawn::Document.new(page_size: 'A6', margin: 0)

    list.each_with_index do |ticket, index|
      document.start_new_page if index.positive?

      new(ticket, position: index + 1, total: list.size).draw_on(document)
    end

    document.render
  end

  def initialize(ticket, position: 1, total: 1)
    @ticket = ticket
    @position = position
    @total = total
  end

  # Called by generate_batch on a fresh instance, so it MUST be public.
  def draw_on(pdf)
    @pdf = pdf

    register_fonts
    measure

    draw_page
    draw_band
    draw_event_block
    draw_perforation
    draw_stub
    draw_footer

    self
  end

  private

  attr_reader :pdf, :ticket, :display_font, :body_font, :mono_font

  # ── the only way text gets drawn ────────────────────────────────────────

  def text(string, color:, font:, **)
    pdf.fill_color color

    pdf.font(font) do
      pdf.text_box(string.to_s, **)
    end
  end

  # ── geometry ────────────────────────────────────────────────────────────

  def measure
    @page_w = pdf.bounds.width
    @page_h = pdf.bounds.height

    @card_x = INSET
    @card_w = @page_w - (INSET * 2)
    @card_top = @page_h - INSET
    @card_bottom = INSET

    @inner_x = @card_x + PAD
    @inner_w = @card_w - (PAD * 2)

    @band_bottom = @card_top - BAND_H
    @tear_y = @card_bottom + STUB_H
  end

  # ── layers ──────────────────────────────────────────────────────────────

  def draw_page
    pdf.fill_color MIST
    pdf.fill_rectangle [0, @page_h], @page_w, @page_h

    pdf.fill_color PAPER
    pdf.fill_rectangle [@card_x, @card_top], @card_w, @card_top - @card_bottom

    pdf.stroke_color HAIRLINE
    pdf.line_width 0.6
    pdf.stroke_rectangle [@card_x, @card_top], @card_w, @card_top - @card_bottom
  end

  # The brand gradient as overlapping vertical strips. Prawn's own gradient
  # API has moved between releases; strips render identically and can't
  # break on a gem bump.
  def draw_band
    steps = 140
    strip_w = @card_w / steps.to_f

    steps.times do |i|
      pdf.fill_color gradient_hex(i / (steps - 1).to_f)
      pdf.fill_rectangle(
        [@card_x + (i * strip_w), @card_top],
        strip_w + 0.7,
        BAND_H
      )
    end

    y = @card_top - 15
    half = @inner_w / 2

    text admit_label,
         color: PAPER, font: mono_font,
         at: [@inner_x, y], width: half, height: 14,
         size: 7.5, style: :bold, character_spacing: 1.7,
         overflow: :shrink_to_fit, single_line: true

    text ticket.ticket_type.name.to_s.upcase,
         color: PAPER, font: mono_font,
         at: [@inner_x + half, y], width: half, height: 14,
         size: 7.5, character_spacing: 1.7, align: :right,
         overflow: :shrink_to_fit, single_line: true
  end

  def admit_label
    return 'ADMIT ONE' if @total <= 1

    "ADMIT ONE  ·  #{@position} OF #{@total}"
  end

  def draw_event_block
    y = @band_bottom - 22

    text event.start_at.strftime('%A %-d %B').upcase,
         color: MAGENTA, font: mono_font,
         at: [@inner_x, y], width: @inner_w, height: 11,
         size: 7.5, character_spacing: 1.5, single_line: true

    y -= 15.5

    # The name is what the holder scans for at the gate, so it shrinks to
    # fit rather than clipping.
    text event.name.to_s,
         color: INK, font: display_font,
         at: [@inner_x, y], width: @inner_w, height: 50,
         size: 21, style: :bold, leading: 1,
         overflow: :shrink_to_fit

    y -= 56

    text venue_and_time,
         color: INK2, font: body_font,
         at: [@inner_x, y], width: @inner_w, height: 13,
         size: 10, overflow: :shrink_to_fit, single_line: true

    y -= 34

    field 'HOLDER', ticket.attendee_name.to_s, @inner_x, y, (@inner_w / 2) - 8
    field 'PAID', paid_amount, @inner_x + (@inner_w / 2), y, @inner_w / 2
  end

  def field(label, value, x, y, width)
    text label,
         color: MUTED, font: mono_font,
         at: [x, y], width: width, height: 11,
         size: 6.5, character_spacing: 1.2, single_line: true

    text value,
         color: INK, font: body_font,
         at: [x, y - 13], width: width, height: 15,
         size: 11, style: :bold,
         overflow: :shrink_to_fit, single_line: true
  end

  # Two mist circles bite through the card edge, then a dashed rule between
  # them — the same perforation as the web ticket.
  def draw_perforation
    pdf.fill_color MIST
    pdf.fill_circle [@card_x, @tear_y], 8
    pdf.fill_circle [@card_x + @card_w, @tear_y], 8

    pdf.stroke_color PERF_LINE
    pdf.line_width 0.9
    pdf.dash 2.5, space: 3
    pdf.stroke_horizontal_line(@card_x + 13, @card_x + @card_w - 13, at: @tear_y)
    pdf.undash
  end

  def draw_stub
    qr_size = 92
    qr_top = @tear_y - 24

    pdf.image qr_png,
              at: [@inner_x, qr_top],
              width: qr_size,
              height: qr_size

    col_x = @inner_x + qr_size + 13
    col_w = @inner_w - qr_size - 13

    text 'TICKET NUMBER',
         color: MUTED, font: mono_font,
         at: [col_x, qr_top], width: col_w, height: 10,
         size: 6.5, character_spacing: 1.2, single_line: true

    text ticket.ticket_number.to_s,
         color: INK, font: mono_font,
         at: [col_x, qr_top - 13], width: col_w, height: 26,
         size: 8.5, leading: 2, overflow: :shrink_to_fit

    draw_status_pill(col_x, qr_top - 44)

    text 'Scan at the gate. Valid for one entry.',
         color: MUTED, font: body_font,
         at: [@inner_x, qr_top - qr_size - 12], width: @inner_w, height: 11,
         size: 8, single_line: true
  end

  def draw_status_pill(x, y)
    label, bg, fg = case ticket.status
                    when 'valid' then ['VALID FOR ENTRY', nil, VIOLET]
                    when 'checked_in' then ['CHECKED IN', INK, PAPER]
                    else ['CANCELLED', 'EDE9F3', INK2]
                    end

    w = 96
    h = 15

    if bg
      pdf.fill_color bg
      pdf.fill_rounded_rectangle [x, y], w, h, 7.5
    else
      pdf.stroke_color VIOLET
      pdf.line_width 0.8
      pdf.stroke_rounded_rectangle [x, y], w, h, 7.5
    end

    text label,
         color: fg, font: mono_font,
         at: [x, y - 4], width: w, height: 10,
         size: 6.5, character_spacing: 0.9, align: :center,
         single_line: true
  end

  def draw_footer
    pdf.undash
    pdf.stroke_color HAIRLINE
    pdf.line_width 0.6
    pdf.stroke_horizontal_line(@inner_x, @inner_x + @inner_w, at: @card_bottom + 30)

    text "SALATO  ·  REF #{ticket.order.reference}",
         color: FAINT, font: mono_font,
         at: [@inner_x, @card_bottom + 22], width: @inner_w, height: 9,
         size: 6, character_spacing: 0.8,
         overflow: :shrink_to_fit, single_line: true
  end

  # ── content ─────────────────────────────────────────────────────────────

  def event
    ticket.event
  end

  def venue_and_time
    venue = event.venue.presence || 'Venue to be announced'
    "#{venue}  ·  #{event.start_at.strftime('%-I:%M %p').downcase}"
  end

  def paid_amount
    "#{ticket.order.currency} #{delimit(ticket.order.unit_price)}"
  end

  def delimit(amount)
    amount.to_i.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
  end

  # ── QR ──────────────────────────────────────────────────────────────────

  def qr_png
    qr = RQRCode::QRCode.new(verify_url, level: :m)

    png = qr.as_png(
      size: 600, # oversampled so it stays crisp at 92pt
      border_modules: 2,
      color: "##{INK}",
      fill: "##{PAPER}"
    )

    StringIO.new(png.to_blob)
  end

  def verify_url
    Rails.application.routes.url_helpers.verify_ticket_url(
      ticket.qr_token,
      host: app_host,
      protocol: Rails.env.production? ? 'https' : 'http'
    )
  end

  # ENV.fetch would raise KeyError and 500 the download. Fall back instead.
  def app_host
    raw = ENV['APP_HOST'].presence ||
          Rails.application.routes.default_url_options[:host].presence ||
          Rails.application.config.action_mailer.default_url_options.to_h[:host].presence ||
          'localhost:3000'

    raw.sub(%r{\Ahttps?://}, '').sub(%r{/\z}, '')
  end

  # ── fonts ───────────────────────────────────────────────────────────────

  # Drop Outfit / InterTight / JetBrainsMono TTFs into app/assets/fonts and
  # the PDF picks up the real brand faces. Otherwise it uses the built-ins.
  def register_fonts
    @display_font = register('Outfit') || 'Helvetica'
    @body_font = register('InterTight') || 'Helvetica'
    @mono_font = register('JetBrainsMono') || 'Courier'
  end

  def register(family)
    dir = Rails.root.join('app/assets/fonts')
    normal = dir.join("#{family}-Regular.ttf")
    bold = dir.join("#{family}-Bold.ttf")

    return nil unless File.exist?(normal) && File.exist?(bold)

    pdf.font_families.update(
      family => { normal: normal.to_s, bold: bold.to_s }
    )

    family
  end

  # ── gradient ────────────────────────────────────────────────────────────

  def gradient_hex(position)
    t = position.clamp(0.0, 1.0)

    lower = GRADIENT_STOPS.select { |stop, _| stop <= t }.last || GRADIENT_STOPS.first
    upper = GRADIENT_STOPS.find { |stop, _| stop >= t } || GRADIENT_STOPS.last

    return lower[1] if lower[0] == upper[0]

    blend(lower[1], upper[1], (t - lower[0]) / (upper[0] - lower[0]))
  end

  def blend(from_hex, to_hex, ratio)
    channels = [0, 2, 4].map do |i|
      from = from_hex[i, 2].to_i(16)
      to = to_hex[i, 2].to_i(16)
      (from + ((to - from) * ratio)).round.clamp(0, 255)
    end

    format('%02X%02X%02X', *channels)
  end
end
