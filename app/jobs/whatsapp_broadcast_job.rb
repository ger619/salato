# app/jobs/whatsapp_broadcast_job.rb
class WhatsappBroadcastJob
  include Sidekiq::Job

  def perform(broadcast_id)
    broadcast = Broadcast.find(broadcast_id)

    tickets = broadcast.event.tickets
                       .with_phone
                       .filtered(broadcast.filters)
                       .includes(:order)

    delay = 0
    tickets.find_each do |ticket|
      phone = PhoneNormalizer.call(ticket.customer_phone)
      next if phone.blank?
      next if broadcast.deliveries.exists?(phone: phone)

      delivery = begin
                   broadcast.deliveries.create!(ticket: ticket, phone: phone, status: "pending")
                 rescue ActiveRecord::RecordNotUnique
                   next # another batch already queued this number
                 end

      delay += rand(8..20) # spread messages out, in seconds
      SendBroadcastMessageJob.perform_in(delay, delivery.id)
    end

    broadcast.update!(status: 'sending', total_count: broadcast.deliveries.count)
  end
end