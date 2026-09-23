module ApplicationHelper
  # Links to a section on the landing page, e.g. nav_anchor("pricing").
  # On the landing page keep the bare hash so Turbo doesn't reload —
  # anywhere else, send them home first, then to the section.
  def nav_anchor(anchor)
    current_page?(root_path) ? "##{anchor}" : root_path(anchor: anchor)
  end
  alias nav_anchor_path nav_anchor

  def mask_phone(phone, visible_from_end: 3)
    return '—' if phone.blank?

    phone = phone.to_s.strip
    return '*' * phone.length if phone.length <= visible_from_end

    phone[0...-visible_from_end] + ('*' * visible_from_end)
  end
end
