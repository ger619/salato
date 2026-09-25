# app/jobs/send_broadcast_message_job.rb
class SendBroadcastMessageJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  def perform(delivery_id)
    delivery = BroadcastDelivery.find(delivery_id)
    return if delivery.status == 'sent'

    broadcast = delivery.broadcast
    Whatsapp::OpenWaClient.send_text(to: delivery.phone, text: broadcast.render_for(delivery.ticket))

    delivery.update!(status: 'sent', sent_at: Time.current)
    Broadcast.update_counters(broadcast.id, sent_count: 1)
  rescue StandardError => e
    delivery.update!(status: 'failed', error: e.message)
    Broadcast.update_counters(delivery.broadcast_id, failed_count: 1)
    raise
  end
end
