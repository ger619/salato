# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# ── Organiser ───────────────────────────────────────────────────────────────
# Every event belongs to a user, so the organiser has to exist first.

organiser_email = ENV.fetch("SEED_USER_EMAIL", "admin@salato.com")

Role.find_or_create_by!(name: 'super admin')
Role.find_or_create_by!(name: 'admin')
Role.find_or_create_by!(name: 'organiser')



user = User.find_or_initialize_by(email: organiser_email)

if user.new_record?
  password = ENV.fetch("SEED_USER_PASSWORD", "password")
  user.password = password
  user.password_confirmation = password

  # Devise :confirmable — skip the confirmation email for seeded accounts.
  user.skip_confirmation! if user.respond_to?(:skip_confirmation!)

  user.save!
  puts "Created organiser #{user.email}"
else
  puts "Organiser #{user.email} already exists"
end
user.add_role(:admin)

# ── Event ───────────────────────────────────────────────────────────────────

event = Event.find_or_create_by!(slug: "tech-summit-2026") do |record|
  record.user = user
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