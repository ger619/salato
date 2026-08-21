# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

event = Event.find_or_create_by!(
  slug: "tech-summit-2026"
) do |record|
  record.name = "Kenya Technology Summit 2026"
  record.description = "A technology and innovation event."
  record.venue = "Nairobi"
  record.start_at = Time.zone.parse(
    "2026-10-15 09:00"
  )
  record.end_at = Time.zone.parse(
    "2026-10-15 18:00"
  )
  record.active = true
end

event.ticket_types.find_or_create_by!(
  name: "Early Bird"
) do |ticket|
  ticket.description = "Early bird admission."
  ticket.price = 1000
  ticket.quantity = 100
  ticket.reserved_quantity = 0
  ticket.sold_quantity = 0
  ticket.active = true
end

event.ticket_types.find_or_create_by!(
  name: "Regular"
) do |ticket|
  ticket.description = "Regular admission."
  ticket.price = 1500
  ticket.quantity = 500
  ticket.reserved_quantity = 0
  ticket.sold_quantity = 0
  ticket.active = true
end

event.ticket_types.find_or_create_by!(
  name: "VIP"
) do |ticket|
  ticket.description = "VIP admission."
  ticket.price = 5000
  ticket.quantity = 50
  ticket.reserved_quantity = 0
  ticket.sold_quantity = 0
  ticket.active = true
end