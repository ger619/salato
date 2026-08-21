module EventsHelper
  # ── Event date parts (used by the index card's date block) ──────────
  def event_month(event)
    event.start_at.strftime("%b").upcase
  end

  def event_day(event)
    event.start_at.strftime("%-d")
  end

  # "Sat 12 Sep · 6:00 PM"
  def event_time(event)
    event.start_at.strftime("%a %-d %b · %-l:%M %p")
  end

  # Short human status for the corner chip. Keep these punchy — the chip is
  # only about 90px wide.
  def event_countdown(event)
    starts_at = event.start_at
    return "FINISHED" if starts_at.past?

    days = (starts_at.to_date - Date.current).to_i

    case days
    when 0     then "TONIGHT"
    when 1     then "TOMORROW"
    when 2..6  then "THIS WEEK"
    when 7..13 then "NEXT WEEK"
    else starts_at.strftime("%b %Y").upcase
    end
  end

  # ── Ticket availability ─────────────────────────────────────────────
  # Only shout when the number actually means something. Showing "247 LEFT"
  # on a 500-capacity show tells the buyer there's no rush.
  def ticket_scarcity(available)
    case available
    when 1     then "LAST ONE"
    when 2..10 then "#{available} LEFT"
    end
  end
end