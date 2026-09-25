# db/seeds.rb
#
# Idempotent. Safe to run repeatedly in any environment.
#   bin/rails db:seed
#
# Override the admin login with:
#   SEED_USER_EMAIL=me@example.com SEED_USER_PASSWORD=secret123 bin/rails db:seed

SEED_PASSWORD = ENV.fetch("SEED_USER_PASSWORD", "password123").freeze

# ── Roles ───────────────────────────────────────────────────────────────────

User::ROLES.each { |name| Role.find_or_create_by!(name: name) }

puts "Roles: #{Role.pluck(:name).sort.join(', ')}"

# ── Client ──────────────────────────────────────────────────────────────────
# The organisation staff belong to. Admins work across every client and so
# carry no client_id at all — only organisers and scanners are attached.

client = Client.find_or_initialize_by(name: "Salato Test")
client.assign_attributes(
  email: "hello@salatotest.co.ke",
  phone: "+254 700 000 000",
  address: "Nairobi"
)
client.save!

puts "Client: #{client.name}"

# ── Users ───────────────────────────────────────────────────────────────────

def seed_user(email:, first_name:, last_name:, role:, client: nil, phone_number: nil, status: nil)
  user = User.find_or_initialize_by(email: email)

  if user.new_record?
    user.password = SEED_PASSWORD
    user.password_confirmation = SEED_PASSWORD
  end

  # Assigned on every run so re-seeding backfills columns added later.
  user.first_name   = first_name
  user.last_name    = last_name
  user.phone_number = phone_number if user.respond_to?(:phone_number=)
  user.status       = status       if !status.nil? && user.respond_to?(:status=)
  user.client       = client

  # ── Devise confirmable ──
  # skip_confirmation! sets confirmed_at and stops Devise sending the
  # confirmation email. Run it for NEW users and for EXISTING users that were
  # seeded earlier but never confirmed, so every seeded account can log in.
  if user.respond_to?(:confirmed?) && !user.confirmed?
    user.skip_confirmation!
    user.confirmation_token = nil if user.respond_to?(:confirmation_token=)
  end

  # Don't send a "confirm your new email" mail if the address was changed.
  user.skip_reconfirmation! if user.respond_to?(:skip_reconfirmation!)

  user.save!

  # The after_create callback grants :organiser to every new user. Make the
  # seed authoritative instead: hold exactly the role we asked for.
  user.add_role(role) unless user.has_role?(role)

  user.roles.reload
  user.roles.map(&:name).each do |existing|
    user.remove_role(existing) unless existing == role.to_s
  end
  user.roles.reload

  confirmed = user.respond_to?(:confirmed?) ? (user.confirmed? ? "confirmed" : "UNCONFIRMED") : ""
  puts "  #{role.to_s.ljust(9)} #{user.email.ljust(24)} #{confirmed.ljust(11)} " \
         "#{user.full_name}#{" — #{client.name}" if client}"

  user
end

puts "Users:"

admin = seed_user(
  email: ENV.fetch("SEED_USER_EMAIL", "abolger254@gmail.com"),
  first_name: "David",
  last_name: "Ger",
  role: :admin,
  phone_number: "+254701450691",
  status: true
)


puts "Password for new seeded users: #{SEED_PASSWORD}"