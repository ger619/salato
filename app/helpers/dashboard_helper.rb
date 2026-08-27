module DashboardHelper
  # ── Money ────────────────────────────────────────────────────────────
  def kes(amount)
    "KES #{number_with_delimiter(amount.to_i)}"
  end

  # Compact form for chart axes and tight cards: 1.2M, 84k, 950
  def kes_short(amount)
    n = amount.to_i
    return "#{(n / 1_000_000.0).round(1)}M" if n >= 1_000_000
    return "#{(n / 1_000.0).round(n >= 10_000 ? 0 : 1)}k" if n >= 1_000

    n.to_s
  end

  # ── Deltas ───────────────────────────────────────────────────────────
  # Returns nil when there's no prior period to compare against — better a
  # blank space than a meaningless "+100%" in the first week of trading.
  def percent_change(current, previous)
    return nil if previous.to_f.zero?

    ((current.to_f - previous.to_f) / previous.to_f * 100).round
  end

  def delta_classes(pct)
    return 'text-ink-soft/60 bg-ink/5' if pct.nil? || pct.zero?

    pct.positive? ? 'text-magenta bg-magenta/10' : 'text-flare bg-flare/10'
  end

  def delta_label(pct)
    return 'no prior data' if pct.nil?
    return 'no change' if pct.zero?

    "#{'+' if pct.positive?}#{pct}%"
  end

  # ── Chart geometry ───────────────────────────────────────────────────
  # Charts are inline SVG built here rather than a JS charting library: no
  # extra importmap pins, and they render server-side on first paint.

  # Round the axis ceiling up to something readable (1, 2 or 5 x 10^n).
  def nice_max(values)
    peak = Array(values).map(&:to_f).max.to_f
    return 10 if peak <= 0

    magnitude = 10**Math.log10(peak).floor
    step = [1, 2, 5, 10].find { |m| peak <= m * magnitude } || 10
    (step * magnitude).to_i
  end

  # Evenly spaced points across the width, scaled to `max`.
  def chart_points(values, width:, height:, max: nil)
    values = Array(values).map(&:to_f)
    return [] if values.empty?

    ceiling = (max || nice_max(values)).to_f
    ceiling = 1.0 if ceiling.zero?
    span = values.length > 1 ? (values.length - 1).to_f : 1.0

    values.each_with_index.map do |value, i|
      x = (i / span) * width
      y = height - (value / ceiling * height)
      [x.round(2), y.round(2)]
    end
  end

  # Smooth-ish line through the points (cubic segments, flat control handles).
  def chart_line_path(values, width:, height:, max: nil)
    points = chart_points(values, width: width, height: height, max: max)
    return '' if points.empty?
    return "M0 #{points.first[1]}" if points.length == 1

    path = "M#{points.first[0]} #{points.first[1]}"
    points.each_cons(2) do |(x1, y1), (x2, y2)|
      mid = ((x1 + x2) / 2).round(2)
      path << " C#{mid} #{y1}, #{mid} #{y2}, #{x2} #{y2}"
    end
    path
  end

  # Same line, closed along the baseline so it can be filled.
  def chart_area_path(values, width:, height:, max: nil)
    line = chart_line_path(values, width: width, height: height, max: max)
    return '' if line.blank?

    points = chart_points(values, width: width, height: height, max: max)
    "#{line} L#{points.last[0]} #{height} L#{points.first[0]} #{height} Z"
  end

  # Tiny inline trend line for the stat cards.
  def sparkline_path(values, width: 100, height: 28)
    chart_line_path(values, width: width, height: height)
  end

  # ── Misc ─────────────────────────────────────────────────────────────
  def order_status_classes(status)
    case status.to_s
    when 'paid' then 'bg-magenta/10 text-magenta'
    when 'pending' then 'bg-ember/15 text-ember'
    when 'expired' then 'bg-ink/8 text-ink-soft/70'
    when 'failed' then 'bg-flare/10 text-flare'
    else 'bg-ink/8 text-ink-soft/70'
    end
  end

  def initials_for(name)
    name.to_s.split.first(2).filter_map { |part| part[0] }.join.upcase.presence || '?'
  end
end
