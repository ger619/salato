# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# ── Roles ───────────────────────────────────────────────────────────────────

%w[admin organiser scanner].each do |name|
  Role.find_or_create_by!(name: name)
end

# ── Client ──────────────────────────────────────────────────────────────────
# The organisation staff belong to. Admins work across every client and so
# carry no client_id at all — only organisers and scanners are attached.

client = Client.find_or_create_by!(name: "Salato Test") do |record|
  record.email = "hello@salatotest.co.ke"
  record.phone = "+254 700 000 000"
  record.address = "Nairobi"
end

puts "Client: #{client.name}"

# ── Users ───────────────────────────────────────────────────────────────────

def seed_user(email:, role:, client: nil, password: nil)
  user = User.find_or_initialize_by(email: email)

  if user.new_record?
    secret = password || ENV.fetch("SEED_USER_PASSWORD", "password")
    user.password = secret
    user.password_confirmation = secret

    # Devise :confirmable — skip the confirmation email for seeded accounts.
    user.skip_confirmation! if user.respond_to?(:skip_confirmation!)
  end

  # Set on every run so re-seeding after adding the column backfills it.
  user.client = client
  user.save!

  user.add_role(role) unless user.has_role?(role)

  puts "#{role.to_s.humanize}: #{user.email}#{" — #{client.name}" if client}"
  user
end

admin = seed_user(
  email: ENV.fetch("SEED_USER_EMAIL", "admin@salato.com"),
  role: :admin
)

seed_user(email: "organiser@salato.com", role: :organiser, client: client)
seed_user(email: "scanner@salato.com",   role: :scanner,   client: client)

# ── Event ───────────────────────────────────────────────────────────────────
# Owned by the admin, since that's the account the seed has always used.

event = Event.find_or_create_by!(slug: "tech-summit-2026") do |record|
  record.user = admin
  record.name = "Kenya Technology Summit 2026"
  record.description = "A technology and innovation event."
  record.venue = "Nairobi"
  record.start_at = Time.zone.parse("2026-10-15 09:00")
  record.end_at = Time.zone.parse("2026-10-15 18:00")
  record.active = false   # published at the end, once ticket types exist
end

puts "Event: #{event.name} (#{event.slug})"

# ── Ticket types ────────────────────────────────────────────────────────────

[
  { name: "Early Bird", description: "Early bird admission.", price: 1_000, quantity: 100 },
  { name: "Regular",    description: "Regular admission.",    price: 1_500, quantity: 500 },
  { name: "VIP",        description: "VIP admission.",        price: 5_000, quantity: 50 }
].each do |attributes|
  event.ticket_types.find_or_create_by!(name: attributes[:name]) do |ticket|
    ticket.description = attributes[:description]
    ticket.price = attributes[:price]
    ticket.quantity = attributes[:quantity]
    ticket.reserved_quantity = 0
    ticket.sold_quantity = 0
    ticket.active = true
  end
end

puts "Ticket types: #{event.ticket_types.pluck(:name).join(', ')}"

# ── Publish ─────────────────────────────────────────────────────────────────

event.update!(active: true) unless event.active?

puts "Published: #{event.name}"