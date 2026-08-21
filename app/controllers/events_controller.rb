class EventsController < ApplicationController
  before_action :authenticate_user!, except: %i[index show]
  def index
    @events = Event.active.order(start_at: :asc)
  end

  def show
    @event = Event.find_by!(slug: params[:slug])

    raise ActiveRecord::RecordNotFound unless @event.active?

    @ticket_types = @event.ticket_types.active
  end
end
