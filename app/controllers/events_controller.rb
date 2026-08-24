class EventsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update destroy]
  before_action :set_owned_event, only: %i[edit update destroy]
  before_action :set_visible_event, only: %i[show]

  # Organisers see their own events; everyone else sees what's on sale.
  def index
    @events = if user_signed_in?
                current_user.events.order(start_at: :desc)
              else
                Event.live.upcoming
              end
  end

  def show
    @ticket_types = visible_ticket_types
  end

  def new
    @event = current_user.events.new(
      active: true,
      start_at: 1.week.from_now.change(hour: 18, min: 0)
    )
    @event.ticket_types.build(active: true)
  end

  def create
    @event = current_user.events.new(event_params)

    if @event.save
      redirect_to @event, notice: "#{@event.name} is published."
    else
      @event.ticket_types.build(active: true) if @event.ticket_types.empty?
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @event.update(event_params)
      redirect_to @event, notice: 'Changes saved.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    redirect_to events_path, notice: 'Event deleted.', status: :see_other
  end

  private

  # Editing, updating and deleting are limited to the organiser who owns it.
  def set_owned_event
    @event = current_user.events.find_by!(slug: event_slug)
  end

  # The ticket page is public, but a draft stays visible to its organiser
  # so they can preview it before switching sales on.
  def set_visible_event
    @event = Event.find_by!(slug: event_slug)
    raise ActiveRecord::RecordNotFound unless @event.active? || organiser?
  end

  def event_slug
    params[:slug] || params[:id]
  end

  def visible_ticket_types
    scope = @event.ticket_types
    scope = scope.where(active: true) unless organiser?
    scope.order(:price)
  end

  def organiser?
    user_signed_in? && @event.user_id == current_user.id
  end
  helper_method :organiser?

  def event_params
    params.require(:event).permit(
      :name, :slug, :description, :venue, :start_at, :end_at, :active, :event_poster,
      ticket_types_attributes: %i[id name description price quantity active _destroy]
    )
  end
end
