# app/controllers/broadcasts_controller.rb
class BroadcastsController < ApplicationController
  before_action :set_event

  def new
    @filters = filter_params
    @recipient_count = recipients.distinct.count('orders.customer_phone')
    @broadcast = @event.broadcasts.new
  end

  def create
    @broadcast = @event.broadcasts.create!(
      user: current_user,
      message: params.require(:broadcast)[:message],
      filters: filter_params.to_h,
      status: 'queued'
    )
    WhatsappBroadcastJob.perform_async(@broadcast.id)
    redirect_to organiser_show_event_path(@event), notice: 'Messages are being sent.'
  end

  def show
    @broadcast = @event.broadcasts.find(params[:id])
  end

  private

  def set_event
    @event = current_user.events.find_by!(slug: params[:event_slug])
  end

  def recipients
    @event.tickets.with_phone.filtered(filter_params)
  end

  def filter_params
    params.fetch(:filters, {}).permit(:status, :ticket_type_id)
  end
end
