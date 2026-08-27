class TicketVerificationsController < ApplicationController
  before_action :authenticate_user!, only: :check_in
  before_action :set_ticket, only: %i[show check_in]
  before_action :authorise_scanner!, only: :check_in
  before_action :ensure_check_in_window!, only: :check_in

  def new
    @query = params[:token].to_s.strip
    return if @query.blank?

    ticket = Ticket.find_by(qr_token: @query) ||
             Ticket.find_by(ticket_number: @query.upcase)

    if ticket
      redirect_to verify_ticket_path(ticket.qr_token)
    else
      render :invalid, status: :not_found
    end
  end

  def show
    # Drives whether the view renders the check-in button or just the status.
    # Same window the controller enforces, so the button never appears when
    # pressing it would only produce an error.
    @event = @ticket.event
    @check_in_open = @event&.check_in_open?
    @can_check_in = user_signed_in? && @event.present? && @check_in_open

    # Lets the view say *when* scanning starts rather than just refusing.
    @check_in_opens_at = @event&.check_in_opens_at
  end

  def check_in
    # Atomic: the WHERE clause is the guard. Only one concurrent request can
    # match a row that is still 'valid', so a double scan can't double check in.
    claimed = Ticket
      .where(id: @ticket.id, status: 'valid')
      .update_all(status: 'checked_in', checked_in_at: Time.current)

    @ticket.reload

    if claimed == 1
      redirect_to verify_ticket_path(@ticket.qr_token),
                  notice: "Checked in — #{@ticket.attendee_name}."
    elsif @ticket.checked_in?
      redirect_to verify_ticket_path(@ticket.qr_token),
                  alert: "Already checked in at #{@ticket.checked_in_at.strftime('%-l:%M %p')}."
    else
      redirect_to verify_ticket_path(@ticket.qr_token),
                  alert: 'This ticket is not valid.'
    end
  end

  private

  def set_ticket
    @ticket = Ticket
      .includes(:event, :ticket_type, :order)
      .find_by(qr_token: params[:token])

    return if @ticket

    render :invalid, status: :not_found
  end

  def authorise_scanner!
    return if @ticket.event

    redirect_to verify_ticket_path(@ticket.qr_token),
                alert: "You can't check in tickets for this event."
  end

  def ensure_check_in_window!
    event = @ticket.event

    if event.start_at.blank?
      return redirect_to verify_ticket_path(@ticket.qr_token),
                         alert: "This event has no start time set, so tickets can't be scanned yet."
    end

    return if event.check_in_open?

    message =
      if Time.current < event.check_in_opens_at
        "Too early — scanning opens #{event.check_in_opens_at.strftime('%-l:%M %p on %a %-d %b')}."
      else
        "Too late — check-in for this event closed #{event.check_in_closes_at.strftime('%-l:%M %p')}."
      end

    redirect_to verify_ticket_path(@ticket.qr_token), alert: message
  end
end
