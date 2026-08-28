class EventsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create edit update organiser organiser_show
                                              assign_user unassign_user]
  before_action :set_owned_event, only: %i[edit update organiser_show assign_user unassign_user]
  before_action :set_visible_event, only: %i[show]
  load_and_authorize_resource

  # Organisers see their own events; everyone else sees what's on sale.
  def index
    @events = if user_signed_in?
                Event.all.order(start_at: :desc)
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
      @event.users << current_user if current_user.has_role?(:organiser) &&
                                      !current_user.has_role?(:admin)

      redirect_to organiser_show_event_path(@event), notice: "#{@event.name} is published."
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

  # The id is looked up *through* assignable_users, so an organiser who posts
  # an admin's id gets the same rejection as a tampered id — the role rule is
  # enforced here, not just hidden in the dropdown.
  def assign_user
    user = assignable_users.find_by(id: params[:user_id])

    if user.nil?
      redirect_to organiser_show_event_path(@event),
                  alert: "You can't add that user to this event."
    else
      @event.users << user
      redirect_to organiser_show_event_path(@event),
                  notice: "#{display_name(user)} can now scan tickets for #{@event.name}."
    end
  end

  def unassign_user
    user = @event.users.find_by(id: params[:user_id])

    if user.nil?
      redirect_to organiser_show_event_path(@event),
                  alert: "That user isn't on this event."
    elsif !can_manage_team?
      redirect_to organiser_show_event_path(@event),
                  alert: "You can't change the door team for this event."
    else
      @event.users.delete(user)
      redirect_to organiser_show_event_path(@event),
                  notice: "#{display_name(user)} removed from #{@event.name}."
    end
  end

  def organiser
    @events = Event.all
      .includes(:ticket_types)
      .with_attached_poster
      .order(start_at: :desc)

    @events = @events.joins(:users).where(users: { id: current_user.id }) unless current_user&.has_any_role?(:admin)
  end

  def organiser_show
    @ticket_types = @event.ticket_types.order(:price)
    @tickets = @event.tickets.includes(:ticket_type, :order)
    @orders = @event.orders.order(created_at: :desc)
  end

  private

  # Editing, updating and deleting are limited to the organiser who owns it.
  def set_owned_event
    @event = Event.find_by!(slug: event_slug)
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

  # Who the signed-in user may put on the door.
  #   admin         — anyone
  #   organiser     — scanners only
  #   anyone else   — nobody, so the button never renders
  def assignable_users
    return User.none unless current_user && @event

    available = User.where.not(id: @event.users.select(:id))

    if current_user.has_role?(:admin)
      available
    elsif current_user.has_role?(:organiser)
      available.joins(:roles).where(roles: { name: 'scanner' }).distinct
    else
      User.none
    end
  end

  helper_method :assignable_users

  def can_manage_team?
    current_user&.has_role?(:admin) || current_user&.has_role?(:organiser)
  end
  helper_method :can_manage_team?

  def display_name(user)
    user.try(:full_name).presence || user.email
  end

  helper_method :organiser?

  def event_params
    params.require(:event).permit(
      :name, :slug, :description, :venue, :start_at, :end_at, :active, :poster,
      ticket_types_attributes: %i[id name description price quantity active _destroy]
    )
  end
end
