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

def seed_user(email:, first_name:, last_name:, role:, client: nil, phone_number: nil)
  user = User.find_or_initialize_by(email: email)

  if user.new_record?
    user.password = SEED_PASSWORD
    user.password_confirmation = SEED_PASSWORD
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
  end

  # Assigned on every run so re-seeding backfills columns added later.
  user.first_name   = first_name
  user.last_name    = last_name
  user.phone_number = phone_number if user.respond_to?(:phone_number=)
  user.client       = client
  user.save!

  # The after_create callback grants :organiser to every new user. Make the
  # seed authoritative instead: hold exactly the role we asked for.
  user.add_role(role) unless user.has_role?(role)

  user.roles.reload
  user.roles.map(&:name).each do |existing|
    user.remove_role(existing) unless existing == role.to_s
  end
  user.roles.reload

  puts "  #{role.to_s.ljust(9)} #{user.email.ljust(24)} " \
         "#{user.full_name}#{" — #{client.name}" if client}"

  user
end

puts "Users:"

admin = seed_user(
  email: ENV.fetch("SEED_USER_EMAIL", "admin@salato.com"),
  first_name: "Salato",
  last_name: "Admin",
  role: :admin,
  phone_number: "+254 700 000 001"
)

seed_user(
  email: "organiser@salato.com",
  first_name: "David",
  last_name: "Ger",
  role: :organiser,
  client: client,
  phone_number: "+254 700 000 002"
)

seed_user(
  email: "scanner@salato.com",
  first_name: "Grace",
  last_name: "Wanjiru",
  role: :scanner,
  client: client,
  phone_number: "+254 700 000 003"
)

# ── Event ───────────────────────────────────────────────────────────────────
# Owned by the admin, since that's the account the seed has always used.

event = Event.find_or_initialize_by(slug: "tech-summit-2026")
event.assign_attributes(
  user: admin,
  name: "Kenya Technology Summit 2026",
  description: "A technology and innovation event.",
  venue: "Nairobi",
  start_at: Time.zone.parse("2026-10-15 09:00"),
  end_at: Time.zone.parse("2026-10-15 18:00")
)
event.active = false if event.new_record? # published at the end, once ticket types exist
event.save!

puts "Event: #{event.name} (#{event.slug})"

# ── Ticket types ────────────────────────────────────────────────────────────

[
  { name: "Early Bird", description: "Early bird admission.", price: 1_000, quantity: 100 },
  { name: "Regular",    description: "Regular admission.",    price: 1_500, quantity: 500 },
  { name: "VIP",        description: "VIP admission.",        price: 5_000, quantity: 50 }
].each do |attributes|
  ticket = event.ticket_types.find_or_initialize_by(name: attributes[:name])

  ticket.description = attributes[:description]
  ticket.price       = attributes[:price]
  ticket.quantity    = attributes[:quantity]
  ticket.active      = true

  if ticket.new_record?
    ticket.reserved_quantity = 0
    ticket.sold_quantity     = 0
  end

  ticket.save!
end

puts "Ticket types: #{event.ticket_types.order(:price).pluck(:name).join(', ')}"

# ── Publish ─────────────────────────────────────────────────────────────────

event.update!(active: true) unless event.active?

puts "Published: #{event.name}"
puts "\nSign in with password: #{SEED_PASSWORD}"