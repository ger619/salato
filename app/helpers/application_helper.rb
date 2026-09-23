module ApplicationHelper
  # Links to a section on the landing page, e.g. nav_anchor("pricing").
  # On the landing page keep the bare hash so Turbo doesn't reload —
  # anywhere else, send them home first, then to the section.
  def nav_anchor(anchor)
    current_page?(root_path) ? "##{anchor}" : root_path(anchor: anchor)
  end
  alias nav_anchor_path nav_anchor

  def mask_phone(phone)
    return '—' if phone.blank?

    digits = phone.to_s.gsub(/\D/, '') # keep numbers only
    digits = "254#{digits[1..]}" if digits.start_with?('0') # 0701… → 254701…

    if digits.length == 12
      "+#{digits[0, 3]} #{digits[3, 3]} *** #{digits[9, 3]}"
    else
      # Fallback for unexpected lengths: hide the middle, keep first 3 and last 3
      "+#{digits[0, 3]} *** #{digits[-3..]}"
    end
  end
end
