class EventsController < ApplicationController
  ADMIN_ROLE = 'admin'.freeze
  ORGANISER_ROLE = 'organiser'.freeze
  SCANNER_ROLE = 'scanner'.freeze

  TEAM_ACTIONS = %i[organiser_show assign_user unassign_user].freeze

  before_action :authenticate_user!, only: %i[new create edit update organiser] + TEAM_ACTIONS
  before_action :set_owned_event, only: %i[edit update] + TEAM_ACTIONS
  before_action :set_visible_event, only: %i[show]
  before_action :require_team_manager!, only: %i[assign_user unassign_user]
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
    # organisers always get their own client; admins may pick one
    @event.client_id = current_user.client_id unless acting_admin?

    if @event.save
      @event.users << current_user if current_user.has_role?(ORGANISER_ROLE) && !acting_admin?

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
  # an id the dropdown never offered — an admin, or someone from another
  # client — gets the same rejection as a tampered id. The client rule and the
  # role rule are both enforced here, not just hidden in the dropdown.
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
  rescue ActiveRecord::RecordNotUnique
    # Double-submit: they're already on the team, which is the intended end state.
    redirect_to organiser_show_event_path(@event),
                notice: "#{display_name(user)} is already on the door team."
  end

  def unassign_user
    user = @event.users.find_by(id: params[:user_id])

    if user.nil?
      redirect_to organiser_show_event_path(@event),
                  alert: "That user isn't on this event."
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

    @events = @events.joins(:users).where(users: { id: current_user.id }) unless acting_admin?
  end

  def organiser_show
    @ticket_types = @event.ticket_types.order(:price)
    @tickets = @event.tickets.includes(:ticket_type, :order)
    @orders = @event.orders.order(created_at: :desc)
  end

  private

  # Ownership itself is enforced by CanCanCan via load_and_authorize_resource,
  # which authorizes the @event this sets.
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
    @event.ticket_types.where(active: true).order(:price)
  end

  # ── Door team ─────────────────────────────────────────────────────────
  #
  # Two independent rules, both applied here:
  #
  #   1. WHICH CLIENT — a candidate must belong to the same client as the
  #      event. Admins are the exception: an admin can be added to any
  #      event regardless of client. This is about the *candidate's* role,
  #      so it holds whether an admin or an organiser is doing the adding.
  #
  #   2. WHICH ROLE — an admin may add anyone the rule above allows; an
  #      organiser may only add scanners.
  #
  def assignable_users
    return User.none unless current_user && @event
    return User.none unless can_manage_team?

    candidates = same_client_or_admin(unassigned_users)

    if acting_admin?
      candidates.distinct
    else
      candidates.joins(:roles).where(roles: { name: SCANNER_ROLE }).distinct
    end
  end
  helper_method :assignable_users

  def unassigned_users
    User.where.not(id: @event.users.select(:id))
  end

  # Both sides of the .or derive from the same relation, which is what
  # ActiveRecord requires for structural compatibility.
  def same_client_or_admin(scope)
    # An event with no client can only take admins — otherwise a nil client_id
    # would silently match every other user whose client_id is also nil.
    return scope.where(id: admin_user_ids) if @event.client_id.blank?

    scope.where(client_id: @event.client_id).or(scope.where(id: admin_user_ids))
  end

  # select(:id), not pluck(:id) — keeps this a subquery instead of loading
  # every admin id into Ruby on each render of the modal.
  def admin_user_ids
    User.joins(:roles).where(roles: { name: ADMIN_ROLE }).select(:id)
  end

  def can_manage_team?
    current_user&.has_role?(ADMIN_ROLE) || current_user&.has_role?(ORGANISER_ROLE)
  end
  helper_method :can_manage_team?

  def require_team_manager!
    return if can_manage_team?

    redirect_to organiser_show_event_path(@event),
                alert: "You can't change the door team for this event."
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  def acting_admin?
    current_user&.has_role?(ADMIN_ROLE)
  end
  helper_method :acting_admin?

  def display_name(user)
    user.try(:full_name).presence || user.email
  end

  helper_method :organiser?

  def event_params
    permitted = %i[name slug description venue start_at end_at active poster]
    permitted << :client_id if acting_admin?

    params.require(:event).permit(
      *permitted,
      ticket_types_attributes: %i[id name description price quantity active _destroy]
    )
  end
end
