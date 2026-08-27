module ApplicationHelper
  def nav_anchor_path(anchor)
    # On the landing page keep the bare hash so Turbo doesn't reload —
    # anywhere else, send them home first, then to the section.
    current_page?(root_path) ? "##{anchor}" : root_path(anchor: anchor)
  end
end
