module UsersHelper
  ROLE_CLASSES = {
    'admin' => 'bg-ink text-white',
    'organiser' => 'grad-edge text-ink',
    'scanner' => 'bg-violet/10 text-violet'
  }.freeze

  def role_pill_classes(role)
    ROLE_CLASSES.fetch(role.name, 'bg-ink/8 text-ink2')
  end

  def role_label(role)
    return role.name.humanize if role.resource.blank?

    "#{role.name.humanize} · #{role.resource.try(:name) || role.resource_type}"
  end
end
