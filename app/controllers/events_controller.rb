class EventsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update organiser organiser_show]
  before_action :set_owned_event, only: %i[edit update organiser_show]
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

  def organiser
    @events = current_user.events
      .includes(:ticket_types)
      .with_attached_poster
      .order(start_at: :desc)
  end

  def organiser_show
    @ticket_types = @event.ticket_types.order(:price)
    @tickets = @event.tickets.includes(:ticket_type, :order)
    @orders = @event.orders.order(created_at: :desc)
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
    scope = scope.where(active: true)
    scope.order(:price)
  end

  helper_method :organiser?

  def event_params
    params.require(:event).permit(
      :name, :slug, :description, :venue, :start_at, :end_at, :active, :poster,
      ticket_types_attributes: %i[id name description price quantity active _destroy]
    )
  end
end
